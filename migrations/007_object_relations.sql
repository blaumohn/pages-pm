-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Tatsächliche Beziehungen zwischen Objekten, geprüft gegen die Regeln aus
-- 006_relation_types.sql (pm.relation_types / pm.relation_type_endpoints).
-- Der zusammengesetzte Primärschlüssel lässt mehrere Beziehungsarten
-- zwischen denselben zwei Objekten zu (z. B. A --references--> B UND
-- A --implements--> B), aber jede Kombination (source, target, Art) nur einmal.

SET ROLE schema_owner;

CREATE TABLE pm.object_relations (
    source_id     uuid NOT NULL
        REFERENCES pm.objects(id)
        ON DELETE CASCADE,

    target_id     uuid NOT NULL
        REFERENCES pm.objects(id)
        ON DELETE CASCADE,

    relation_type text NOT NULL
        REFERENCES pm.relation_types(key)
        ON DELETE RESTRICT,

    description   jsonb,

    created_at    timestamptz NOT NULL
        DEFAULT statement_timestamp(),

    PRIMARY KEY (source_id, target_id, relation_type),

    CONSTRAINT object_relations_no_self_relation
        CHECK (source_id <> target_id),

    CONSTRAINT object_relations_description_is_nonempty_language_map
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

COMMENT ON TABLE pm.object_relations IS
    'Typübergreifende n:m-Beziehungen. Klare 1:n-Zuordnungen (z. B. issue.sprint_id) '
    'gehören NICHT hierher, sondern als Fremdschlüssel in die jeweilige Fachtabelle.';
COMMENT ON COLUMN pm.object_relations.description IS
    'Optionale Sprachkarte, erklärt den konkreten Einzelfall, nicht die Bedeutung '
    'der Beziehungsart (die steht in pm.relation_types.description). Pflicht, wenn '
    'pm.relation_types.description_required für diese Art wahr ist.';

-- Prüft die optionale description gegen die in pm.languages konfigurierten
-- Sprachen. Die CHECK-Bedingung der Tabelle prüft zusätzlich die statische
-- Grundform der Sprachkarte.
CREATE FUNCTION pm.validate_object_relation_language_maps()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pm.validate_language_map(NEW.description, true);
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.validate_object_relation_language_maps() IS
    'Prüft die optionale pm.object_relations.description gegen die systemweite Sprachkonfiguration.';

CREATE TRIGGER object_relations_validate_language_maps
    BEFORE INSERT OR UPDATE OF description
    ON pm.object_relations
    FOR EACH ROW
    EXECUTE FUNCTION pm.validate_object_relation_language_maps();

-- Zyklusprüfung als eigene Funktion: prüft, ob target_id source_id über Kanten
-- DERSELBEN Beziehungsart bereits erreichen kann (dann würde source→target
-- einen Zyklus schließen). Bei einem UPDATE wird die ersetzte alte Kante von
-- der Traversierung ausgeschlossen, sonst würde eine Zeile sich selbst blockieren.
-- Prüft NUR Zyklen innerhalb einer einzelnen Beziehungsart, nicht gemischt
-- über mehrere Arten hinweg (z. B. A--derived_from-->B--implements-->A wird
-- nicht erkannt) — das ist für den jetzigen Stand eine bewusste Grenze.
CREATE FUNCTION pm.object_relation_would_create_cycle(
    p_source_id              uuid,
    p_target_id              uuid,
    p_relation_type          text,
    p_excluded_source_id     uuid,
    p_excluded_target_id     uuid,
    p_excluded_relation_type text
) RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    WITH RECURSIVE reachable(id) AS (
        SELECT target_id
        FROM pm.object_relations
        WHERE source_id = p_target_id
          AND relation_type = p_relation_type
          AND NOT (
              p_excluded_relation_type IS NOT NULL
              AND relation_type = p_excluded_relation_type
              AND source_id = p_excluded_source_id
              AND target_id = p_excluded_target_id
          )

        UNION

        SELECT r.target_id
        FROM pm.object_relations r
        JOIN reachable x ON r.source_id = x.id
        WHERE r.relation_type = p_relation_type
          AND NOT (
              p_excluded_relation_type IS NOT NULL
              AND r.relation_type = p_excluded_relation_type
              AND r.source_id = p_excluded_source_id
              AND r.target_id = p_excluded_target_id
          )
    )
    SELECT EXISTS (SELECT 1 FROM reachable WHERE id = p_source_id);
$$;

COMMENT ON FUNCTION pm.object_relation_would_create_cycle IS
    'Prüft Erreichbarkeit target_id -> source_id über Kanten derselben Beziehungsart. '
    'p_excluded_* schließt die zu ersetzende Kante bei UPDATE aus der Traversierung aus.';

CREATE FUNCTION pm.enforce_object_relation_rules()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_source_type       pm.object_type;
    v_target_type       pm.object_type;
    v_relation          pm.relation_types%ROWTYPE;
    v_endpoint          pm.relation_type_endpoints%ROWTYPE;
    v_target_count      integer;
    v_source_count      integer;
    v_excluded_source_id     uuid := NULL;
    v_excluded_target_id     uuid := NULL;
    v_excluded_relation_type text := NULL;
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'pm.object_relations.created_at darf nicht geändert werden'
            USING ERRCODE = '23514';
    END IF;

    -- source_id/target_id/relation_type bilden gemeinsam die Identität der
    -- Beziehung (Primärschlüssel). Eine Änderung wäre keine Bearbeitung der
    -- bestehenden Beziehung, sondern fachlich das Löschen der alten und
    -- Anlegen einer neuen Beziehung — dafür gibt es DELETE+INSERT.
    -- Nur description ist über UPDATE veränderbar.
    IF TG_OP = 'UPDATE' AND (
        NEW.source_id IS DISTINCT FROM OLD.source_id
        OR NEW.target_id IS DISTINCT FROM OLD.target_id
        OR NEW.relation_type IS DISTINCT FROM OLD.relation_type
    ) THEN
        RAISE EXCEPTION
            'source_id/target_id/relation_type sind unveränderlich — statt UPDATE DELETE+INSERT verwenden'
            USING ERRCODE = '23514';
    END IF;

    -- Änderungen derselben Beziehungsart werden geordnet (Transaktionssperre),
    -- damit zwei gleichzeitige Transaktionen nicht denselben alten Zählstand
    -- sehen und dadurch Kardinalitäts- oder Zyklusregeln gemeinsam umgehen
    -- können (klassisches Lese-dann-Schreiben-Wettrennen ohne diese Sperre).
    -- Da relation_type bei UPDATE nicht mehr wechseln kann (s. o.), genügt
    -- eine einzelne Sperre auf NEW.relation_type für INSERT und UPDATE gleichermaßen.
    PERFORM pg_advisory_xact_lock(
        hashtextextended('pm.object_relations:' || NEW.relation_type, 0)
    );

    IF TG_OP = 'UPDATE' THEN
        v_excluded_source_id     := OLD.source_id;
        v_excluded_target_id     := OLD.target_id;
        v_excluded_relation_type := OLD.relation_type;
    END IF;

    SELECT object_type INTO v_source_type FROM pm.objects WHERE id = NEW.source_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Keine Grundzeile in pm.objects für source_id=%', NEW.source_id
            USING ERRCODE = '23503';
    END IF;

    SELECT object_type INTO v_target_type FROM pm.objects WHERE id = NEW.target_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Keine Grundzeile in pm.objects für target_id=%', NEW.target_id
            USING ERRCODE = '23503';
    END IF;

    SELECT * INTO v_relation FROM pm.relation_types WHERE key = NEW.relation_type;
    IF NOT FOUND THEN
        -- Der Fremdschlüssel erzwingt das letztlich, prüft aber erst nach
        -- diesem BEFORE-Trigger — deshalb hier ausdrücklich.
        RAISE EXCEPTION 'Unbekannte Beziehungsart: %', NEW.relation_type
            USING ERRCODE = '23503';
    END IF;

    SELECT * INTO v_endpoint
      FROM pm.relation_type_endpoints
     WHERE relation_type = NEW.relation_type
       AND source_type = v_source_type
       AND target_type = v_target_type;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Beziehungsart % erlaubt keine Kombination %  -> %',
            NEW.relation_type, v_source_type, v_target_type
            USING ERRCODE = '23514';
    END IF;

    -- Ob eine vorhandene description eine gültige und vollständige Sprachkarte
    -- ist, prüfen object_relations_validate_language_maps und die CHECK-
    -- Bedingung der Tabelle — unabhängig von der Ausführungsreihenfolge
    -- mehrerer BEFORE-Trigger auf derselben Tabelle (PostgreSQL führt sie
    -- alphabetisch nach Triggername aus, nicht nach Anlagereihenfolge).
    -- Hier wird nur die fachliche Anwesenheitspflicht geprüft.
    IF v_relation.description_required AND NEW.description IS NULL THEN
        RAISE EXCEPTION 'Beziehungsart % erfordert eine Beschreibung', NEW.relation_type
            USING ERRCODE = '23514';
    END IF;

    IF v_endpoint.max_targets_per_source IS NOT NULL THEN
        SELECT count(*) INTO v_target_count
          FROM pm.object_relations r
          JOIN pm.objects o ON o.id = r.target_id
         WHERE r.source_id = NEW.source_id
           AND r.relation_type = NEW.relation_type
           AND o.object_type = v_target_type
           AND NOT (
               v_excluded_relation_type IS NOT NULL
               AND r.source_id = v_excluded_source_id
               AND r.target_id = v_excluded_target_id
               AND r.relation_type = v_excluded_relation_type
           );

        IF v_target_count >= v_endpoint.max_targets_per_source THEN
            RAISE EXCEPTION
                'Quellobjekt % hat bereits % Ziel(e) vom Typ % für Beziehungsart % (Höchstgrenze %)',
                NEW.source_id, v_target_count, v_target_type, NEW.relation_type,
                v_endpoint.max_targets_per_source
                USING ERRCODE = '23514';
        END IF;
    END IF;

    IF v_endpoint.max_sources_per_target IS NOT NULL THEN
        SELECT count(*) INTO v_source_count
          FROM pm.object_relations r
          JOIN pm.objects o ON o.id = r.source_id
         WHERE r.target_id = NEW.target_id
           AND r.relation_type = NEW.relation_type
           AND o.object_type = v_source_type
           AND NOT (
               v_excluded_relation_type IS NOT NULL
               AND r.source_id = v_excluded_source_id
               AND r.target_id = v_excluded_target_id
               AND r.relation_type = v_excluded_relation_type
           );

        IF v_source_count >= v_endpoint.max_sources_per_target THEN
            RAISE EXCEPTION
                'Zielobjekt % hat bereits % Quelle(n) vom Typ % für Beziehungsart % (Höchstgrenze %)',
                NEW.target_id, v_source_count, v_source_type, NEW.relation_type,
                v_endpoint.max_sources_per_target
                USING ERRCODE = '23514';
        END IF;
    END IF;

    IF v_relation.acyclic THEN
        IF pm.object_relation_would_create_cycle(
               NEW.source_id, NEW.target_id, NEW.relation_type,
               v_excluded_source_id, v_excluded_target_id, v_excluded_relation_type
           )
        THEN
            RAISE EXCEPTION
                'Beziehungsart % ist zyklusfrei — %  -> % würde einen Zyklus schließen',
                NEW.relation_type, NEW.source_id, NEW.target_id
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER object_relations_enforce_rules
    BEFORE INSERT OR UPDATE
    ON pm.object_relations
    FOR EACH ROW
    EXECUTE FUNCTION pm.enforce_object_relation_rules();

-- source_id, target_id und relation_type bilden gemeinsam die Identität der
-- Beziehung. Die Rolle build darf diese nicht per UPDATE verändern (der
-- Trigger erzwingt das ohnehin); eine andere Beziehung wird durch DELETE und
-- INSERT abgebildet. Nur description ist nachträglich änderbar.
GRANT SELECT, INSERT, DELETE
    ON pm.object_relations
    TO build;
GRANT UPDATE (description)
    ON pm.object_relations
    TO build;

RESET ROLE;
