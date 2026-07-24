-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Projektzugehörigkeit ist eine allgemeine Grundlage und wird vor der ersten
-- Fachart (010_kep_lites.sql) umgesetzt. Ein Projekt ist ein eigenständig
-- geplantes und entwickeltes Vorhaben mit eigener fachlicher Abgrenzung und
-- eigenem Lebenszyklus (z. B. "Pages PM"), keine Pages-PM-Fachart und keine
-- Instanz einer Objektart aus pm.object_types.
--
-- pm.projects bildet eine Projekthierarchie über parent_id ab (z. B.
-- Kashasaga -> Pages PM). pm.object_projects ordnet jedem registrierten
-- Fachobjekt höchstens ein unmittelbares Projekt zu (Primärschlüssel auf
-- object_id). Die konkrete Projektstruktur selbst wird nicht hier, sondern
-- in project/003_projects.sql als Projektkonfiguration angelegt.
--
-- Sprachkarten (title, description) werden mit dem in
-- 008_common_field_functions.sql eingeführten Prüftrigger-Muster
-- (pm.validate_nonempty_language_map() per PERFORM in einem eigenen
-- BEFORE-Trigger) geprüft, nicht mit einer CHECK-Bedingung.

SET ROLE schema_owner;

CREATE TABLE pm.projects (
    id uuid PRIMARY KEY
        DEFAULT uuidv7(),

    key text NOT NULL UNIQUE,
    title jsonb NOT NULL,

    parent_id uuid
        REFERENCES pm.projects(id)
        ON DELETE RESTRICT,

    description jsonb,

    created_at timestamptz NOT NULL
        DEFAULT statement_timestamp(),

    updated_at timestamptz NOT NULL
        DEFAULT statement_timestamp(),

    CONSTRAINT projects_key_has_valid_format
        CHECK (key ~ '^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$'),

    CONSTRAINT projects_parent_is_not_self
        CHECK (
            parent_id IS NULL
            OR parent_id <> id
        )
);

COMMENT ON TABLE pm.projects IS
    'Eigenständig geplante und entwickelte Vorhaben mit eigener fachlicher '
    'Abgrenzung und eigenem Lebenszyklus, gegebenenfalls mit eigener '
    'Spezifikation sowie einer oder mehreren Umsetzungen, in hierarchischer '
    'Struktur (parent_id). Keine Pages-PM-Fachart und keine Instanz einer '
    'Objektart aus pm.object_types — ein Bereich oder Teilsystem ist dadurch '
    'nicht automatisch selbst ein Projekt.';
COMMENT ON COLUMN pm.projects.id IS
    'Unveränderliche Kennung des Projekts.';
COMMENT ON COLUMN pm.projects.key IS
    'Unveränderlicher technischer Schlüssel wie "pages_pm", unabhängig vom Titel.';
COMMENT ON COLUMN pm.projects.parent_id IS
    'Übergeordnetes Projekt, z. B. Kashasaga für Pages PM. ON DELETE RESTRICT: '
    'ein Projekt mit Unterprojekten kann nicht gelöscht werden.';
COMMENT ON COLUMN pm.projects.title IS
    'Nicht leere Sprachkarte mit dem sichtbaren Projektnamen.';
COMMENT ON COLUMN pm.projects.description IS
    'Optionale nicht leere Sprachkarte mit der fachlichen Beschreibung.';

-- Prüft title und die optionale description gegen die systemweite
-- Sprachkonfiguration und gegen eine fachliche Mindestlänge. Die statische
-- Grundform (nicht leeres JSON-Objekt, nur Zeichenketten, keine
-- Leerraumwerte) wird bereits von pm.validate_language_map() innerhalb von
-- pm.validate_nonempty_language_map() geprüft.
CREATE FUNCTION pm.validate_project_language_maps()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pm.validate_nonempty_language_map(NEW.title, 2);
    PERFORM pm.validate_nonempty_language_map(NEW.description, 2, true);
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.validate_project_language_maps() IS
    'Prüft pm.projects.title (Pflicht) und pm.projects.description (optional) '
    'gegen die systemweite Sprachkonfiguration und eine Mindestlänge von 2 '
    'Zeichen je vorhandenem Sprachwert.';

CREATE TRIGGER projects_validate_language_maps
    BEFORE INSERT OR UPDATE OF title, description
    ON pm.projects
    FOR EACH ROW
    EXECUTE FUNCTION pm.validate_project_language_maps();

-- Verhindert mehrgliedrige Zyklen in parent_id (z. B. A -> B -> C -> A).
-- Der unmittelbare Selbstbezug (parent_id = id) ist bereits durch die
-- CHECK-Bedingung projects_parent_is_not_self ausgeschlossen. Läuft nur bei
-- gesetztem NEW.parent_id: läuft die Kette der Vorfahren von NEW.parent_id
-- aufwärts (parent_id -> parent_id -> ...) und scheitert, sobald NEW.id
-- darin selbst wieder auftaucht.
CREATE FUNCTION pm.prevent_project_hierarchy_cycle()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.parent_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        WITH RECURSIVE ancestors (id, parent_id) AS (
            SELECT p.id, p.parent_id
              FROM pm.projects AS p
             WHERE p.id = NEW.parent_id

            UNION ALL

            SELECT p.id, p.parent_id
              FROM pm.projects AS p
              JOIN ancestors AS a
                ON p.id = a.parent_id
        )
        SELECT 1 FROM ancestors WHERE id = NEW.id
    ) THEN
        RAISE EXCEPTION
            'Projekt % kann nicht Vorfahre seines eigenen übergeordneten Projekts % werden (Zyklus)',
            NEW.id, NEW.parent_id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.prevent_project_hierarchy_cycle() IS
    'Verhindert mehrgliedrige Zyklen in pm.projects.parent_id, indem die '
    'Vorfahrenkette von NEW.parent_id aufwärts nach NEW.id durchsucht wird.';

CREATE TRIGGER projects_prevent_hierarchy_cycle
    BEFORE INSERT OR UPDATE OF parent_id
    ON pm.projects
    FOR EACH ROW
    EXECUTE FUNCTION pm.prevent_project_hierarchy_cycle();

CREATE TRIGGER projects_set_updated_at
    BEFORE UPDATE
    ON pm.projects
    FOR EACH ROW
    EXECUTE FUNCTION pm.set_updated_at();

CREATE FUNCTION pm.prevent_project_identity_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id THEN
        RAISE EXCEPTION 'pm.projects.id darf nicht geändert werden'
            USING ERRCODE = '23514';
    END IF;
    IF NEW.key IS DISTINCT FROM OLD.key THEN
        RAISE EXCEPTION 'pm.projects.key darf nicht geändert werden'
            USING ERRCODE = '23514';
    END IF;
    IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'pm.projects.created_at darf nicht geändert werden'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.prevent_project_identity_change() IS
    'Verhindert Änderungen an pm.projects.id, .key und .created_at.';

CREATE TRIGGER projects_prevent_identity_change
    BEFORE UPDATE OF id, key, created_at
    ON pm.projects
    FOR EACH ROW
    EXECUTE FUNCTION pm.prevent_project_identity_change();

-- PostgreSQL legt für referenzierende Fremdschlüsselspalten keinen Index
-- automatisch an. Dieser Index unterstützt die Suche nach Unterprojekten,
-- Hierarchieabfragen und die Prüfung von ON DELETE RESTRICT beim Löschen
-- eines übergeordneten Projekts.
CREATE INDEX projects_parent_id_idx
    ON pm.projects(parent_id);

-- Ordnet jedes registrierte Fachobjekt höchstens einem unmittelbaren Projekt
-- zu. Der Primärschlüssel auf object_id erzwingt das. ON DELETE CASCADE auf
-- object_id: verschwindet das Fachobjekt (und damit sein Registereintrag),
-- verschwindet auch seine Projektzuordnung automatisch, symmetrisch zu
-- pm.object_areas. ON DELETE RESTRICT auf project_id: ein Projekt mit
-- zugeordneten Objekten kann nicht gelöscht werden.
--
-- Für den Bootstrap werden Fachobjekt und Projektzuordnung immer in
-- derselben Transaktion angelegt. Eine verzögerte allgemeine Prüfung, dass
-- jedes betriebliche Objekt genau eine Projektzuordnung besitzt, ist noch
-- nicht Teil dieses Standes.
CREATE TABLE pm.object_projects (
    object_id uuid PRIMARY KEY
        REFERENCES pm.object_registry(id)
        ON DELETE CASCADE,

    project_id uuid NOT NULL
        REFERENCES pm.projects(id)
        ON DELETE RESTRICT
);

COMMENT ON TABLE pm.object_projects IS
    'Unmittelbare Projektzugehörigkeit je registriertem Fachobjekt. '
    'Primärschlüssel auf object_id: höchstens eine Zuordnung je Objekt. '
    'Übergeordnete Projektzugehörigkeit ergibt sich aus pm.projects.parent_id.';
COMMENT ON COLUMN pm.object_projects.object_id IS
    'Registriertes Fachobjekt (pm.object_registry.id).';
COMMENT ON COLUMN pm.object_projects.project_id IS
    'Unmittelbar zugeordnetes Projekt.';

-- PostgreSQL legt für referenzierende Fremdschlüsselspalten keinen Index
-- automatisch an. object_id ist bereits als Primärschlüssel indiziert. Dieser
-- Index unterstützt die Suche nach den Objekten eines Projekts und die
-- Prüfung von ON DELETE RESTRICT beim Löschen eines Projekts.
CREATE INDEX object_projects_project_id_idx
    ON pm.object_projects(project_id);

-- Die anfängliche Projektstruktur selbst wird als Projektkonfiguration unter
-- Schemahoheit angelegt (project/003_projects.sql, läuft als migrator).
-- editor soll im Bootstrap keine neuen Projekte oder Projekthierarchien
-- erzeugen und erhält deshalb nur SELECT auf pm.projects.
GRANT SELECT, INSERT, UPDATE, DELETE
    ON pm.projects
    TO migrator;

GRANT SELECT
    ON pm.projects
    TO editor, reader;

-- pm.object_projects enthält die eigentliche fachliche Zuordnung. editor legt
-- sie beim Anlegen des Fachobjekts an und darf project_id ändern, also das
-- Objekt unmittelbar einem anderen Projekt zuordnen. editor erhält kein
-- DELETE-Recht: Eine bestehende Projektzuordnung darf nicht ersatzlos entfernt
-- werden. Beim Löschen des Fachobjekts entfernt ON DELETE CASCADE die
-- Zuordnung automatisch.
GRANT SELECT, INSERT
    ON pm.object_projects
    TO editor;
GRANT UPDATE (project_id)
    ON pm.object_projects
    TO editor;

GRANT SELECT
    ON pm.object_projects
    TO reader;

RESET ROLE;
