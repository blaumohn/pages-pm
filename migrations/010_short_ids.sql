-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Setzt §7.4 (Kennungen, Adressierung und Rahmen), Regeln 1-8 um: die
-- Kurzkennung ist eine eigenständige, kurze, installationsweit eindeutige
-- äußere Adresse, getrennt von der unveränderlichen inneren Kennung
-- (pm.object_registry.id).
--
-- pm.short_ids ist ein append-only-Verzeichnis, nicht Teil von
-- pm.object_registry: Eine einmal vergebene Kurzkennung bleibt reserviert,
-- auch wenn das zugehörige Objekt später gelöscht wird (§7.4, Regel 3). Beim
-- Löschen des Objekts setzt ON DELETE SET NULL nur object_id auf NULL — die
-- Zeile und ihr Wert bleiben bestehen, ein alter äußerer Verweis zeigt danach
-- ins Leere, nie auf ein anderes Objekt. "Append-only" folgt hier aus den
-- vergebenen Rechten (kein UPDATE/DELETE für editor, siehe unten und die
-- zugehörigen Tests), nicht aus einem zusätzlichen Sperrtrigger.
--
-- Erzeugung und Kollisionsauflösung: pm.assign_short_id() zieht wiederholt
-- eine neue Kandidatin (pm.generate_short_id_candidate()) und versucht sie
-- über INSERT ... ON CONFLICT DO NOTHING in pm.short_ids einzutragen, bis
-- ein freier Wert eingetragen wurde. Das entspricht Regel 2: bei Kollision
-- wird die Ziehung wiederholt, bestehende Kurzkennungen ändern sich nie. Die
-- Schleife ist auf 1000 Versuche begrenzt, damit ein erschöpfter
-- Kennungsraum oder ein Fehler in der Erzeugungsfunktion nicht zu einer
-- Endlosschleife führt, sondern zu einem klaren Fehler. Zeichenmenge, Länge
-- und Erzeugungsverfahren sind ausdrücklich keine Festlegung der
-- Spezifikation (§7.4, Abgrenzung zur technischen Umsetzungsschicht) und
-- dürfen hier frei gewählt werden.
--
-- pm.register_object() (003_object_registry.sql) wird um den Aufruf von
-- pm.assign_short_id(NEW.id) erweitert, damit jedes registrierte Objekt
-- innerhalb derselben Anweisung auch seine Kurzkennung erhält — ohne diese
-- Erweiterung gäbe es einen Moment, in dem ein Objekt registriert, aber von
-- außen noch nicht adressierbar wäre. Scheitert bereits die Registrierung
-- (unbekannte oder falsch zugeordnete Objektart), wird pm.assign_short_id()
-- gar nicht erst erreicht. Scheitert stattdessen die Kurzkennungsvergabe
-- selbst (z. B. nach 1000 erfolglosen Versuchen), nimmt dieselbe Anweisung
-- ebenso die soeben eingefügte Registerzeile und die auslösende Fachzeile
-- zurück — beide entstehen nur zusammen mit einer Kurzkennung, nie ohne.

SET ROLE schema_owner;

CREATE TABLE pm.short_ids (
    -- Die gegenwärtige Erzeugung (pm.generate_short_id_candidate()) liefert
    -- immer vier Zeichen aus [0-9a-z]; die Bedingung selbst lässt "4 oder
    -- mehr" zu, damit eine spätere, längere Kennungsform (§7.4, Regel 8)
    -- keine Schemaänderung braucht.
    value       text PRIMARY KEY
        CHECK (value ~ '^[a-z0-9]{4,}$'),

    object_id   uuid
        REFERENCES pm.object_registry(id)
        ON DELETE SET NULL,

    assigned_at timestamptz NOT NULL
        DEFAULT statement_timestamp()
);

COMMENT ON TABLE pm.short_ids IS
    'Äußere Kurzkennungen (§7.4). Append-only: Zeilen werden nie gelöscht und '
    'ihr value nie geändert, damit eine Kurzkennung nie einem anderen Objekt '
    'zugewiesen wird (Regel 3). Append-only folgt aus den vergebenen Rechten '
    '(kein UPDATE/DELETE für editor). Geschrieben ausschließlich über '
    'pm.assign_short_id(), nie unmittelbar durch editor.';
COMMENT ON COLUMN pm.short_ids.value IS
    'Die Kurzkennung selbst; unveränderlich. Vergleiche sind immer exakt '
    '(Regel 4) — diese Spalte wird nie als Präfix oder Suffix durchsucht.';
COMMENT ON COLUMN pm.short_ids.object_id IS
    'Registriertes Objekt, dem diese Kurzkennung gehört. NULL, sobald das '
    'Objekt gelöscht wurde (ON DELETE SET NULL) — die Zeile bleibt bestehen, '
    'ein alter Verweis zeigt dann ins Leere, nie auf ein anderes Objekt.';
COMMENT ON COLUMN pm.short_ids.assigned_at IS
    'Bearbeitungsspur, keine fachliche Aussage.';

-- Jedes lebende Objekt trägt höchstens eine Kurzkennung. Ein partieller
-- Unique-Index statt eines UNIQUE-Constraints, weil mehrere Zeilen mit
-- object_id = NULL (gelöschte Objekte) nebeneinander bestehen dürfen.
CREATE UNIQUE INDEX short_ids_object_id_key
    ON pm.short_ids (object_id)
    WHERE object_id IS NOT NULL;

-- Erzeugt nur eine Kandidatin, ohne Eindeutigkeit zu prüfen. Zeichenmenge
-- 0-9 und a-z (36 Zeichen), vier Stellen. Rein technische Wahl, keine
-- Festlegung dieser Spezifikation.
CREATE FUNCTION pm.generate_short_id_candidate()
RETURNS text
LANGUAGE sql
VOLATILE
AS $$
    SELECT string_agg(
               substr(
                   '0123456789abcdefghijklmnopqrstuvwxyz',
                   (floor(random() * 36) + 1)::int,
                   1
               ),
               ''
           )
      FROM generate_series(1, 4);
$$;

COMMENT ON FUNCTION pm.generate_short_id_candidate() IS
    'Liefert eine einzelne vierstellige Kandidatin aus [0-9a-z], ohne '
    'Eindeutigkeit zu prüfen. Nur zur Verwendung durch pm.assign_short_id().';

REVOKE ALL ON FUNCTION pm.generate_short_id_candidate() FROM PUBLIC;

-- Zieht Kandidatinnen, bis eine frei ist, trägt sie ein und liefert sie
-- zurück. Bricht nach 1000 erfolglosen Versuchen mit einer eindeutigen
-- Fehlermeldung ab, statt endlos zu schleifen. SECURITY DEFINER (Eigentümer
-- schema_owner), weil editor keine unmittelbaren Schreibrechte auf
-- pm.short_ids erhält.
CREATE FUNCTION pm.assign_short_id(p_object_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pm
AS $$
DECLARE
    v_candidate text;
    v_row_count int;
    v_attempt   int;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pm.object_registry WHERE id = p_object_id
    ) THEN
        RAISE EXCEPTION 'Objekt % ist nicht im Register vorhanden', p_object_id
            USING ERRCODE = '23503';
    END IF;

    -- pm.short_ids_object_id_key (partieller Unique-Index) verhindert eine
    -- zweite Kurzkennung für dasselbe Objekt ohnehin, aber als Fehler an der
    -- falschen Stelle: ON CONFLICT (value) unten fängt nur Kollisionen bei
    -- value ab, nicht bei object_id. Ohne diese Prüfung würde ein zweiter
    -- Aufruf für dasselbe Objekt mit einem rohen Unique-Verletzungsfehler
    -- auf short_ids_object_id_key abbrechen statt mit einer verständlichen
    -- Meldung.
    IF EXISTS (
        SELECT 1 FROM pm.short_ids WHERE object_id = p_object_id
    ) THEN
        RAISE EXCEPTION 'Objekt % besitzt bereits eine Kurzkennung', p_object_id
            USING ERRCODE = '23505';
    END IF;

    FOR v_attempt IN 1..1000 LOOP
        v_candidate := pm.generate_short_id_candidate();

        INSERT INTO pm.short_ids (value, object_id)
        VALUES (v_candidate, p_object_id)
        ON CONFLICT (value) DO NOTHING;

        GET DIAGNOSTICS v_row_count = ROW_COUNT;

        IF v_row_count > 0 THEN
            RETURN v_candidate;
        END IF;
    END LOOP;

    RAISE EXCEPTION
        'Keine freie Kurzkennung nach 1000 Versuchen gefunden'
        USING ERRCODE = '53200';
END;
$$;

COMMENT ON FUNCTION pm.assign_short_id(uuid) IS
    'Erzeugt und reserviert die Kurzkennung eines bereits registrierten '
    'Objekts (§7.4, Regeln 1-2). Wiederholt die Ziehung bei einer Kollision '
    '(ON CONFLICT DO NOTHING auf pm.short_ids.value), bis ein freier Wert '
    'eingetragen ist oder 1000 Versuche erschöpft sind. Wird von '
    'pm.register_object() aufgerufen, nicht unmittelbar von editor.';

REVOKE ALL ON FUNCTION pm.assign_short_id(uuid) FROM PUBLIC;

-- Löst eine Kurzkennung ausschließlich exakt auf (Regel 4). Liefert NULL bei
-- unbekanntem Wert und ebenso NULL, wenn das Objekt inzwischen gelöscht ist —
-- beides "zeigt ins Leere", niemals auf ein anderes Objekt.
CREATE FUNCTION pm.resolve_short_id(p_value text)
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
    SELECT object_id
      FROM pm.short_ids
     WHERE value = p_value;
$$;

COMMENT ON FUNCTION pm.resolve_short_id(text) IS
    'Löst eine Kurzkennung exakt zur inneren Kennung auf (Regel 4, Regel 6). '
    'NULL sowohl bei unbekanntem Wert als auch bei einer Kurzkennung, deren '
    'Objekt gelöscht wurde.';

-- Neu angelegte Funktionen erhalten von PostgreSQL standardmäßig EXECUTE für
-- PUBLIC. pm.resolve_short_id() ist zur unmittelbaren Verwendung durch
-- migrator, editor und reader gedacht, nicht für beliebige Rollen.
REVOKE ALL ON FUNCTION pm.resolve_short_id(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION pm.resolve_short_id(text)
    TO migrator, editor, reader;

-- pm.register_object() (003_object_registry.sql) um die Vergabe der
-- Kurzkennung erweitert: dieselbe Anweisung, die die Fachzeile registriert,
-- vergibt jetzt auch ihre Kurzkennung. Scheitert die Registrierung, wird wie
-- bisher die gesamte Fachzeilen-Einfügung zurückgenommen — dann wurde auch
-- keine Kurzkennung verbraucht, weil pm.assign_short_id() gar nicht erst
-- erreicht wird.
CREATE OR REPLACE FUNCTION pm.register_object()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pm
AS $$
DECLARE
    v_object_type text;
    v_table_name  regclass;
BEGIN
    IF TG_NARGS <> 1 THEN
        RAISE EXCEPTION
            'pm.register_object() auf %.% erwartet genau ein Objektart-Argument',
            TG_TABLE_SCHEMA, TG_TABLE_NAME
            USING ERRCODE = '22023';
    END IF;

    v_object_type := TG_ARGV[0];

    SELECT t.table_name
      INTO v_table_name
      FROM pm.object_types AS t
     WHERE t.key = v_object_type;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Unbekannte Objektart: %', v_object_type
            USING ERRCODE = '23503';
    END IF;

    IF v_table_name <> TG_RELID THEN
        RAISE EXCEPTION
            'Objektart % gehört zu %, nicht zu %',
            v_object_type, v_table_name, TG_RELID::regclass
            USING ERRCODE = '23514';
    END IF;

    INSERT INTO pm.object_registry (id, object_type)
    VALUES (NEW.id, v_object_type);

    PERFORM pm.assign_short_id(NEW.id);

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.register_object() IS
    'AFTER-INSERT-Triggerfunktion für Fachtabellen. Erwartet die Objektart als '
    'Triggerargument, prüft deren Existenz und dass pm.object_types.table_name '
    'auf die auslösende Tabelle verweist, registriert NEW.id und vergibt seine '
    'Kurzkennung (pm.assign_short_id) — andernfalls wird die gesamte '
    'Fachzeilen-Einfügung zurückgenommen.';

-- editor und reader dürfen Kurzkennungen lesen (Auflösung, Anzeige), aber
-- nicht unmittelbar schreiben: Vergabe geschieht ausschließlich über
-- pm.assign_short_id(), aufgerufen aus pm.register_object().
GRANT SELECT ON pm.short_ids TO migrator, editor, reader;

RESET ROLE;
