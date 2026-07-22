-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Eine externe Archiveinheit wird durch fachliche Normalisierung zu einem
-- internen Pages-PM-Objekt (Migration: extern → intern). Mehrere externe
-- Archiveinheiten dürfen gemeinsam zu einem internen Objekt werden (ein
-- internes Objekt kann null bis viele Herkunftszeilen besitzen), aber eine
-- externe Archiveinheit wird höchstens einem internen Objekt zugeordnet.
-- Diese Regel verhindert, dass Pages PM einen unklar strukturierten
-- Archivbestand künstlich vervielfacht.
--
-- source_system bezeichnet Art oder Bestand der externen Quelle (z. B.
-- jira_archive oder filesystem). source_reference ist die übergeordnete
-- Kennung innerhalb dieser Quelle (z. B. J01-123 oder ein Dateipfad).
-- source_locator bezeichnet einen genaueren Ausschnitt innerhalb der
-- source_reference (z. B. comment:4, lines:3-12 oder heading:security). Ist
-- source_locator NULL, gilt die gesamte source_reference als Archiveinheit;
-- Ein leerer oder nur aus Leerraum bestehender Text würde inhaltlich
-- ebenfalls „keinen Ausschnitt“ bedeuten und wird daher ausgeschlossen — es
-- gibt so nur die zwei klaren Zustände "gesamte externe Einheit" (NULL) und
-- "bestimmter Ausschnitt" (nichtleerer Text).
--
-- source_reference und source_locator müssen zusätzlich bereits in
-- getrimmter Form vorliegen (kein führender/nachgestellter Leerraum): die
-- Eindeutigkeitsbedingung vergleicht die Rohwerte, nicht btrim(...). Ohne
-- diese Normalform könnten " J01-123" und "J01-123" als verschiedene externe
-- Einheiten durchgehen, obwohl sie dieselbe bezeichnen. Eingaben werden
-- bewusst zurückgewiesen statt still normalisiert, damit Fehler in
-- Importdateien sichtbar bleiben.
--
-- migration_note ist eine optionale Sprachkarte, weil sie eine von Menschen
-- verfasste und gelesene fachliche Aussage zur Normalisierung enthält.
-- source_system und source_reference bleiben dagegen text: nicht zu
-- übersetzende technische bzw. externe Kennungen.

SET ROLE schema_owner;

CREATE TABLE pm.object_origins (
    id                 uuid PRIMARY KEY DEFAULT uuidv7(),

    object_id          uuid NOT NULL
        REFERENCES pm.object_registry(id)
        ON DELETE RESTRICT,

    source_system      text NOT NULL,
    source_reference   text NOT NULL,
    source_locator     text,
    source_created_at  timestamptz,
    migration_note     jsonb,

    CONSTRAINT object_origins_source_system_has_valid_format
        CHECK (
            source_system ~ '^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$'
        ),

    CONSTRAINT object_origins_source_reference_is_trimmed
        CHECK (
            source_reference = btrim(source_reference)
            AND source_reference <> ''
        ),

    CONSTRAINT object_origins_source_locator_is_trimmed
        CHECK (
            source_locator IS NULL
            OR (
                source_locator = btrim(source_locator)
                AND source_locator <> ''
            )
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
        UNIQUE NULLS NOT DISTINCT (source_system, source_reference, source_locator)
);

COMMENT ON TABLE pm.object_origins IS
    'Externe Herkunft normalisierter und in Pages PM typisierter Objekte. '
    'Mehrere Zeilen je Objekt möglich (mehrere externe Einheiten → ein '
    'internes Objekt); dieselbe externe Einheit gehört höchstens einem '
    'internen Objekt.';
COMMENT ON COLUMN pm.object_origins.id IS
    'Technische Kennung der Herkunftszeile; nicht Teil der externen Identität.';
COMMENT ON COLUMN pm.object_origins.object_id IS
    'Internes Objekt, dem diese externe Herkunft zugeordnet ist. Ein Objekt '
    'kann mehrere Herkunftszeilen besitzen.';
COMMENT ON COLUMN pm.object_origins.source_system IS
    'Normalisierter technischer Quellschlüssel wie "jira_archive" oder "filesystem".';
COMMENT ON COLUMN pm.object_origins.source_reference IS
    'Übergeordnete, bereits getrimmte Kennung innerhalb des Quellsystems, '
    'z. B. "J01-123" oder ein Dateipfad.';
COMMENT ON COLUMN pm.object_origins.source_locator IS
    'Optionaler genauerer, bereits getrimmter Ausschnitt innerhalb der '
    'source_reference, z. B. "comment:4", "lines:3-12" oder '
    '"heading:security". NULL bedeutet: die gesamte source_reference gilt '
    'als Archiveinheit.';
COMMENT ON COLUMN pm.object_origins.source_created_at IS
    'Übernommener ursprünglicher Erstellungszeitpunkt; durch Pages PM nicht intern beweisbar.';
COMMENT ON COLUMN pm.object_origins.migration_note IS
    'Optionale mehrsprachige Anmerkung zur fachlichen Normalisierung oder zu Unsicherheiten des Imports.';
COMMENT ON CONSTRAINT object_origins_unique_source
    ON pm.object_origins IS
    'Verhindert, dass dieselbe externe Archiveinheit (source_system, '
    'source_reference, source_locator) versehentlich mehrfach normalisiert '
    'wird — unabhängig davon, welchem internen Objekt sie jeweils zugeordnet '
    'werden soll. Mehrere unterschiedliche Einheiten dürfen weiterhin '
    'demselben object_id zugeordnet sein.';

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

-- source_system, source_reference und source_locator bilden gemeinsam die
-- unveränderliche externe Identität der Herkunftsangabe. object_id bestimmt
-- das interne Zielobjekt. editor darf keines dieser Felder per UPDATE ändern;
-- eine andere Zuordnung oder Herkunftsidentität wird durch DELETE und INSERT
-- abgebildet.
--
-- migration_note und source_created_at sind nachträglich korrigierbare
-- Herkunftsmetadaten. Für sie erhält editor ein spaltenbezogenes UPDATE-Recht.
GRANT SELECT, INSERT, DELETE
    ON pm.object_origins
    TO editor;
GRANT UPDATE (migration_note, source_created_at)
    ON pm.object_origins
    TO editor;

GRANT SELECT
    ON pm.object_origins
    TO reader;

RESET ROLE;
