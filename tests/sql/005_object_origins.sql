BEGIN;
SELECT plan(9);

SELECT has_table('pm', 'object_origins', 'pm.object_origins existiert');

SELECT lives_ok(
    $$ WITH o AS (
           INSERT INTO pm.objects (object_type, title)
           VALUES ('issue', '{"de": "Migriertes Issue", "en": "Migrated issue"}'::jsonb)
           RETURNING id
       )
       INSERT INTO pm.object_origins (object_id, source_system, source_reference, migration_note)
       SELECT o.id, 'jira', 'PROJECT-184',
              '{"de": "Als Vorgang eingeordnet.", "en": "Classified as issue."}'::jsonb
       FROM o $$,
    'gültige Herkunft mit mehrsprachiger Anmerkung wird angelegt'
);

SELECT lives_ok(
    $$ WITH o AS (
           INSERT INTO pm.objects (object_type, title)
           VALUES ('issue', '{"de": "Ohne Anmerkung", "en": "Without note"}'::jsonb)
           RETURNING id
       )
       INSERT INTO pm.object_origins (object_id, source_system, source_reference)
       SELECT o.id, 'filesystem', 'archive/kep-0017.md'
       FROM o $$,
    'migration_note ist optional'
);

SELECT throws_ok(
    $$ WITH o AS (
           INSERT INTO pm.objects (object_type, title)
           VALUES ('issue', '{"de": "x", "en": "y"}'::jsonb)
           RETURNING id
       )
       INSERT INTO pm.object_origins (object_id, source_system, source_reference)
       SELECT o.id, 'Jira Cloud', 'PROJECT-185'
       FROM o $$,
    '23514',
    NULL,
    'ungültiges source_system-Format wird abgelehnt'
);

SELECT throws_ok(
    $$ WITH o AS (
           INSERT INTO pm.objects (object_type, title)
           VALUES ('issue', '{"de": "x", "en": "y"}'::jsonb)
           RETURNING id
       )
       INSERT INTO pm.object_origins (object_id, source_system, source_reference)
       SELECT o.id, 'jira', '   '
       FROM o $$,
    '23514',
    NULL,
    'leere source_reference wird abgelehnt'
);

SELECT throws_ok(
    $$ WITH o AS (
           INSERT INTO pm.objects (object_type, title)
           VALUES ('issue', '{"de": "x", "en": "y"}'::jsonb)
           RETURNING id
       )
       INSERT INTO pm.object_origins (object_id, source_system, source_reference)
       SELECT o.id, 'jira', 'PROJECT-184'
       FROM o $$,
    '23505',
    NULL,
    'dieselbe externe Quelle kann nicht doppelt importiert werden'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_origins (object_id, source_system, source_reference)
       SELECT object_id, 'github', 'irrelevant'
       FROM pm.object_origins
       WHERE source_system = 'jira'
         AND source_reference = 'PROJECT-184' $$,
    '23505',
    NULL,
    'ein Objekt kann nicht zwei Herkunftszeilen besitzen'
);

SELECT throws_ok(
    $$ UPDATE pm.object_origins
       SET migration_note = '{"de": "Nur Deutsch"}'::jsonb
       WHERE source_system = 'jira'
         AND source_reference = 'PROJECT-184' $$,
    '23514',
    NULL,
    'unvollständige migration_note wird abgelehnt'
);

SELECT throws_ok(
    $$ UPDATE pm.object_origins
       SET migration_note = '{"de": "Deutsch", "en": "English", "nl": "Onbekend"}'::jsonb
       WHERE source_system = 'jira'
         AND source_reference = 'PROJECT-184' $$,
    '23514',
    NULL,
    'unbekannte Sprache in migration_note wird abgelehnt'
);

SELECT * FROM finish();
ROLLBACK;
