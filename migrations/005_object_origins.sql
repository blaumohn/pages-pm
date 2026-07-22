-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Ein migriertes Objekt ist ein vollständig typisiertes pm.objects-Objekt.
-- Die Herkunft ist eine zusätzliche, nur begrenzt intern prüfbare Aussage.
--
-- Eine vorhandene Zeile bedeutet, dass das Objekt aus einer externen Quelle
-- übernommen wurde. Fehlt die Zeile, ist das Objekt innerhalb von Pages PM
-- entstanden. Ein zusätzliches migrated-Feld ist daher nicht nötig.
--
-- pm.objects.created_at ist der Zeitpunkt, zu dem das Objekt in Pages PM
-- angelegt wurde. Bei einem migrierten Objekt dient dieser Wert zugleich als
-- interner Importzeitpunkt. Ein zusätzliches imported_at wäre daher für das
-- derzeitige Modell redundant.
--
-- migration_note ist eine optionale Sprachkarte, weil sie eine von Menschen
-- verfasste und gelesene fachliche Aussage zur Normalisierung enthält.
-- source_system und source_reference bleiben dagegen text: nicht zu
-- übersetzende technische bzw. externe Kennungen.

SET ROLE schema_owner;

CREATE TABLE pm.object_origins (
    object_id uuid PRIMARY KEY
        REFERENCES pm.objects(id)
        ON DELETE CASCADE,

    source_system     text NOT NULL,
    source_reference  text NOT NULL,
    source_created_at timestamptz,
    migration_note    jsonb,

    CONSTRAINT object_origins_source_system_has_valid_format
        CHECK (
            source_system ~ '^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$'
        ),

    CONSTRAINT object_origins_source_reference_not_blank
        CHECK (
            btrim(source_reference) <> ''
        ),

    CONSTRAINT object_origins_migration_note_is_nonempty_language_map
        CHECK (
            migration_note IS NULL
            OR (
                jsonb_typeof(migration_note) = 'object'
                AND migration_note <> '{}'::jsonb
                AND NOT jsonb_path_exists(
                    migration_note,
                    '$.* ? (@.type() != "string" || @ == "")'
                )
            )
        ),

    CONSTRAINT object_origins_unique_source
        UNIQUE (source_system, source_reference)
);

COMMENT ON TABLE pm.object_origins IS
    'Unmittelbare externe Herkunft normalisierter und in Pages PM typisierter Objekte.';
COMMENT ON COLUMN pm.object_origins.object_id IS
    'Objekt mit höchstens einer unmittelbaren externen Herkunft.';
COMMENT ON COLUMN pm.object_origins.source_system IS
    'Normalisierter technischer Quellschlüssel wie "jira" oder "filesystem".';
COMMENT ON COLUMN pm.object_origins.source_reference IS
    'Möglichst eindeutige Kennung innerhalb des Quellsystems, z. B. "PROJECT-184" oder ein Dateipfad.';
COMMENT ON COLUMN pm.object_origins.source_created_at IS
    'Übernommener ursprünglicher Erstellungszeitpunkt; durch Pages PM nicht intern beweisbar.';
COMMENT ON COLUMN pm.object_origins.migration_note IS
    'Optionale mehrsprachige Anmerkung zur fachlichen Normalisierung oder zu Unsicherheiten des Imports.';
COMMENT ON CONSTRAINT object_origins_unique_source
    ON pm.object_origins IS
    'Verhindert, dass dieselbe externe Quelle versehentlich mehrfach importiert wird.';

-- Prüft die optionale migration_note gegen die in pm.languages konfigurierten
-- Sprachen. Die CHECK-Bedingung der Tabelle prüft zusätzlich die statische
-- Grundform der Sprachkarte.
CREATE FUNCTION pm.validate_object_origin_language_maps()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pm.validate_language_map(NEW.migration_note, true);
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.validate_object_origin_language_maps() IS
    'Prüft die optionale pm.object_origins.migration_note gegen die systemweite Sprachkonfiguration.';

CREATE TRIGGER object_origins_validate_language_maps
    BEFORE INSERT OR UPDATE OF migration_note
    ON pm.object_origins
    FOR EACH ROW
    EXECUTE FUNCTION pm.validate_object_origin_language_maps();

-- object_id, source_system und source_reference bilden gemeinsam die Identität
-- der Herkunftsangabe. build darf diese nicht per UPDATE verändern; eine andere
-- Herkunftsidentität wird durch DELETE und INSERT abgebildet.
--
-- migration_note und source_created_at sind nachträglich korrigierbare
-- Herkunftsmetadaten. Für sie erhält build ein spaltenbezogenes UPDATE-Recht.
GRANT SELECT, INSERT, DELETE
    ON pm.object_origins
    TO build;
GRANT UPDATE (migration_note, source_created_at)
    ON pm.object_origins
    TO build;

RESET ROLE;
