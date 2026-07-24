BEGIN;
SELECT plan(27);

SELECT has_table('pm', 'projects', 'pm.projects existiert');
SELECT has_table('pm', 'object_projects', 'pm.object_projects existiert');

-- Eigene künstliche Objektart und Fachtabelle; die Prüfung verwendet keine
-- Prüfdaten anderer Testdateien. pm.projects selbst ist jedoch keine
-- isolierte Testtabelle: project/003_projects.sql hat darin bereits die
-- wirkliche Projektkonfiguration angelegt. Die hier verwendeten Schlüssel
-- test_root_project, test_child_project und test_leaf_project dürfen deshalb
-- nicht mit wirklichen Projektschlüsseln wie pages_pm kollidieren.
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

-- 1: Root-Projekt.
SELECT lives_ok(
    $$ INSERT INTO pm.projects (key, title)
       VALUES ('test_root_project', '{"de": "Wurzel", "en": "Root"}'::jsonb) $$,
    'Root-Projekt kann angelegt werden'
);

-- 2: Unterprojekt über parent_id.
SELECT lives_ok(
    $$ INSERT INTO pm.projects (key, title, parent_id)
       SELECT 'test_child_project', '{"de": "Kind", "en": "Child"}'::jsonb, id
       FROM pm.projects WHERE key = 'test_root_project' $$,
    'Unterprojekt kann angelegt werden'
);

-- 3: Hierarchie ist über parent_id nachvollziehbar.
SELECT is(
    (SELECT parent.key
       FROM pm.projects AS child
       JOIN pm.projects AS parent
         ON parent.id = child.parent_id
      WHERE child.key = 'test_child_project'),
    'test_root_project',
    'Unterprojekt ist über parent_id dem Root-Projekt zugeordnet'
);

-- 4: ungültiges Schlüsselformat.
SELECT throws_ok(
    $$ INSERT INTO pm.projects (key, title)
       VALUES ('Test Invalid Key', '{"de": "x", "en": "y"}'::jsonb) $$,
    '23514',
    NULL,
    'ungültiges Schlüsselformat wird abgelehnt'
);

-- 5: doppelter Schlüssel. title muss gültig sein, damit nicht bereits der
-- Sprachkarten-Prüftrigger (23514) vor der Eindeutigkeitsprüfung (23505)
-- scheitert.
SELECT throws_ok(
    $$ INSERT INTO pm.projects (key, title)
       VALUES (
           'test_child_project',
           '{"de": "Doppeltes Projekt", "en": "Duplicate project"}'::jsonb
       ) $$,
    '23505',
    NULL,
    'doppelter Projektschlüssel wird abgelehnt'
);

-- 6: Titel unterschreitet die Mindestlänge.
SELECT throws_ok(
    $$ INSERT INTO pm.projects (key, title)
       VALUES ('test_too_short_title', '{"de": "x", "en": "y"}'::jsonb) $$,
    '23514',
    NULL,
    'Titel unterhalb der Mindestlänge wird abgelehnt'
);

-- 7: optionale description unterschreitet die Mindestlänge.
SELECT throws_ok(
    $$ INSERT INTO pm.projects (key, title, description)
       VALUES (
           'test_too_short_description',
           '{"de": "gueltig", "en": "valid"}'::jsonb,
           '{"de": "x", "en": "y"}'::jsonb
       ) $$,
    '23514',
    NULL,
    'description unterhalb der Mindestlänge wird abgelehnt'
);

-- 8: Selbst-Elternbeziehung.
SELECT throws_ok(
    $$ UPDATE pm.projects SET parent_id = id WHERE key = 'test_child_project' $$,
    '23514',
    NULL,
    'Selbst-Elternbeziehung wird abgelehnt'
);

-- test_leaf_project haengt unter test_child_project; damit laesst sich
-- anschliessend sowohl der Loeschschutz durch ein Unterprojekt
-- (test_child_project) als auch durch eine Objektzuordnung
-- (test_leaf_project) getrennt pruefen.
-- updated_at wird ausdruecklich auf gestern gesetzt, damit Test 13 nicht von
-- der Zeitaufloesung unmittelbar aufeinanderfolgender Anweisungen abhaengt.
INSERT INTO pm.projects (key, title, parent_id, updated_at)
SELECT
    'test_leaf_project',
    '{"de": "Blatt", "en": "Leaf"}'::jsonb,
    id,
    statement_timestamp() - interval '1 day'
FROM pm.projects WHERE key = 'test_child_project';

-- 9: mehrgliedriger Hierarchiezyklus. test_root_project.parent_id =
-- test_leaf_project.id wuerde test_root_project -> test_child_project ->
-- test_leaf_project -> test_root_project schliessen.
SELECT throws_ok(
    $$ UPDATE pm.projects SET parent_id = leaf.id
       FROM pm.projects AS leaf
       WHERE pm.projects.key = 'test_root_project'
         AND leaf.key = 'test_leaf_project' $$,
    '23514',
    NULL,
    'mehrgliedriger Hierarchiezyklus wird abgelehnt'
);

-- 10: key ist nach Anlage unveraenderlich.
SELECT throws_ok(
    $$ UPDATE pm.projects SET key = 'renamed' WHERE key = 'test_leaf_project' $$,
    '23514',
    NULL,
    'key ist nach Anlage unveränderlich'
);

-- 11: id ist nach Anlage unveraenderlich.
SELECT throws_ok(
    $$ UPDATE pm.projects SET id = uuidv7() WHERE key = 'test_leaf_project' $$,
    '23514',
    NULL,
    'id ist nach Anlage unveränderlich'
);

-- 12: created_at ist nach Anlage unveraenderlich.
SELECT throws_ok(
    $$ UPDATE pm.projects SET created_at = statement_timestamp()
       WHERE key = 'test_leaf_project' $$,
    '23514',
    NULL,
    'created_at ist nach Anlage unveränderlich'
);

-- 13: updated_at wird durch eine zulässige Änderung fortgeschrieben.
-- Der bisherige Wert wird vor der Änderung für den anschließenden Vergleich
-- in einer temporären Tabelle gesichert.
CREATE TEMP TABLE pm_test_previous_updated_at
ON COMMIT DROP
AS
SELECT updated_at
FROM pm.projects
WHERE key = 'test_leaf_project';

UPDATE pm.projects
   SET title = '{"de": "Blatt", "en": "Leaf (renamed)"}'::jsonb
 WHERE key = 'test_leaf_project';

SELECT ok(
    (
        SELECT current_project.updated_at > previous.updated_at
        FROM pm.projects AS current_project
        CROSS JOIN pm_test_previous_updated_at AS previous
        WHERE current_project.key = 'test_leaf_project'
    ),
    'updated_at wird durch die Änderung fortgeschrieben'
);

-- Feste UUID statt dynamisch erzeugter id, damit die spaetere Pruefung genau
-- dieses eine Fachobjekt trifft.
INSERT INTO pm_test.widgets (id) VALUES ('00000000-0000-0000-0000-000000000001');

-- 14: unbekanntes object_id wird abgelehnt.
SELECT throws_ok(
    $$ INSERT INTO pm.object_projects (object_id, project_id)
       SELECT '00000000-0000-0000-0000-000000000099', id
       FROM pm.projects WHERE key = 'test_leaf_project' $$,
    '23503',
    NULL,
    'unbekanntes object_id wird abgelehnt'
);

-- 15: unbekanntes project_id wird abgelehnt.
SELECT throws_ok(
    $$ INSERT INTO pm.object_projects (object_id, project_id)
       VALUES (
           '00000000-0000-0000-0000-000000000001',
           '00000000-0000-0000-0000-000000000098'
       ) $$,
    '23503',
    NULL,
    'unbekanntes project_id wird abgelehnt'
);

-- 16: Objekt kann einem vorhandenen Projekt zugeordnet werden.
SELECT lives_ok(
    $$ INSERT INTO pm.object_projects (object_id, project_id)
       SELECT '00000000-0000-0000-0000-000000000001', id
       FROM pm.projects WHERE key = 'test_leaf_project' $$,
    'Objekt kann einem vorhandenen Projekt zugeordnet werden'
);

-- 17: höchstens eine unmittelbare Projektzuordnung ist vorhanden.
SELECT is(
    (SELECT count(*) FROM pm.object_projects
      WHERE object_id = '00000000-0000-0000-0000-000000000001'),
    1::bigint,
    'eine unmittelbare Projektzuordnung wurde angelegt'
);

-- 18: eine zweite unmittelbare Projektzuordnung desselben Objekts scheitert
-- am Primaerschluessel auf object_id.
SELECT throws_ok(
    $$ INSERT INTO pm.object_projects (object_id, project_id)
       SELECT '00000000-0000-0000-0000-000000000001', id
       FROM pm.projects WHERE key = 'test_root_project' $$,
    '23505',
    NULL,
    'zweite unmittelbare Projektzuordnung desselben Objekts wird abgelehnt'
);

-- 19: Projekt mit Unterprojekten kann nicht geloescht werden.
SELECT throws_ok(
    $$ DELETE FROM pm.projects WHERE key = 'test_child_project' $$,
    '23001',
    NULL,
    'Projekt mit Unterprojekten kann nicht gelöscht werden'
);

-- 20: Projekt mit zugeordneten Objekten kann nicht geloescht werden.
SELECT throws_ok(
    $$ DELETE FROM pm.projects WHERE key = 'test_leaf_project' $$,
    '23001',
    NULL,
    'Projekt mit zugeordneten Objekten kann nicht gelöscht werden'
);

-- 21: Projektzuordnung kann auf ein anderes vorhandenes Projekt geaendert
-- werden.
SELECT lives_ok(
    $$ UPDATE pm.object_projects
          SET project_id = (SELECT id FROM pm.projects WHERE key = 'test_root_project')
        WHERE object_id = '00000000-0000-0000-0000-000000000001' $$,
    'Projektzuordnung kann auf ein anderes Projekt geändert werden'
);

-- 22: die geaenderte Zuordnung zeigt tatsaechlich auf das neue Projekt.
SELECT is(
    (SELECT p.key
       FROM pm.object_projects AS op
       JOIN pm.projects AS p ON p.id = op.project_id
      WHERE op.object_id = '00000000-0000-0000-0000-000000000001'),
    'test_root_project',
    'Objekt ist nach der Änderung dem Root-Projekt zugeordnet'
);

-- 23: test_leaf_project hat nun weder Unterprojekt noch zugeordnetes Objekt
-- mehr und kann gelöscht werden.
SELECT lives_ok(
    $$ DELETE FROM pm.projects WHERE key = 'test_leaf_project' $$,
    'test_leaf_project kann nach dem Verschieben der Objektzuordnung gelöscht werden'
);

-- 24: Löschen des zugeordneten Fachobjekts gelingt trotz Projektzuordnung.
SELECT lives_ok(
    $$ DELETE FROM pm_test.widgets
       WHERE id = '00000000-0000-0000-0000-000000000001' $$,
    'Löschen des zugeordneten Fachobjekts gelingt trotz Projektzuordnung'
);

-- 25: die Projektzuordnung des gelöschten Objekts ist automatisch
-- verschwunden (ON DELETE CASCADE auf object_id).
SELECT is(
    (SELECT count(*) FROM pm.object_projects
      WHERE object_id = '00000000-0000-0000-0000-000000000001'),
    0::bigint,
    'Projektzuordnung wird beim Löschen des Fachobjekts entfernt'
);

SELECT * FROM finish();
ROLLBACK;
