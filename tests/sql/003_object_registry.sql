BEGIN;
SELECT plan(15);

SELECT has_table('pm', 'object_types', 'pm.object_types existiert');
SELECT has_table('pm', 'object_registry', 'pm.object_registry existiert');

-- Isolierte Prüfumgebung: eigenes Fixture-Schema mit zwei künstlichen
-- Objektarten/Fachtabellen, unabhängig von project/002_object_types.sql und
-- von jeder anderen Testdatei. Wird durch das abschließende ROLLBACK wieder
-- entfernt.
DROP SCHEMA IF EXISTS pm_test CASCADE;
CREATE SCHEMA pm_test;

CREATE TABLE pm_test.widgets (
    id uuid PRIMARY KEY
);

CREATE TABLE pm_test.gadgets (
    id uuid PRIMARY KEY
);

-- table_name kann erst gesetzt werden, nachdem die Fixture-Tabelle besteht.
INSERT INTO pm.object_types (key, table_name) VALUES
    ('widget', 'pm_test.widgets'::regclass),
    ('gadget', 'pm_test.gadgets'::regclass);

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

-- Objektart ohne zugeordnete Fachtabelle (table_name = NULL).
INSERT INTO pm.object_types (key, table_name) VALUES ('shadow', NULL);

CREATE TABLE pm_test.shadows (
    id uuid PRIMARY KEY
);

CREATE TRIGGER shadows_register_object
    AFTER INSERT ON pm_test.shadows
    FOR EACH ROW
    EXECUTE FUNCTION pm.register_object('shadow');

SELECT throws_ok(
    $$ INSERT INTO pm_test.shadows (id) VALUES ('00000000-0000-0000-0000-000000000003') $$,
    '23514',
    NULL,
    'Objektart ohne zugeordnete Fachtabelle kann nicht registrieren'
);

SELECT is(
    (SELECT count(*) FROM pm_test.shadows
      WHERE id = '00000000-0000-0000-0000-000000000003'),
    0::bigint,
    'Objektart ohne Fachtabelle hinterlässt keine Fachzeile'
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
