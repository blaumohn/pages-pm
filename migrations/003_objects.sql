-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Gemeinsame Grundform aller fachlichen Objekte. Die Fachtabellen referenzieren
-- pm.objects über ihre eigene id als 1:1-Fremdschlüssel (siehe 008_sprints.sql,
-- 009_issues.sql, ...). object_type legt fest, zu welcher Fachtabelle die id
-- gehören muss — die jeweilige Fachtabelle prüft diese Zuordnung mit
-- pm.enforce_object_type(). Fachliche Erzeugungsfunktionen legen Grundzeile
-- und Fachzeile später gemeinsam in einer Transaktion an; bis dahin ist eine
-- verwaiste Grundzeile ohne Fachzeile technisch noch möglich.
--
-- title ist eine Sprachkarte, zum Beispiel:
-- {"de": "Anmeldung umsetzen", "en": "Implement login"}
--
-- Die CHECK-Bedingung prüft eine statische Grundform der Sprachkarte.
-- Vollständigkeit, Zulässigkeit und nicht leere Inhalte der konfigurierten
-- Sprachen prüft pm.validate_object_language_maps() mithilfe von
-- pm.validate_language_map() und pm.languages aus 002_languages.sql.

SET ROLE schema_owner;

-- Jeder Wert bezeichnet genau eine anerkannte fachliche Objektart. Für jede
-- Objektart wird eine eigene Fachtabelle angelegt. Ein allgemeiner Auffangtyp
-- wie "document" ist absichtlich nicht vorgesehen. Neue fachlich begründete
-- Objektarten können später durch Migrationen ergänzt werden (ALTER TYPE ...
-- ADD VALUE) — die deklarierte Reihenfolge hat dabei keine fachliche
-- Bedeutung (keine Rang- oder Sortierordnung), nur PostgreSQL-interne
-- Vergleichsreihenfolge.
CREATE TYPE pm.object_type AS ENUM (
    'sprint',
    'issue',
    'adr',
    'drift_report',
    'feature_matrix',
    'jira_work_document',
    'kep_lite',
    'postmortem',
    'policy',
    'runbook',
    'flow_spec',
    'system_spec',
    'test_matrix'
);

CREATE TABLE pm.objects (
    id          uuid           PRIMARY KEY DEFAULT uuidv7(),
    object_type pm.object_type NOT NULL,
    created_at  timestamptz    NOT NULL DEFAULT statement_timestamp(),
    title       jsonb          NOT NULL,

    CONSTRAINT objects_title_is_nonempty_language_map
        CHECK (
            jsonb_typeof(title) = 'object'
            AND title <> '{}'::jsonb
            AND NOT jsonb_path_exists(
                title,
                '$.* ? (@.type() != "string" || @ == "")'
            )
        )
);

COMMENT ON TABLE pm.objects IS
    'Gemeinsame Grundform aller fachlichen Objekte wie Vorgänge, Sprints und Dokumente.';
COMMENT ON COLUMN pm.objects.id IS
    'Unveränderliche, zeitlich sortierbare UUIDv7.';
COMMENT ON COLUMN pm.objects.object_type IS
    'Legt fest, in welcher Fachtabelle die zugehörige Zeile liegt.';
COMMENT ON COLUMN pm.objects.created_at IS
    'Unveränderlicher Erstellungszeitpunkt.';
COMMENT ON COLUMN pm.objects.title IS
    'Nicht leere Sprachkarte, z. B. {"de": "...", "en": "..."}.';

CREATE FUNCTION pm.validate_object_language_maps()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pm.validate_language_map(NEW.title);
    RETURN NEW;
END;
$$;

CREATE TRIGGER objects_validate_language_maps
    BEFORE INSERT OR UPDATE OF title
    ON pm.objects
    FOR EACH ROW
    EXECUTE FUNCTION pm.validate_object_language_maps();

CREATE FUNCTION pm.prevent_object_identity_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id THEN
        RAISE EXCEPTION 'pm.objects.id darf nicht geändert werden'
            USING ERRCODE = '23514';
    END IF;
    IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'pm.objects.created_at darf nicht geändert werden'
            USING ERRCODE = '23514';
    END IF;
    IF NEW.object_type IS DISTINCT FROM OLD.object_type THEN
        RAISE EXCEPTION 'pm.objects.object_type darf nicht geändert werden'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER objects_prevent_identity_change
    BEFORE UPDATE OF id, created_at, object_type
    ON pm.objects
    FOR EACH ROW
    EXECUTE FUNCTION pm.prevent_object_identity_change();

-- Verteidigung in der Tiefe: verwendet von 008_sprints.sql, 009_issues.sql
-- und den späteren Migrationen der weiteren Fachtypen als
-- BEFORE INSERT OR UPDATE OF id-Trigger, z. B.
-- EXECUTE FUNCTION pm.enforce_object_type('sprint').
--
-- Der Fremdschlüssel auf pm.objects(id) bleibt zusätzlich bestehen: Er sichert
-- die Existenz der Grundzeile, nicht deren fachlichen Typ.
CREATE FUNCTION pm.enforce_object_type()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    expected_type pm.object_type;
    actual_type   pm.object_type;
BEGIN
    IF TG_NARGS <> 1 THEN
        RAISE EXCEPTION
            'Trigger % auf %.% erwartet genau ein object_type-Argument',
            TG_NAME, TG_TABLE_SCHEMA, TG_TABLE_NAME
            USING ERRCODE = '22023';
    END IF;

    expected_type := TG_ARGV[0]::pm.object_type;

    SELECT object_type
      INTO actual_type
      FROM pm.objects
     WHERE id = NEW.id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Keine Grundzeile in pm.objects für %.%.id=%',
            TG_TABLE_SCHEMA, TG_TABLE_NAME, NEW.id
            USING ERRCODE = '23503';
    END IF;

    IF actual_type <> expected_type THEN
        RAISE EXCEPTION
            '%.% erwartet object_type=%, für id=% wurde jedoch % gefunden',
            TG_TABLE_SCHEMA, TG_TABLE_NAME, expected_type, NEW.id, actual_type
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

-- pm.objects enthält gewöhnliche Fachdaten. Im MVP darf build direkt per DML
-- lesen und schreiben; Constraints und Trigger erzwingen weiterhin alle
-- Datenbankregeln unabhängig von der Anwendung.
GRANT SELECT, INSERT, UPDATE, DELETE
    ON pm.objects
    TO build;

RESET ROLE;
