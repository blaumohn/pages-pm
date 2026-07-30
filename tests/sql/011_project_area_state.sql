BEGIN;
SELECT plan(10);

-- Isolierte Prüfumgebung: eigene Fachtabelle und Objektart, unabhängig von
-- jeder anderen Testdatei. Das abschließende ROLLBACK entfernt alle
-- Testobjekte wieder.
DROP SCHEMA IF EXISTS pm_test CASCADE;
CREATE SCHEMA pm_test;

CREATE TABLE pm_test.widgets (
    id uuid PRIMARY KEY
);

INSERT INTO pm.object_types (key, table_name, requires_project_assignment) VALUES
    ('state_widget', 'pm_test.widgets'::regclass, false);

CREATE TRIGGER widgets_register_object
    AFTER INSERT ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.register_object('state_widget');

CREATE TRIGGER widgets_deregister_object
    BEFORE DELETE ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.deregister_object('state_widget');

-- [Spez §7.1.1, Regel 4] Kein Vorgabewert für ein Urteil: state und
-- scope_mode müssen bei pm.projects, state bei pm.areas ausdrücklich gesetzt
-- werden.
SELECT throws_ok(
    $$ INSERT INTO pm.projects (key, title, scope_mode)
       VALUES ('no_state', '{"de": "Test", "en": "Test"}'::jsonb, 'unweighted') $$,
    '23502',
    NULL,
    '[Spez §7.1.1, Regel 4] pm.projects ohne state wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.projects (key, title, state)
       VALUES ('no_scope_mode', '{"de": "Test", "en": "Test"}'::jsonb, 'active') $$,
    '23502',
    NULL,
    '[Spez §7.1.1, Regel 4] pm.projects ohne scope_mode wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.areas (key, title)
       VALUES ('no_state', '{"de": "x", "en": "x"}'::jsonb) $$,
    '23502',
    NULL,
    '[Spez §7.1.1, Regel 4] pm.areas ohne state wird abgelehnt'
);

-- Ungültige Zustände/Umfangsarten werden abgewiesen.
SELECT throws_ok(
    $$ INSERT INTO pm.projects (key, title, state, scope_mode)
       VALUES ('bad_state', '{"de": "x", "en": "x"}'::jsonb, 'vanished', 'unweighted') $$,
    '23514',
    NULL,
    '[Spez §7.4, Rahmen Projekt] ungültiger Projektzustand wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.projects (key, title, state, scope_mode)
       VALUES ('bad_scope', '{"de": "x", "en": "x"}'::jsonb, 'active', 'guessed') $$,
    '23514',
    NULL,
    '[Spez §7.4, Rahmen Projekt] ungültige Umfangsangabe wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.areas (key, title, state)
       VALUES ('bad_state', '{"de": "x", "en": "x"}'::jsonb, 'forgotten') $$,
    '23514',
    NULL,
    '[Spez §7.4, Rahmen Bereich] ungültiger Bereichszustand wird abgelehnt'
);

-- [Spez §7.4, Rahmen Projekt] Ein Projekt im Zustand closed nimmt keine
-- neuen Fachgegenstände auf.
INSERT INTO pm.projects (key, title, state, scope_mode) VALUES
    ('open_project', '{"de": "Offen", "en": "Open"}'::jsonb, 'active', 'unweighted'),
    ('closed_project', '{"de": "Zu", "en": "Closed"}'::jsonb, 'closed', 'unweighted');

INSERT INTO pm_test.widgets (id) VALUES ('00000000-0000-0000-0000-000000000001');

SELECT throws_ok(
    $$ INSERT INTO pm.object_projects (object_id, project_id)
       SELECT '00000000-0000-0000-0000-000000000001', id
         FROM pm.projects WHERE key = 'closed_project' $$,
    '23514',
    NULL,
    'Zuordnung zu einem abgeschlossenen Projekt wird abgewiesen'
);

INSERT INTO pm.object_projects (object_id, project_id)
    SELECT '00000000-0000-0000-0000-000000000001', id
      FROM pm.projects WHERE key = 'open_project';

-- Umhängen in ein abgeschlossenes Projekt wird ebenso abgewiesen.
SELECT throws_ok(
    $$ UPDATE pm.object_projects
          SET project_id = (SELECT id FROM pm.projects WHERE key = 'closed_project')
        WHERE object_id = '00000000-0000-0000-0000-000000000001' $$,
    '23514',
    NULL,
    'Umhängen in ein abgeschlossenes Projekt wird abgewiesen'
);

-- Eine bestehende Zuordnung bleibt bestehen, wenn das Projekt nachträglich
-- geschlossen wird: die Regel sperrt nur Neuzugänge, verlangt keinen
-- Rückzug.
UPDATE pm.projects SET state = 'closed' WHERE key = 'open_project';

SELECT is(
    (SELECT project_id FROM pm.object_projects
      WHERE object_id = '00000000-0000-0000-0000-000000000001'),
    (SELECT id FROM pm.projects WHERE key = 'open_project'),
    'bestehende Zuordnung bleibt bestehen, wenn ihr Projekt nachträglich abgeschlossen wird'
);

SELECT is(
    (SELECT count(*) FROM pm.object_projects
      WHERE object_id = '00000000-0000-0000-0000-000000000001'),
    1::bigint,
    'die bestehende Zuordnung wird durch das nachträgliche Schließen nicht entfernt'
);

SELECT * FROM finish();
ROLLBACK;
