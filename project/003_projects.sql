-- Pages-PM-spezifische Projektkonfiguration, keine Schema-Migration.
-- Muss nach migrations/009_projects.sql laufen und wird als migrator
-- ausgeführt. Die nötigen Rechte werden dort unmittelbar auf pm.projects
-- vergeben.
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

INSERT INTO pm.projects (key, title) VALUES
    ('kashasaga', '{"de": "Kashasaga", "en": "Kashasaga"}'::jsonb);

INSERT INTO pm.projects (key, title, parent_id)
SELECT 'pages_pm', '{"de": "Pages PM", "en": "Pages PM"}'::jsonb, id
FROM pm.projects WHERE key = 'kashasaga';

INSERT INTO pm.projects (key, title, parent_id)
SELECT 'pipeline_config_spec', '{"de": "Pipeline Config Spec", "en": "Pipeline Config Spec"}'::jsonb, id
FROM pm.projects WHERE key = 'kashasaga';
