BEGIN;
SELECT plan(8);

SELECT has_table('pm', 'objects', 'pm.objects existiert');
SELECT has_type('pm', 'object_type', 'pm.object_type existiert');

SELECT lives_ok(
    $$ INSERT INTO pm.objects (object_type, title)
       VALUES ('issue', '{"de": "Test", "en": "Test"}'::jsonb) $$,
    'vollständige Sprachkarte wird akzeptiert'
);

SELECT throws_ok(
    $$ INSERT INTO pm.objects (object_type, title)
       VALUES ('issue', '{"de": "Nur Deutsch"}'::jsonb) $$,
    '23514',
    NULL,
    'fehlende Pflichtsprache en wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.objects (object_type, title)
       VALUES ('issue', '{}'::jsonb) $$,
    '23514',
    NULL,
    'leere Sprachkarte wird abgelehnt'
);

SELECT throws_ok(
    $$ UPDATE pm.objects
       SET id = uuidv7()
       WHERE object_type = 'issue' $$,
    '23514',
    NULL,
    'id ist nach Anlage unveränderlich'
);

SELECT throws_ok(
    $$ UPDATE pm.objects
       SET created_at = created_at + interval '1 second'
       WHERE object_type = 'issue' $$,
    '23514',
    NULL,
    'created_at ist nach Anlage unveränderlich'
);

SELECT throws_ok(
    $$ UPDATE pm.objects
       SET object_type = 'sprint'
       WHERE object_type = 'issue' $$,
    '23514',
    NULL,
    'object_type ist nach Anlage unveränderlich'
);

SELECT * FROM finish();
ROLLBACK;
