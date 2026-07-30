-- Pages-PM-spezifische Projektkonfiguration, keine Schema-Migration.
-- Muss nach migrations/011_project_area_state.sql laufen (state und
-- scope_mode sind NOT NULL ohne DEFAULT) und wird als migrator ausgeführt.
-- Die nötigen Rechte werden bereits in migrations/009_projects.sql
-- unmittelbar auf pm.projects vergeben.
--
-- Anfängliche Projektstruktur:
--
--     Kashasaga
--     ├── Pages PM
--     └── Pipeline Config Spec
--
-- Kashasaga bildet den übergeordneten Projektrahmen für das kleine
-- Shared-Hosting-Seitengerüst. Der Name beruht auf dem Kürzel KSHSG (für
-- "Kleines Shared-Hosting-Seitengerüst"); die eingeschobenen "a" dienen
-- lediglich der Aussprechbarkeit. Pages PM und Pipeline Config Spec besitzen
-- jeweils eine eigene fachliche Abgrenzung und einen eigenen
-- Entwicklungslebenszyklus. Pipeline Config Spec ist dabei ein Projektname,
-- keine Instanz der Pages-PM-Fachart "system_spec".
--
-- Alle drei Projekte sind aktiv und verwenden zunächst unweighted (nicht
-- gewichtet): bei ein bis fünf mitarbeitenden Personen ist Abzählen oft so
-- treffsicher wie Schätzen (§7.4, Rahmen Projekt, Gegenbeispiel).

INSERT INTO pm.projects (key, title, state, scope_mode) VALUES
    ('kashasaga', '{"de": "Kashasaga", "en": "Kashasaga"}'::jsonb, 'active', 'unweighted');

INSERT INTO pm.projects (key, title, parent_id, state, scope_mode)
SELECT 'pages_pm', '{"de": "Pages PM", "en": "Pages PM"}'::jsonb, id, 'active', 'unweighted'
FROM pm.projects WHERE key = 'kashasaga';

INSERT INTO pm.projects (key, title, parent_id, state, scope_mode)
SELECT 'pipeline_config_spec', '{"de": "Pipeline Config Spec", "en": "Pipeline Config Spec"}'::jsonb, id, 'active', 'unweighted'
FROM pm.projects WHERE key = 'kashasaga';
