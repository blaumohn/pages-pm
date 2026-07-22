BEGIN;
SELECT plan(12);

SELECT has_table('pm', 'areas', 'pm.areas existiert');
SELECT has_table('pm', 'object_areas', 'pm.object_areas existiert');

SELECT lives_ok(
    $$ INSERT INTO pm.areas (key, title, description)
       VALUES (
           'http_runtime',
           '{"de": "HTTP-Laufzeit", "en": "HTTP runtime"}'::jsonb,
           '{"de": "Anfragebearbeitung", "en": "Request handling"}'::jsonb
       ) $$,
    'gültiger Bereich mit Titel und Beschreibung wird angelegt'
);

SELECT lives_ok(
    $$ INSERT INTO pm.areas (key, title)
       VALUES ('build', '{"de": "Build", "en": "Build"}'::jsonb) $$,
    'Beschreibung ist optional'
);

SELECT throws_ok(
    $$ INSERT INTO pm.areas (key, title)
       VALUES ('HTTP Runtime', '{"de": "x", "en": "y"}'::jsonb) $$,
    '23514',
    NULL,
    'ungültiges Schlüsselformat wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.areas (key, title)
       VALUES ('deploy', '{"de": "Nur Deutsch"}'::jsonb) $$,
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

-- Zuordnung + Löschschutz
SELECT lives_ok(
    $$ WITH o AS (
           INSERT INTO pm.objects (object_type, title)
           VALUES ('issue', '{"de": "Zugeordnetes Issue", "en": "Assigned issue"}'::jsonb)
           RETURNING id
       )
       INSERT INTO pm.object_areas (object_id, area_id)
       SELECT o.id, a.id FROM o, pm.areas a WHERE a.key = 'build' $$,
    'Objekt kann einem Bereich zugeordnet werden'
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

SELECT * FROM finish();
ROLLBACK;
