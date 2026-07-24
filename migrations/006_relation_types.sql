-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Beziehungsarten sind keine bloßen ENUM-Werte, sondern fachliche Regeln:
-- Bedeutung, erlaubte Quell-/Zieltypen, Kardinalität, Beschreibungspflicht
-- und Zyklusverbot müssen festgelegt sein, bevor pm.object_relations
-- (007_object_relations.sql) Einträge zulässt. Sonst entsteht ein mehrdeutiges
-- Netz (z. B. "references" und "derived_from" austauschbar für denselben Fall).
--
-- Diese Kernmigration legt nur Struktur und Prüfungen fest, jedoch keine
-- konkreten Beziehungsarten. Diese gehören zur konkreten Pages-PM-
-- Installation, nicht zum Kernschema, und werden nach dieser Migration durch
-- project/002_relation_types.sql ergänzt. Dort werden die drei anfänglichen
-- Beziehungsarten derived_from, implements und references sowie der
-- Verzicht auf allgemeine Beziehungsarten assigned_to, documents und
-- supersedes begründet.
--
-- source_type und target_type in pm.relation_type_endpoints verweisen auf
-- pm.object_types.key statt auf ein PostgreSQL-Enum. Das entspricht
-- 003_object_registry.sql, wo Objektarten ebenfalls in einer Tabelle geführt
-- werden.

SET ROLE schema_owner;

CREATE TABLE pm.relation_types (
    key                   text    PRIMARY KEY,
    title                 jsonb   NOT NULL,
    description           jsonb   NOT NULL,
    description_required  boolean NOT NULL DEFAULT false,
    acyclic               boolean NOT NULL DEFAULT false,

    CONSTRAINT relation_types_key_has_valid_format
        CHECK (key ~ '^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$'),

    CONSTRAINT relation_types_title_is_nonempty_language_map
        CHECK (
            jsonb_typeof(title) = 'object'
            AND title <> '{}'::jsonb
            AND NOT jsonb_path_exists(
                title, '$.* ? (@.type() != "string" || @ == "")'
            )
        ),

    CONSTRAINT relation_types_description_is_nonempty_language_map
        CHECK (
            jsonb_typeof(description) = 'object'
            AND description <> '{}'::jsonb
            AND NOT jsonb_path_exists(
                description, '$.* ? (@.type() != "string" || @ == "")'
            )
        )
);

COMMENT ON TABLE pm.relation_types IS
    'Fachliche Definition jeder erlaubten Beziehungsart (Bedeutung ist Pflicht, '
    'nicht optional wie bei pm.areas.description).';
COMMENT ON COLUMN pm.relation_types.key IS
    'Unveränderlicher technischer Schlüssel der Beziehungsart.';
COMMENT ON COLUMN pm.relation_types.description IS
    'Pflichtfeld: die fachliche Bedeutung der Beziehungsart, nicht der Einzelfall.';
COMMENT ON COLUMN pm.relation_types.description_required IS
    'Global je Beziehungsart (nicht je Endpunktkombination): wenn wahr, muss '
    'jede konkrete Beziehung dieser Art eine eigene Beschreibung '
    '(pm.object_relations.description) tragen.';
COMMENT ON COLUMN pm.relation_types.acyclic IS
    'Wenn wahr, prüft 007_object_relations.sql, dass keine Kette dieser Art einen Zyklus bildet.';

-- Prüft title und description gegen die in pm.languages konfigurierten
-- Sprachen. Die CHECK-Bedingungen der Tabelle prüfen zusätzlich die
-- statische Grundform der Sprachkarten.
CREATE FUNCTION pm.validate_relation_type_language_maps()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pm.validate_language_map(NEW.title);
    PERFORM pm.validate_language_map(NEW.description);
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.validate_relation_type_language_maps() IS
    'Prüft pm.relation_types.title und pm.relation_types.description gegen die systemweite Sprachkonfiguration.';

CREATE TRIGGER relation_types_validate_language_maps
    BEFORE INSERT OR UPDATE OF title, description
    ON pm.relation_types
    FOR EACH ROW
    EXECUTE FUNCTION pm.validate_relation_type_language_maps();

CREATE FUNCTION pm.prevent_relation_type_key_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.key IS DISTINCT FROM OLD.key THEN
        RAISE EXCEPTION 'pm.relation_types.key darf nicht geändert werden'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.prevent_relation_type_key_change() IS
    'Verhindert Änderungen am technischen Schlüssel einer Beziehungsart.';

CREATE TRIGGER relation_types_prevent_key_change
    BEFORE UPDATE OF key
    ON pm.relation_types
    FOR EACH ROW
    EXECUTE FUNCTION pm.prevent_relation_type_key_change();

-- Erlaubte Endpunkt-Kombinationen je Beziehungsart. Bewusst noch UNBEFÜLLT:
-- die betroffenen Fachtabellen (pm.kep_lites, pm.policies, ...) existieren
-- noch nicht. Endpunkte werden zusammen mit der jeweiligen Fachtabellen-
-- Migration ergänzt. Eine Beziehungsart ohne Endpunktzeilen kann bis dahin
-- in keiner konkreten Beziehung verwendet werden (007_object_relations.sql
-- akzeptiert nur Kombinationen, die hier eingetragen sind).
CREATE TABLE pm.relation_type_endpoints (
    relation_type          text NOT NULL
        REFERENCES pm.relation_types(key)
        ON DELETE CASCADE,
    source_type            text NOT NULL
        REFERENCES pm.object_types(key)
        ON DELETE RESTRICT,
    target_type            text NOT NULL
        REFERENCES pm.object_types(key)
        ON DELETE RESTRICT,
    max_targets_per_source integer,
    max_sources_per_target integer,

    PRIMARY KEY (relation_type, source_type, target_type),

    CONSTRAINT relation_type_endpoints_max_targets_positive
        CHECK (max_targets_per_source IS NULL OR max_targets_per_source > 0),
    CONSTRAINT relation_type_endpoints_max_sources_positive
        CHECK (max_sources_per_target IS NULL OR max_sources_per_target > 0)
);

COMMENT ON TABLE pm.relation_type_endpoints IS
    'Erlaubte Quell-/Zieltyp-Kombinationen je Beziehungsart. NULL bei max_* bedeutet unbegrenzt.';
COMMENT ON COLUMN pm.relation_type_endpoints.max_targets_per_source IS
    'Höchste Zahl von Zielen je Quellobjekt innerhalb GENAU dieser Typkombination '
    '(nicht über alle Endpunktzeilen derselben Beziehungsart hinweg summiert); NULL = unbegrenzt.';
COMMENT ON COLUMN pm.relation_type_endpoints.max_sources_per_target IS
    'Höchste Zahl von Quellen je Zielobjekt innerhalb GENAU dieser Typkombination; NULL = unbegrenzt.';

-- Keine Beziehungsarten in dieser Kernmigration — siehe
-- project/002_relation_types.sql.

-- Beide Tabellen enthalten verwaltete Konfiguration wie pm.languages und
-- pm.areas. migrator legt Beziehungsarten und Endpunktregeln an, ändert
-- und löscht sie. editor und reader dürfen beide Tabellen nur lesen.
-- pm.enforce_object_relation_rules() (007_object_relations.sql) ist nicht
-- SECURITY DEFINER und läuft daher mit den Rechten des aufrufenden Benutzers
-- — editor braucht das Leserecht deshalb auch für die Trigger-Prüfung dort,
-- nicht nur für eigene Abfragen.
GRANT SELECT, INSERT, UPDATE, DELETE
    ON pm.relation_types, pm.relation_type_endpoints
    TO migrator;

GRANT SELECT
    ON pm.relation_types, pm.relation_type_endpoints
    TO editor, reader;

RESET ROLE;
