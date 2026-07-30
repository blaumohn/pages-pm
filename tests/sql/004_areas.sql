BEGIN;
SELECT plan(15);

SELECT has_table('pm', 'areas', 'pm.areas existiert');
SELECT has_table('pm', 'object_areas', 'pm.object_areas existiert');

-- Isolierte Prüfumgebung: eigene künstliche Objektart und Fachtabelle,
-- unabhängig von jeder anderen Testdatei.
DROP SCHEMA IF EXISTS pm_test CASCADE;
CREATE SCHEMA pm_test;

CREATE TABLE pm_test.widgets (
    id uuid PRIMARY KEY
);

INSERT INTO pm.object_types (key, table_name) VALUES
    ('widget', 'pm_test.widgets'::regclass);

CREATE TRIGGER widgets_register_object
    AFTER INSERT ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.register_object('widget');

CREATE TRIGGER widgets_deregister_object
    BEFORE DELETE ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.deregister_object('widget');

SELECT lives_ok(
    $$ INSERT INTO pm.areas (key, title, description, state)
       VALUES (
           'http_runtime',
           '{"de": "HTTP-Laufzeit", "en": "HTTP runtime"}'::jsonb,
           '{"de": "Anfragebearbeitung", "en": "Request handling"}'::jsonb,
           'active'
       ) $$,
    'gültiger Bereich mit Titel und Beschreibung wird angelegt'
);

SELECT lives_ok(
    $$ INSERT INTO pm.areas (key, title, state)
       VALUES ('build', '{"de": "Build", "en": "Build"}'::jsonb, 'active') $$,
    'Beschreibung ist optional'
);

SELECT throws_ok(
    $$ INSERT INTO pm.areas (key, title, state)
       VALUES ('HTTP Runtime', '{"de": "x", "en": "y"}'::jsonb, 'active') $$,
    '23514',
    NULL,
    'ungültiges Schlüsselformat wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.areas (key, title, state)
       VALUES ('deploy', '{"de": "Nur Deutsch"}'::jsonb, 'active') $$,
    '23514',
    NULL,
    'fehlende Pflichtsprache im Titel wird abgelehnt'
);

SELECT throws_ok(
    $$ UPDATE pm.areas SET key = 'renamed' WHERE key = 'build' $$,
    '23514',
    NULL,
    'key ist nach Anlage unveränderlich'
);

SELECT throws_ok(
    $$ UPDATE pm.areas SET id = uuidv7() WHERE key = 'build' $$,
    '23514',
    NULL,
    'id ist nach Anlage unveränderlich'
);

-- Zuordnung + Löschschutz. Feste UUID statt dynamisch erzeugter id, damit
-- die spätere Löschprüfung genau dieses eine Fachobjekt trifft, unabhängig
-- von später ergänzten Prüfdaten.
INSERT INTO pm_test.widgets (id) VALUES ('00000000-0000-0000-0000-000000000001');

SELECT lives_ok(
    $$ INSERT INTO pm.object_areas (object_id, area_id)
       SELECT '00000000-0000-0000-0000-000000000001', a.id
       FROM pm.areas a WHERE a.key = 'build' $$,
    'Objekt kann einem Bereich zugeordnet werden'
);

SELECT is(
    (SELECT count(*) FROM pm.object_areas
      WHERE object_id = '00000000-0000-0000-0000-000000000001'),
    1::bigint,
    'genau eine Bereichszuordnung wurde angelegt'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_areas (object_id, area_id)
       SELECT build_assignment.object_id, target_area.id
       FROM pm.object_areas AS build_assignment
       JOIN pm.areas AS build_area
         ON build_area.id = build_assignment.area_id
       CROSS JOIN pm.areas AS target_area
       WHERE build_area.key = 'build'
         AND target_area.key = 'http_runtime' $$,
    'ein Objekt kann mehreren Bereichen zugeordnet werden'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_areas (object_id, area_id)
       SELECT build_assignment.object_id, build_assignment.area_id
       FROM pm.object_areas AS build_assignment
       JOIN pm.areas AS build_area
         ON build_area.id = build_assignment.area_id
       WHERE build_area.key = 'build' $$,
    '23505',
    NULL,
    'dieselbe Bereichszuordnung kann nicht doppelt angelegt werden'
);

SELECT throws_ok(
    $$ DELETE FROM pm.areas WHERE key = 'build' $$,
    '23001',
    NULL,
    'Bereich mit bestehender Zuordnung kann nicht gelöscht werden'
);

-- Löschen des Fachobjekts entfernt dessen Bereichszuordnungen automatisch
-- (die Zuordnung selbst blockiert dabei nicht die Objektlöschung).
SELECT lives_ok(
    $$ DELETE FROM pm_test.widgets
       WHERE id = '00000000-0000-0000-0000-000000000001' $$,
    'Löschen des zugeordneten Fachobjekts gelingt trotz Bereichszuordnung'
);

SELECT is(
    (SELECT count(*) FROM pm.object_areas
      WHERE object_id = '00000000-0000-0000-0000-000000000001'),
    0::bigint,
    'Bereichszuordnungen des gelöschten Objekts sind automatisch verschwunden'
);

SELECT * FROM finish();
ROLLBACK;
