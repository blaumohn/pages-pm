BEGIN;
SELECT plan(16);

SELECT has_table('pm', 'object_types', 'pm.object_types existiert');
SELECT has_table('pm', 'object_registry', 'pm.object_registry existiert');

-- Isolierte Prüfumgebung: eigenes Prüfschema mit zwei künstlichen
-- Objektarten und Fachtabellen, unabhängig von jeder anderen Testdatei.
-- Das abschließende ROLLBACK entfernt alle Testobjekte wieder.
DROP SCHEMA IF EXISTS pm_test CASCADE;
CREATE SCHEMA pm_test;

CREATE TABLE pm_test.widgets (
    id uuid PRIMARY KEY
);

CREATE TABLE pm_test.gadgets (
    id uuid PRIMARY KEY
);

-- table_name kann erst gesetzt werden, nachdem die Prüftabelle besteht.
INSERT INTO pm.object_types (key, table_name, requires_project_assignment) VALUES
    ('widget', 'pm_test.widgets'::regclass, false),
    ('gadget', 'pm_test.gadgets'::regclass, false);

CREATE TRIGGER widgets_register_object
    AFTER INSERT ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.register_object('widget');

CREATE TRIGGER widgets_deregister_object
    BEFORE DELETE ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.deregister_object('widget');

CREATE TRIGGER gadgets_register_object
    AFTER INSERT ON pm_test.gadgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.register_object('gadget');

CREATE TRIGGER gadgets_deregister_object
    BEFORE DELETE ON pm_test.gadgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.deregister_object('gadget');

SELECT lives_ok(
    $$ INSERT INTO pm_test.widgets (id) VALUES ('00000000-0000-0000-0000-000000000001') $$,
    'gültige Fachzeile registriert sich automatisch'
);

SELECT results_eq(
    $$ SELECT object_type FROM pm.object_registry
       WHERE id = '00000000-0000-0000-0000-000000000001' $$,
    ARRAY['widget'],
    'Registerzeile trägt die richtige Objektart'
);

SELECT lives_ok(
    $$ DELETE FROM pm_test.widgets WHERE id = '00000000-0000-0000-0000-000000000001' $$,
    'Löschen der Fachzeile entfernt die Registerzeile wieder'
);

SELECT is(
    (SELECT count(*) FROM pm.object_registry
      WHERE id = '00000000-0000-0000-0000-000000000001'),
    0::bigint,
    'Registerzeile ist nach dem Löschen verschwunden'
);

-- Unbekannte Objektart: Triggerargument verweist auf keinen Schlüssel in
-- pm.object_types.
CREATE TABLE pm_test.ghosts (
    id uuid PRIMARY KEY
);

CREATE TRIGGER ghosts_register_object
    AFTER INSERT ON pm_test.ghosts
    FOR EACH ROW
    EXECUTE FUNCTION pm.register_object('ghost');

SELECT throws_ok(
    $$ INSERT INTO pm_test.ghosts (id) VALUES ('00000000-0000-0000-0000-000000000002') $$,
    '23503',
    NULL,
    'unbekannte Objektart wird abgelehnt'
);

SELECT is(
    (SELECT count(*) FROM pm_test.ghosts
      WHERE id = '00000000-0000-0000-0000-000000000002'),
    0::bigint,
    'unbekannte Objektart hinterlässt keine Fachzeile'
);

-- table_name ist NOT NULL: eine Objektart kann nicht ohne bereits
-- bestehende Fachtabelle eingetragen werden.
SELECT throws_ok(
    $$ INSERT INTO pm.object_types (key, table_name) VALUES ('shadow', NULL) $$,
    '23502',
    NULL,
    'Objektart ohne zugeordnete Fachtabelle kann nicht eingetragen werden'
);

-- table_name ist UNIQUE: zwei Objektarten dürfen sich nicht dieselbe
-- Fachtabelle teilen.
SELECT throws_ok(
    $$ INSERT INTO pm.object_types (key, table_name, requires_project_assignment)
       VALUES ('impostor_type', 'pm_test.widgets'::regclass, false) $$,
    '23505',
    NULL,
    'zwei Objektarten können nicht dieselbe Fachtabelle verwenden'
);

-- Falsche Tabelle registriert sich nicht unter einer fremden Objektart:
-- 'widget' gehört zu pm_test.widgets, nicht zu pm_test.impostors.
CREATE TABLE pm_test.impostors (
    id uuid PRIMARY KEY
);

CREATE TRIGGER impostors_register_object
    AFTER INSERT ON pm_test.impostors
    FOR EACH ROW
    EXECUTE FUNCTION pm.register_object('widget');

SELECT throws_ok(
    $$ INSERT INTO pm_test.impostors (id) VALUES ('00000000-0000-0000-0000-000000000004') $$,
    '23514',
    NULL,
    'fremde Tabelle kann sich nicht unter einer nicht zugeordneten Objektart registrieren'
);

SELECT is(
    (SELECT count(*) FROM pm_test.impostors
      WHERE id = '00000000-0000-0000-0000-000000000004'),
    0::bigint,
    'fremde Tabelle hinterlässt keine Fachzeile'
);

SELECT ok(
    NOT has_table_privilege('editor', 'pm.object_registry', 'INSERT')
    AND NOT has_table_privilege('editor', 'pm.object_registry', 'UPDATE')
    AND NOT has_table_privilege('editor', 'pm.object_registry', 'DELETE'),
    'editor besitzt keine unmittelbaren Schreibrechte auf pm.object_registry'
);

-- pm.object_types gehört zur Schemaebene: Objektarten entstehen zusammen mit
-- ihrer Fachtabelle innerhalb einer Schema-Migration als schema_owner.
-- migrator darf die Zuordnung lesen, aber nicht unmittelbar verändern.
SELECT ok(
    has_table_privilege('migrator', 'pm.object_types', 'SELECT')
    AND NOT has_table_privilege('migrator', 'pm.object_types', 'INSERT')
    AND NOT has_table_privilege('migrator', 'pm.object_types', 'UPDATE')
    AND NOT has_table_privilege('migrator', 'pm.object_types', 'DELETE'),
    'migrator darf pm.object_types lesen, aber nicht unmittelbar schreiben'
);

-- Bereits anderweitig registrierte UUID: dieselbe id wird zuerst über
-- pm_test.widgets registriert, danach in pm_test.gadgets eingefügt. Die
-- zweite Einfügung muss am Primärschlüssel von pm.object_registry scheitern,
-- und die Fachzeile in pm_test.gadgets darf nicht zurückbleiben — das belegt
-- die zentrale Zusage: Scheitert die Registrierung, bleibt keine Fachzeile
-- ohne Registereintrag zurück.
INSERT INTO pm_test.widgets (id) VALUES ('00000000-0000-0000-0000-000000000005');

SELECT throws_ok(
    $$ INSERT INTO pm_test.gadgets (id) VALUES ('00000000-0000-0000-0000-000000000005') $$,
    '23505',
    NULL,
    'bereits anderweitig registrierte UUID kann nicht erneut registriert werden'
);

SELECT is(
    (SELECT count(*) FROM pm_test.gadgets
      WHERE id = '00000000-0000-0000-0000-000000000005'),
    0::bigint,
    'Fachzeile in pm_test.gadgets wird bei gescheiterter Registrierung zurückgenommen'
);

SELECT * FROM finish();
ROLLBACK;
