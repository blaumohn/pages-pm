BEGIN;
SELECT plan(16);

SELECT has_table('pm', 'object_origins', 'pm.object_origins existiert');

-- Isolierte Prüfumgebung: eigene künstliche Objektart und Fachtabelle,
-- unabhängig von jeder anderen Testdatei.
DROP SCHEMA IF EXISTS pm_test CASCADE;
CREATE SCHEMA pm_test;

CREATE TABLE pm_test.widgets (
    id uuid PRIMARY KEY
);

INSERT INTO pm.object_types (key, table_name, requires_project_assignment) VALUES
    ('widget', 'pm_test.widgets'::regclass, false);

CREATE TRIGGER widgets_register_object
    AFTER INSERT ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.register_object('widget');

CREATE TRIGGER widgets_deregister_object
    BEFORE DELETE ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.deregister_object('widget');

INSERT INTO pm_test.widgets (id) VALUES
    ('00000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000002');

SELECT lives_ok(
    $$ INSERT INTO pm.object_origins (object_id, source_system, source_reference, migration_note)
       VALUES (
           '00000000-0000-0000-0000-000000000001', 'jira', 'PROJECT-184',
           '{"de": "Als Vorgang eingeordnet.", "en": "Classified as issue."}'::jsonb
       ) $$,
    'gültige Herkunft mit mehrsprachiger Anmerkung wird angelegt'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_origins (object_id, source_system, source_reference)
       VALUES ('00000000-0000-0000-0000-000000000002', 'filesystem', 'archive/kep-0017.md') $$,
    'migration_note ist optional'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_origins (object_id, source_system, source_reference)
       VALUES ('00000000-0000-0000-0000-000000000001', 'Jira Cloud', 'PROJECT-185') $$,
    '23514',
    NULL,
    'ungültiges source_system-Format wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_origins (object_id, source_system, source_reference)
       VALUES ('00000000-0000-0000-0000-000000000001', 'jira', '   ') $$,
    '23514',
    NULL,
    'leere source_reference wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_origins (object_id, source_system, source_reference)
       VALUES ('00000000-0000-0000-0000-000000000001', 'jira', ' PROJECT-186') $$,
    '23514',
    NULL,
    'nicht getrimmte source_reference wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_origins (object_id, source_system, source_reference, source_locator)
       VALUES ('00000000-0000-0000-0000-000000000001', 'jira', 'PROJECT-184', '   ') $$,
    '23514',
    NULL,
    'leerer source_locator wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_origins (
           object_id,
           source_system,
           source_reference
       )
       VALUES (
           '00000000-0000-0000-0000-000000000002',
           'jira',
           'PROJECT-184'
       ) $$,
    '23505',
    NULL,
    'dieselbe externe Archiveinheit kann keinem zweiten Objekt zugeordnet werden'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_origins (object_id, source_system, source_reference, source_locator)
       VALUES ('00000000-0000-0000-0000-000000000001', 'jira', 'PROJECT-184', 'comment:4') $$,
    'derselbe source_reference-Wert mit anderem source_locator ist eine andere externe Einheit'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_origins (
           object_id,
           source_system,
           source_reference
       )
       VALUES (
           '00000000-0000-0000-0000-000000000002',
           'github',
           'irrelevant'
       ) $$,
    'ein Objekt kann mehrere Herkunftszeilen besitzen'
);

SELECT throws_ok(
    $$ UPDATE pm.object_origins
       SET migration_note = '{"de": "Nur Deutsch"}'::jsonb
       WHERE source_system = 'jira'
         AND source_reference = 'PROJECT-184'
         AND source_locator IS NULL $$,
    '23514',
    NULL,
    'unvollständige migration_note wird abgelehnt'
);

SELECT throws_ok(
    $$ UPDATE pm.object_origins
       SET migration_note = '{"de": "Deutsch", "en": "English", "nl": "Onbekend"}'::jsonb
       WHERE source_system = 'jira'
         AND source_reference = 'PROJECT-184'
         AND source_locator IS NULL $$,
    '23514',
    NULL,
    'unbekannte Sprache in migration_note wird abgelehnt'
);

-- object_id, source_system, source_reference und source_locator sind nicht
-- durch einen Trigger strukturell unveränderlich gemacht, sondern nur durch
-- Rollenrechte geschützt (GRANT UPDATE nur auf migration_note,
-- source_created_at). Diese Testdatei läuft mit einer Rolle, die die
-- editor-Rechte nicht einschränken. Die Regel wird daher über die
-- vergebenen Spaltenrechte geprüft.
SELECT ok(
    NOT has_column_privilege('editor', 'pm.object_origins', 'object_id', 'UPDATE')
    AND NOT has_column_privilege('editor', 'pm.object_origins', 'source_system', 'UPDATE')
    AND NOT has_column_privilege('editor', 'pm.object_origins', 'source_reference', 'UPDATE')
    AND NOT has_column_privilege('editor', 'pm.object_origins', 'source_locator', 'UPDATE'),
    'editor kann die externe Identität und das Zielobjekt nicht per UPDATE ändern'
);

-- Herkunft blockiert die Löschung des internen Objekts (ON DELETE RESTRICT).
-- PostgreSQL meldet eine RESTRICT-Blockade als 23001 (restrict_violation),
-- nicht als 23503 (foreign_key_violation, das gilt für Einfüge-/Update-
-- Verletzungen sowie NO ACTION).
SELECT throws_ok(
    $$ DELETE FROM pm_test.widgets
       WHERE id = '00000000-0000-0000-0000-000000000001' $$,
    '23001',
    NULL,
    'Objekt mit bestehender Herkunft kann nicht gelöscht werden'
);

SELECT lives_ok(
    $$ DELETE FROM pm.object_origins
       WHERE object_id = '00000000-0000-0000-0000-000000000001' $$,
    'nach Entfernen der Herkunftszeilen lässt sich die Löschung vorbereiten'
);

SELECT lives_ok(
    $$ DELETE FROM pm_test.widgets
       WHERE id = '00000000-0000-0000-0000-000000000001' $$,
    'Objekt kann nach Entfernen aller Herkunftszeilen gelöscht werden'
);

SELECT * FROM finish();
ROLLBACK;
