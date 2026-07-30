-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Stellt die gemeinsame Grundlage zur Umsetzung von P-010 (Änderungen
-- sichtbar fortschreiben) bereit: der Zustandsverlauf ist eine geführte,
-- abfragbare Nebenfolge (P-014, §7.2), kein eigener Fachgegenstand —
-- Einträge tragen eine Platznummer je Objekt, keine Kennung, und sind nie
-- selbst Endpunkt einer Beziehung. Diese Migration stellt nur den
-- gemeinsamen Speicher bereit; erst eine Fachtabelle mit echter
-- Zustandsliste (Vorgang, §7.6) kann erzwingen, dass eine Zustandsänderung
-- und ihr Verlaufseintrag atomar zusammen erfolgen.
--
-- pm.state_history ist absichtlich generisch über alle registrierten
-- Fachobjekte (object_id -> pm.object_registry), nicht je Fachtabelle
-- eigens: das entspricht dem Registermodell aus 003_object_registry.sql.
-- Welche Zustandswechsel einer bestimmten Fachart überhaupt einen Eintrag
-- verlangen ("Schwelle ist der Zustand des Gegenstands, nicht die Größe der
-- Änderung"), entscheidet die jeweilige Fachtabelle beim Aufruf von
-- pm.append_state_history() — das gibt es hier noch nicht zu entscheiden,
-- weil keine Fachtabelle mit einer echten Zustandsliste im Go-live existiert.
--
-- Append-only: Zeilen werden nie geändert oder gelöscht (§7.2, Nebenfolge).
-- editor erhält deshalb keine unmittelbaren Schreibrechte auf
-- pm.state_history, sondern ausschließlich EXECUTE auf
-- pm.append_state_history() (SECURITY DEFINER, Eigentümer schema_owner).
-- ON DELETE RESTRICT auf object_id: ein Objekt mit Verlauf ist gegen
-- versehentliches Löschen geschützt, wie Herkunft und Beziehungen. Eine
-- ausdrückliche, streng eingeschränkte administrative Aufhebung dieser
-- Sperre für tatsächliche Fehlanlagen ist bewusst NICHT Teil dieser
-- Migration, sondern eine eigene, spätere technische Grundlage.
--
-- Bearbeiter (actor) ist laut Form eines Verlaufseintrags "automatisch",
-- Grund (reason) dagegen "mit der Änderung übergeben" (Pflicht-Parameter).
-- pm.append_state_history() verwendet dafür session_user: eine von der
-- Anwendung frei setzbare Sitzungseinstellung wäre kein belastbarer
-- Nachweis der handelnden Person. session_user ist damit die
-- Datenbankrolle, nicht zwingend die verantwortliche Person — eine
-- authentifizierte fachliche Identität (P-004) ist eine spätere, eigene
-- Angabe, keine Vorwegnahme hier.

SET ROLE schema_owner;

CREATE TABLE pm.state_history (
    object_id   uuid NOT NULL
        REFERENCES pm.object_registry(id)
        ON DELETE RESTRICT,

    seq         integer NOT NULL
        CHECK (seq > 0),

    occurred_at timestamptz NOT NULL
        DEFAULT statement_timestamp(),

    database_actor text NOT NULL,

    event_kind  text NOT NULL,

    reason      jsonb NOT NULL,

    change_kind text,

    PRIMARY KEY (object_id, seq),

    CONSTRAINT state_history_event_kind_is_valid
        CHECK (
            event_kind IN (
                'state_change',
                'decision',
                'supersession',
                'project_change',
                'override',
                'text_change'
            )
        ),

    -- Änderungsart ist ein Kurzwert ohne Vorgabewert. "Geltungsbereich" ist
    -- absichtlich kein zulässiger Wert: eine Geltungsbereichsänderung ist
    -- laut Spezifikation immer eine Ablösung (event_kind = 'supersession'),
    -- keine Textänderung mit change_kind.
    CONSTRAINT state_history_change_kind_is_valid
        CHECK (change_kind IS NULL OR change_kind IN ('editorial', 'substantive')),

    -- change_kind ist Pflicht genau bei Textänderungen an angenommenem oder
    -- geltendem Text (event_kind = 'text_change') — und nur dort, weil ein
    -- Eintrag ohnehin nur ab dieser Schwelle entsteht (siehe Migrationskopf).
    CONSTRAINT state_history_change_kind_required_for_text_change
        CHECK ((event_kind = 'text_change') = (change_kind IS NOT NULL))
);

COMMENT ON TABLE pm.state_history IS
    'Geführte Nebenfolge des Zustandsverlaufs (P-010) über alle registrierten '
    'Fachobjekte hinweg. Append-only: Zeilen werden nie geändert oder '
    'gelöscht, geschrieben ausschließlich über pm.append_state_history().';
COMMENT ON COLUMN pm.state_history.object_id IS
    'Registriertes Fachobjekt, zu dem dieser Verlaufseintrag gehört.';
COMMENT ON COLUMN pm.state_history.seq IS
    'Platznummer je Objekt (1, 2, 3, ...), keine Kennung. Eine Beziehung '
    'zeigt immer auf object_id, nie auf einen einzelnen Verlaufseintrag.';
COMMENT ON COLUMN pm.state_history.occurred_at IS
    'Zeitpunkt des Ereignisses. Automatisch gesetzt (Form eines '
    'Verlaufseintrags).';
COMMENT ON COLUMN pm.state_history.database_actor IS
    'Technische Datenbankrolle der Sitzung, automatisch aus session_user '
    'gesetzt. Noch keine authentifizierte fachliche Identität nach P-004. '
    'Bewusst als database_actor bezeichnet, damit eine spätere fachliche '
    'Identität in einer eigenen Spalte ergänzt werden kann.';
COMMENT ON COLUMN pm.state_history.event_kind IS
    'Ereignisart: state_change (Zustandswechsel), decision (Entscheidung), '
    'supersession (Ablösung), project_change (Projektwechsel), override '
    '(Übergehung) oder text_change (Textänderung an angenommenem oder '
    'geltendem Text).';
COMMENT ON COLUMN pm.state_history.reason IS
    'Grund als Fachtext (Sprachkarte). Pflicht, mit der Änderung übergeben '
    '— nicht nachträglich ergänzbar, weil die Zeile append-only ist.';
COMMENT ON COLUMN pm.state_history.change_kind IS
    'Änderungsart: editorial (redaktionell, kein Grund inhaltlich nötig) '
    'oder substantive (fachlich, der Inhalt gilt jetzt anders). Pflicht bei '
    'event_kind = text_change, sonst NULL. Kein Vorgabewert — ein Urteil.';

-- Prüft reason gegen die systemweite Sprachkonfiguration. Mindestlänge 1:
-- damit wird nur die in P-010 verlangte Anwesenheit eines Grundes geprüft
-- (pm.validate_nonempty_language_map vergleicht nach btrim(); ein reiner
-- Leerraumwert zählt daher ebenfalls als zu kurz). Eine größere Mindestlänge
-- wäre nur mit einer eigenen fachlichen Regel zulässig.
CREATE FUNCTION pm.validate_state_history_reason()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pm.validate_nonempty_language_map(NEW.reason, 1);
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.validate_state_history_reason() IS
    'Prüft pm.state_history.reason gegen die systemweite Sprachkonfiguration. '
    'Mindestlänge 1 (nicht leer) — P-010 verlangt einen Grund, aber keine '
    'darüber hinausgehende Mindestlänge.';

CREATE TRIGGER state_history_validate_reason
    BEFORE INSERT ON pm.state_history
    FOR EACH ROW
    EXECUTE FUNCTION pm.validate_state_history_reason();

-- Vergibt die nächste Platznummer je Objekt und schreibt den Eintrag.
-- SECURITY DEFINER (Eigentümer schema_owner), weil editor keine
-- unmittelbaren Schreibrechte auf pm.state_history erhält — Append-only gilt
-- damit tatsächlich, nicht nur der Empfehlung nach.
--
-- FOR UPDATE auf die betroffene pm.object_registry-Zeile serialisiert
-- gleichzeitige Aufrufe für dasselbe Objekt. Ohne diese Sperre könnten zwei
-- gleichzeitige Aufrufe dieselbe nächste Platznummer bestimmen; einer der
-- beiden INSERTs würde dann am Primärschlüssel (object_id, seq) scheitern.
CREATE FUNCTION pm.append_state_history(
    p_object_id   uuid,
    p_event_kind  text,
    p_reason      jsonb,
    p_change_kind text DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pm
AS $$
DECLARE
    v_seq integer;
BEGIN
    PERFORM 1 FROM pm.object_registry WHERE id = p_object_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Objekt % ist nicht im Register vorhanden', p_object_id
            USING ERRCODE = '23503';
    END IF;

    SELECT COALESCE(max(seq), 0) + 1
      INTO v_seq
      FROM pm.state_history
     WHERE object_id = p_object_id;

    INSERT INTO pm.state_history (
        object_id, seq, database_actor, event_kind, reason, change_kind
    )
    VALUES (
        p_object_id,
        v_seq,
        session_user,
        p_event_kind,
        p_reason,
        p_change_kind
    );

    RETURN v_seq;
END;
$$;

COMMENT ON FUNCTION pm.append_state_history(uuid, text, jsonb, text) IS
    'Schreibt den nächsten Zustandsverlauf-Eintrag eines Objekts (P-010). '
    'Grund (p_reason) muss mit der Änderung übergeben werden; der '
    'Bearbeiter wird automatisch auf session_user gesetzt, nicht aus einem '
    'Parameter übernommen.';

REVOKE ALL ON FUNCTION pm.append_state_history(uuid, text, jsonb, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION pm.append_state_history(uuid, text, jsonb, text)
    TO migrator, editor;

-- editor und reader dürfen den Verlauf lesen; Schreiben geschieht
-- ausschließlich über pm.append_state_history().
GRANT SELECT ON pm.state_history TO migrator, editor, reader;

RESET ROLE;
