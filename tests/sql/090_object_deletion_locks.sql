BEGIN;
SELECT plan(5);

-- Übernommen aus dem entfernten tests/sql/008_phase_a_acceptance.sql: prüft
-- das Zusammenwirken zweier unabhängiger Löschsperren (Herkunft und
-- Beziehung, jeweils ON DELETE RESTRICT auf pm.object_registry). Jede Sperre
-- für sich ist bereits in ihrer zuständigen Testdatei geprüft
-- (tests/sql/005_object_origins.sql: "Objekt mit bestehender Herkunft kann
-- nicht gelöscht werden"; tests/sql/007_object_relations.sql: "Objekt mit
-- bestehender Beziehung als Quelle kann nicht gelöscht werden") — hier daher
-- nur das Zusammenspiel: Zum Löschen müssen beide Sperren entfernt sein;
-- das Entfernen nur einer Sperre genügt nicht. Bewusst kein
-- migrationsgebundener Dateiname (0NN
-- entspricht keiner Migration 0NN): eine fachübergreifende Prüfung wie diese
-- braucht keine eigene Migration.
--
-- Isolierte Prüfumgebung, unabhängig von jeder anderen Testdatei.
DROP SCHEMA IF EXISTS pm_test CASCADE;
CREATE SCHEMA pm_test;

CREATE TABLE pm_test.widgets (
    id uuid PRIMARY KEY
);

INSERT INTO pm.object_types (key, table_name) VALUES
    ('lock_widget', 'pm_test.widgets'::regclass);

CREATE TRIGGER widgets_register_object
    AFTER INSERT ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.register_object('lock_widget');

CREATE TRIGGER widgets_deregister_object
    BEFORE DELETE ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.deregister_object('lock_widget');

INSERT INTO pm.relation_types (key, title, description, description_required, acyclic)
VALUES (
    'lock_test_references',
    '{"de": "Testverweis", "en": "Test reference"}'::jsonb,
    '{"de": "Nur für diesen Test.", "en": "Only for this test."}'::jsonb,
    false, false
);

INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
VALUES ('lock_test_references', 'lock_widget', 'lock_widget');

INSERT INTO pm_test.widgets (id) VALUES
    ('00000000-0000-0000-0000-000000000001'), -- A: trägt Herkunft und Beziehung
    ('00000000-0000-0000-0000-000000000002'); -- B: nur Beziehungsziel

-- Beide Blockaden werden vor dem ersten Löschversuch angelegt.
INSERT INTO pm.object_origins (object_id, source_system, source_reference)
VALUES ('00000000-0000-0000-0000-000000000001', 'jira', 'LOCK-1');

INSERT INTO pm.object_relations (source_id, target_id, relation_type)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    'lock_test_references'
);

SELECT throws_ok(
    $$ DELETE FROM pm_test.widgets WHERE id = '00000000-0000-0000-0000-000000000001' $$,
    '23001',
    NULL,
    'Herkunft und Beziehung zusammen sperren das Löschen'
);

SELECT lives_ok(
    $$ DELETE FROM pm.object_relations
       WHERE source_id = '00000000-0000-0000-0000-000000000001' $$,
    'Beziehung wird entfernt'
);

SELECT throws_ok(
    $$ DELETE FROM pm_test.widgets WHERE id = '00000000-0000-0000-0000-000000000001' $$,
    '23001',
    NULL,
    'nach Entfernen nur der Beziehung bleibt A wegen der Herkunft gesperrt'
);

SELECT lives_ok(
    $$ DELETE FROM pm.object_origins
       WHERE object_id = '00000000-0000-0000-0000-000000000001' $$,
    'Herkunft wird entfernt'
);

SELECT lives_ok(
    $$ DELETE FROM pm_test.widgets WHERE id = '00000000-0000-0000-0000-000000000001' $$,
    'A kann erst nach Entfernen beider Sperren gelöscht werden'
);

SELECT * FROM finish();
ROLLBACK;
