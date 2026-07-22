-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Bereiche sind verwaltete Klassifikationen wie build, deploy oder
-- http_runtime, keine freien Zeichenketten. Ein Objekt kann mehreren Bereichen
-- zugeordnet sein (pm.object_areas).
--
-- Ein Bereich, dem noch Objekte zugeordnet sind, darf nicht gelöscht werden
-- (ON DELETE RESTRICT). Die Zuordnungen müssen zuerst entfernt werden.

SET ROLE schema_owner;

CREATE TABLE pm.areas (
    id          uuid  PRIMARY KEY DEFAULT uuidv7(),
    key         text  NOT NULL UNIQUE,
    title       jsonb NOT NULL,
    description jsonb,

    CONSTRAINT areas_key_has_valid_format
        CHECK (key ~ '^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$'),

    CONSTRAINT areas_title_is_nonempty_language_map
        CHECK (
            jsonb_typeof(title) = 'object'
            AND title <> '{}'::jsonb
            AND NOT jsonb_path_exists(
                title,
                '$.* ? (@.type() != "string" || @ == "")'
            )
        ),

    CONSTRAINT areas_description_is_nonempty_language_map
        CHECK (
            description IS NULL
            OR (
                jsonb_typeof(description) = 'object'
                AND description <> '{}'::jsonb
                AND NOT jsonb_path_exists(
                    description,
                    '$.* ? (@.type() != "string" || @ == "")'
                )
            )
        )
);

COMMENT ON TABLE pm.areas IS
    'Verwaltete fachliche Bereiche wie build, deploy oder http_runtime.';
COMMENT ON COLUMN pm.areas.id IS
    'Unveränderliche Kennung des Bereichs.';
COMMENT ON COLUMN pm.areas.key IS
    'Unveränderlicher technischer Schlüssel wie "http_runtime", unabhängig vom Titel.';
COMMENT ON COLUMN pm.areas.title IS
    'Nicht leere Sprachkarte mit dem sichtbaren Namen des Bereichs.';
COMMENT ON COLUMN pm.areas.description IS
    'Optionale nicht leere Sprachkarte mit der fachlichen Beschreibung.';

-- Prüft title und die optionale description gegen die in pm.languages
-- konfigurierten Sprachen. Die CHECK-Bedingungen der Tabelle prüfen
-- zusätzlich die statische Grundform der Sprachkarten.
CREATE FUNCTION pm.validate_area_language_maps()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pm.validate_language_map(NEW.title);
    PERFORM pm.validate_language_map(NEW.description, true);
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.validate_area_language_maps() IS
    'Prüft pm.areas.title und die optionale pm.areas.description gegen die systemweite Sprachkonfiguration.';

CREATE TRIGGER areas_validate_language_maps
    BEFORE INSERT OR UPDATE OF title, description
    ON pm.areas
    FOR EACH ROW
    EXECUTE FUNCTION pm.validate_area_language_maps();

CREATE FUNCTION pm.prevent_area_identity_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id THEN
        RAISE EXCEPTION 'pm.areas.id darf nicht geändert werden'
            USING ERRCODE = '23514';
    END IF;
    IF NEW.key IS DISTINCT FROM OLD.key THEN
        RAISE EXCEPTION 'pm.areas.key darf nicht geändert werden'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER areas_prevent_identity_change
    BEFORE UPDATE OF id, key
    ON pm.areas
    FOR EACH ROW
    EXECUTE FUNCTION pm.prevent_area_identity_change();

CREATE TABLE pm.object_areas (
    object_id uuid NOT NULL
        REFERENCES pm.objects(id)
        ON DELETE CASCADE,

    area_id   uuid NOT NULL
        REFERENCES pm.areas(id)
        ON DELETE RESTRICT,

    PRIMARY KEY (object_id, area_id)
);

COMMENT ON TABLE pm.object_areas IS
    'Mehrfachzuordnung fachlicher Objekte zu Bereichen. Der zusammengesetzte '
    'Primärschlüssel verhindert doppelte Zuordnungen.';

-- pm.areas ist verwaltete Klassifikation wie pm.languages und
-- pm.relation_types: build darf lesen; neue Bereiche legt
-- migrator beziehungsweise schema_owner an.
--
-- pm.object_areas enthält die eigentlichen fachlichen Zuordnungen. Kein
-- UPDATE: der zusammengesetzte Primärschlüssel (object_id, area_id) ist die
-- einzige Information der Tabelle — eine geänderte Zuordnung ist fachlich
-- DELETE+INSERT, nicht Bearbeitung.
GRANT SELECT
    ON pm.areas
    TO build;

GRANT SELECT, INSERT, DELETE
    ON pm.object_areas
    TO build;

RESET ROLE;
