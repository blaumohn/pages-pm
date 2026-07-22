-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Ersetzt das frühere Obertyp-Untertyp-Modell (eine vorab anzulegende Zeile
-- in pm.objects, die erst später durch eine Fachtabellenzeile vervollständigt
-- wurde) durch ein reines Registermodell: Jede Fachtabelle (pm.issues,
-- pm.sprints, pm.kep_lites, ...) ist selbst das vollständige Objekt. Ein
-- gemeinsames technisches Register (pm.object_registry) beantwortet nur, ob
-- eine Objektkennung existiert und zu welcher Objektart sie gehört —
-- title, created_at und alle übrigen fachlichen Felder bleiben ausschließlich
-- in der jeweiligen Fachtabelle.
--
-- Objektarten stehen in einer Tabelle (pm.object_types) statt in einem
-- PostgreSQL-Enum, damit neue Fachtabellen ihre Objektart per additiver
-- Migration ergänzen können, ohne den Enum-Typ zu ändern. table_name bleibt
-- so lange NULL, bis die zuständige Fachtabellen-Migration sie setzt — erst
-- dann kann sich eine Zeile dieser Tabelle unter dieser Objektart
-- registrieren (siehe pm.register_object() unten). In diesem Stand (Phase A)
-- existieren noch keine Fachtabellen; project/002_object_types.sql seedet
-- lediglich die vorgesehenen Objektart-Schlüssel mit table_name = NULL.
--
-- Jede Fachtabelle registriert neue Zeilen automatisch über einen
-- AFTER-INSERT-Trigger, der pm.register_object(<objektart>) ausführt, und
-- entfernt den Registereintrag über einen BEFORE-DELETE-Trigger mit
-- pm.deregister_object(<objektart>). Beide Funktionen sind SECURITY DEFINER
-- (Eigentümer schema_owner): editor erhält bewusst keine unmittelbaren
-- Schreibrechte auf pm.object_registry, kann aber über die eigene Fachzeile
-- (Fachtabellenrechte) den Registereintrag mittelbar anlegen bzw. entfernen.
-- Scheitert die Registrierung, wird die auslösende Fachzeile innerhalb
-- derselben Anweisung zurückgenommen. Bei der gewöhnlichen Bearbeitung als
-- editor kann damit weder eine Registerzeile ohne Fachobjekt noch ein
-- Fachobjekt ohne Registerzeile entstehen.
--
-- pm.objects (die gemeinsame Lesesicht über alle Fachtabellen) entsteht erst
-- mit der ersten echten Fachtabelle (Phase B, nicht Teil dieses Standes).

SET ROLE schema_owner;

CREATE TABLE pm.object_types (
    key        text PRIMARY KEY,
    table_name regclass UNIQUE,

    CONSTRAINT object_types_key_has_valid_format
        CHECK (key ~ '^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$')
);

COMMENT ON TABLE pm.object_types IS
    'Verwaltete Zuordnung zwischen Objektart und zuständiger Fachtabelle. '
    'table_name ist NULL, bis die zuständige Fachtabellen-Migration sie setzt.';
COMMENT ON COLUMN pm.object_types.key IS
    'Unveränderlicher technischer Schlüssel der Objektart, z. B. "issue" oder "kep_lite".';
COMMENT ON COLUMN pm.object_types.table_name IS
    'Fachtabelle, deren Zeilen sich unter dieser Objektart registrieren dürfen. '
    'NULL, solange die Fachtabelle noch nicht existiert. Nach dem erstmaligen '
    'Setzen darf die Zuordnung nur durch eine ausdrücklich geprüfte '
    'Schema-Migration geändert werden.';

CREATE TABLE pm.object_registry (
    id          uuid PRIMARY KEY,
    object_type text NOT NULL
        REFERENCES pm.object_types(key)
        ON DELETE RESTRICT
);

COMMENT ON TABLE pm.object_registry IS
    'Rein technisches Verzeichnis: welche Objektkennung existiert, zu welcher '
    'Objektart gehört sie. Kein fachlicher Teil des Objekts — title, '
    'created_at und andere Fachfelder bleiben in der Fachtabelle. Wird '
    'ausschließlich über pm.register_object()/pm.deregister_object() '
    'geschrieben, nie unmittelbar durch editor.';
COMMENT ON COLUMN pm.object_registry.id IS
    'Identisch mit der id der registrierenden Fachzeile, kein eigener Default.';
COMMENT ON COLUMN pm.object_registry.object_type IS
    'Objektart der registrierten Fachzeile; verweist auf pm.object_types.key.';

-- Generische Registrierungs-Triggerfunktion für AFTER-INSERT-Trigger auf
-- Fachtabellen, z. B.:
--   CREATE TRIGGER issues_register_object
--       AFTER INSERT ON pm.issues
--       FOR EACH ROW
--       EXECUTE FUNCTION pm.register_object('issue');
--
-- Prüft nicht nur, dass die angegebene Objektart existiert, sondern auch,
-- dass pm.object_types.table_name tatsächlich auf die auslösende Tabelle
-- (TG_RELID) verweist. Ohne diese Prüfung wäre table_name reine
-- Dokumentation statt einer durchgesetzten Integritätsregel — jede Tabelle
-- könnte sich sonst unter einer fremden Objektart registrieren.
CREATE FUNCTION pm.register_object()
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

    IF v_table_name IS NULL THEN
        RAISE EXCEPTION 'Objektart % besitzt noch keine zugeordnete Fachtabelle', v_object_type
            USING ERRCODE = '23514';
    END IF;

    IF v_table_name <> TG_RELID THEN
        RAISE EXCEPTION
            'Objektart % gehört zu %, nicht zu %',
            v_object_type, v_table_name, TG_RELID::regclass
            USING ERRCODE = '23514';
    END IF;

    INSERT INTO pm.object_registry (id, object_type)
    VALUES (NEW.id, v_object_type);

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.register_object() IS
    'AFTER-INSERT-Triggerfunktion für Fachtabellen. Erwartet die Objektart als '
    'Triggerargument, prüft deren Existenz und dass pm.object_types.table_name '
    'auf die auslösende Tabelle verweist, und registriert NEW.id — andernfalls '
    'wird die gesamte Fachzeilen-Einfügung zurückgenommen.';

REVOKE ALL ON FUNCTION pm.register_object() FROM PUBLIC;

-- Generische Deregistrierungs-Triggerfunktion für BEFORE-DELETE-Trigger auf
-- Fachtabellen, z. B.:
--   CREATE TRIGGER issues_deregister_object
--       BEFORE DELETE ON pm.issues
--       FOR EACH ROW
--       EXECUTE FUNCTION pm.deregister_object('issue');
--
-- Symmetrisch zu pm.register_object(): prüft vor dem Löschen, dass die
-- angegebene Objektart zur auslösenden Tabelle passt und dass für OLD.id eine
-- passende Registerzeile besteht. Fehlt die Registerzeile, ist das eine
-- bereits beschädigte Systeminvariante — die Fachzeile wird dann NICHT
-- klaglos gelöscht (kein stiller Erfolg), sondern die Löschung schlägt fehl.
-- Bestehen noch blockierende Abhängigkeiten (pm.object_relations,
-- pm.object_origins, jeweils ON DELETE RESTRICT auf pm.object_registry),
-- scheitert bereits das DELETE FROM pm.object_registry und damit die gesamte
-- Fachzeilen-Löschung.
CREATE FUNCTION pm.deregister_object()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pm
AS $$
DECLARE
    v_object_type     text;
    v_table_name      regclass;
    v_registered_type text;
BEGIN
    IF TG_NARGS <> 1 THEN
        RAISE EXCEPTION
            'pm.deregister_object() auf %.% erwartet genau ein Objektart-Argument',
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

    IF v_table_name IS NULL OR v_table_name <> TG_RELID THEN
        RAISE EXCEPTION
            'Objektart % gehört nicht zu %',
            v_object_type, TG_RELID::regclass
            USING ERRCODE = '23514';
    END IF;

    SELECT r.object_type
      INTO v_registered_type
      FROM pm.object_registry AS r
     WHERE r.id = OLD.id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Objekt % ist nicht im Register vorhanden', OLD.id
            USING ERRCODE = '23514';
    END IF;

    IF v_registered_type <> v_object_type THEN
        RAISE EXCEPTION
            'Objekt % ist als % registriert, nicht als %',
            OLD.id, v_registered_type, v_object_type
            USING ERRCODE = '23514';
    END IF;

    DELETE FROM pm.object_registry
     WHERE id = OLD.id
       AND object_type = v_object_type;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Passende Registerzeile für Objekt % konnte nicht entfernt werden',
            OLD.id
            USING ERRCODE = '23514';
    END IF;

    RETURN OLD;
END;
$$;

COMMENT ON FUNCTION pm.deregister_object() IS
    'BEFORE-DELETE-Triggerfunktion für Fachtabellen. Prüft Objektart, '
    'zuständige Tabelle und das Bestehen der Registerzeile, bevor sie diese '
    'löscht, und prüft nach dem DELETE, dass tatsächlich eine Zeile entfernt '
    'wurde. Blockierende Fremdschlüssel aus pm.object_relations bzw. '
    'pm.object_origins lassen die gesamte Fachzeilen-Löschung scheitern.';

REVOKE ALL ON FUNCTION pm.deregister_object() FROM PUBLIC;

-- pm.object_types ist verwaltete Konfiguration: migrator legt Objektarten an
-- und setzt table_name, sobald die zuständige Fachtabelle existiert.
-- editor und reader dürfen pm.object_types und pm.object_registry nur lesen;
-- unmittelbare Schreibrechte auf pm.object_registry werden nicht vergeben.
GRANT SELECT, INSERT, UPDATE, DELETE ON pm.object_types TO migrator;
GRANT SELECT ON pm.object_types, pm.object_registry TO editor, reader;

RESET ROLE;
