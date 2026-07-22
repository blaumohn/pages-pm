-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Beziehungsarten sind keine bloßen ENUM-Werte, sondern fachliche Regeln:
-- Bedeutung, erlaubte Quell-/Zieltypen, Kardinalität, Beschreibungspflicht
-- und Zyklusverbot müssen festgelegt sein, bevor pm.object_relations
-- (007_object_relations.sql) Einträge zulässt. Sonst entsteht ein mehrdeutiges
-- Netz (z. B. "references" und "derived_from" austauschbar für denselben Fall).
--
-- Anfänglicher Satz bewusst klein gehalten: derived_from, implements,
-- supersedes, references. "assigned_to" und "documents" sind ausdrücklich
-- NICHT hier vertreten — assigned_to gehört als klarer Fremdschlüssel in die
-- jeweilige Fachtabelle (z. B. pm.issues.sprint_id), "documents" ist zu
-- mehrdeutig und wird erst bei einem echten Anwendungsfall präzisiert.
--
-- Richtung von derived_from: Quellobjekt → Zielobjekt bedeutet "Quellobjekt
-- wurde fachlich aus Zielobjekt abgeleitet" (Beispiel: KEP-lite --derived_from--> Vorgang,
-- der Vorgang ist die Grundlage, das KEP-lite das daraus abgeleitete Objekt).

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
    source_type            pm.object_type NOT NULL,
    target_type            pm.object_type NOT NULL,
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

INSERT INTO pm.relation_types (
    key,
    title,
    description,
    description_required,
    acyclic
) VALUES
    (
        'derived_from',
        '{"de": "abgeleitet von", "en": "derived from"}'::jsonb,
        '{
            "de": "Das Quellobjekt wurde fachlich aus dem Zielobjekt abgeleitet.",
            "en": "The source object was derived from the target object."
        }'::jsonb,
        false, true
    ),
    (
        'implements',
        '{"de": "setzt um", "en": "implements"}'::jsonb,
        '{
            "de": "Das Quellobjekt setzt Anforderungen oder Entscheidungen des Zielobjekts um.",
            "en": "The source object implements requirements or decisions of the target object."
        }'::jsonb,
        false, false
    ),
    (
        'supersedes',
        '{"de": "ersetzt", "en": "supersedes"}'::jsonb,
        '{
            "de": "Das Quellobjekt ersetzt das Zielobjekt fachlich.",
            "en": "The source object supersedes the target object."
        }'::jsonb,
        true, true
    ),
    (
        'references',
        '{"de": "verweist auf", "en": "references"}'::jsonb,
        '{
            "de": "Das Quellobjekt verweist informativ auf das Zielobjekt, ohne eine stärkere fachliche Aussage. Diese Beziehungsart darf nur verwendet werden, wenn keine genauere Beziehungsart passt.",
            "en": "The source object informatively references the target object without making a stronger claim. Use this relation type only when no more specific relation type applies."
        }'::jsonb,
        true, false
    );

-- Beide Tabellen enthalten verwaltete Konfiguration wie pm.languages und
-- pm.areas. build darf sie lesen; das ist auch für die Trigger-Prüfungen in
-- 007_object_relations.sql erforderlich.
--
-- Neue Beziehungsarten und Endpunktregeln legt migrator beziehungsweise
-- schema_owner an.
GRANT SELECT
    ON pm.relation_types, pm.relation_type_endpoints
    TO build;

RESET ROLE;
