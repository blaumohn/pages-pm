BEGIN;
SELECT plan(18);

SELECT has_table('pm', 'short_ids', 'pm.short_ids existiert');

-- Isolierte Prüfumgebung: eigene Fachtabelle und Objektart, unabhängig von
-- jeder anderen Testdatei. Das abschließende ROLLBACK entfernt alle
-- Testobjekte wieder.
DROP SCHEMA IF EXISTS pm_test CASCADE;
CREATE SCHEMA pm_test;

CREATE TABLE pm_test.widgets (
    id uuid PRIMARY KEY
);

INSERT INTO pm.object_types (key, table_name, requires_project_assignment) VALUES
    ('shortid_widget', 'pm_test.widgets'::regclass, false);

CREATE TRIGGER widgets_register_object
    AFTER INSERT ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.register_object('shortid_widget');

CREATE TRIGGER widgets_deregister_object
    BEFORE DELETE ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.deregister_object('shortid_widget');

-- [Spez §7.4, Regeln 1+2] Jedes registrierte Objekt erhält automatisch genau
-- eine Kurzkennung, ohne dass editor sie selbst vergeben muss.
INSERT INTO pm_test.widgets (id) VALUES ('00000000-0000-0000-0000-000000000001');

SELECT is(
    (SELECT count(*) FROM pm.short_ids
      WHERE object_id = '00000000-0000-0000-0000-000000000001'),
    1::bigint,
    '[Spez §7.4, Regel 1] registriertes Objekt erhält genau eine Kurzkennung'
);

SELECT ok(
    (SELECT value FROM pm.short_ids
      WHERE object_id = '00000000-0000-0000-0000-000000000001') ~ '^[a-z0-9]{4}$',
    '[Spez §7.4, Regel 1] Kurzkennung besteht aus vier Kleinbuchstaben/Ziffern'
);

-- [Spez §7.4] Zwei nacheinander angelegte Objekte erhalten verschiedene
-- Kurzkennungen. Echte Gleichzeitigkeit (zwei parallele Sitzungen) lässt sich
-- in einem einzelnen pgTAP-Testlauf nicht abbilden; dafür bräuchte es einen
-- gesonderten Lauf mit echten nebenläufigen Verbindungen.
INSERT INTO pm_test.widgets (id) VALUES ('00000000-0000-0000-0000-000000000002');

SELECT isnt(
    (SELECT value FROM pm.short_ids WHERE object_id = '00000000-0000-0000-0000-000000000001'),
    (SELECT value FROM pm.short_ids WHERE object_id = '00000000-0000-0000-0000-000000000002'),
    '[Spez §7.4, Regel 5] zwei verschiedene Objekte erhalten verschiedene Kurzkennungen'
);

-- [Spez §7.4, Regel 2] Erzwungene Kollision: pm.generate_short_id_candidate()
-- wird für die Dauer dieser Transaktion durch eine deterministische Folge
-- ersetzt, die beim zweiten Aufruf absichtlich denselben Wert wie beim ersten
-- liefert. pm.assign_short_id() muss die Ziehung wiederholen und einen
-- anderen, freien Wert eintragen, ohne die bereits vergebene Kurzkennung zu
-- verändern.
-- pm.generate_short_id_candidate() läuft (über pm.assign_short_id(), das
-- SECURITY DEFINER als schema_owner ausführt) nicht als der superuser, der
-- diesen Test aufruft. Ohne diese GRANTs scheitert der Zugriff auf die
-- Sequenz mit "permission denied for schema pm_test".
CREATE SEQUENCE pm_test.short_id_calls;
GRANT USAGE ON SCHEMA pm_test TO schema_owner;
GRANT USAGE, SELECT ON SEQUENCE pm_test.short_id_calls TO schema_owner;

CREATE OR REPLACE FUNCTION pm.generate_short_id_candidate()
RETURNS text
LANGUAGE sql
VOLATILE
AS $$
    SELECT (ARRAY['zzz1', 'zzz1', 'zzz2'])[nextval('pm_test.short_id_calls')];
$$;

INSERT INTO pm_test.widgets (id) VALUES ('00000000-0000-0000-0000-000000000003');
INSERT INTO pm_test.widgets (id) VALUES ('00000000-0000-0000-0000-000000000004');

SELECT is(
    (SELECT value FROM pm.short_ids WHERE object_id = '00000000-0000-0000-0000-000000000003'),
    'zzz1',
    '[Spez §7.4, Regel 2] erster Aufruf erhält die erste Kandidatin unverändert'
);

SELECT is(
    (SELECT value FROM pm.short_ids WHERE object_id = '00000000-0000-0000-0000-000000000004'),
    'zzz2',
    '[Spez §7.4, Regel 2] Kollision bei der Kandidatin führt zu einer anderen Kurzkennung'
);

SELECT is(
    (SELECT count(*) FROM pm.short_ids WHERE value = 'zzz1'),
    1::bigint,
    '[Spez §7.4, Regel 2] die zuerst vergebene Kurzkennung bleibt einmalig bestehen'
);

-- [Spez §7.4, Regel 3] Löschen des Objekts setzt object_id auf NULL, die
-- Zeile und ihr Wert bleiben bestehen; die Kurzkennung wird nicht erneut
-- vergeben. Der Wert wird vor dem Löschen in einer temporären Tabelle
-- festgehalten, weil er über object_id danach nicht mehr auffindbar ist.
CREATE TEMP TABLE pm_test_deleted_short_id AS
    SELECT value FROM pm.short_ids WHERE object_id = '00000000-0000-0000-0000-000000000001';

DELETE FROM pm_test.widgets WHERE id = '00000000-0000-0000-0000-000000000001';

SELECT is(
    (
        SELECT value
          FROM pm.short_ids
         WHERE object_id IS NULL
           AND value = (SELECT value FROM pm_test_deleted_short_id)
    ),
    (SELECT value FROM pm_test_deleted_short_id),
    '[Spez §7.4, Regel 3] gelöschte Kurzkennung bleibt reserviert'
);

-- [Spez §7.4, Regel 6] Auflösung ist ausschließlich exakt und liefert bei
-- einer gelöschten Kurzkennung NULL — ins Leere, nie auf ein anderes Objekt.
SELECT is(
    pm.resolve_short_id((SELECT value FROM pm_test_deleted_short_id)),
    NULL::uuid,
    '[Spez §7.4, Regel 3+6] Auflösung einer gelöschten Kurzkennung ergibt NULL'
);

SELECT is(
    pm.resolve_short_id('does-not-exist'),
    NULL::uuid,
    '[Spez §7.4, Regel 6] Auflösung eines unbekannten Werts ergibt NULL'
);

SELECT is(
    pm.resolve_short_id((SELECT value FROM pm.short_ids WHERE object_id = '00000000-0000-0000-0000-000000000002')),
    '00000000-0000-0000-0000-000000000002'::uuid,
    '[Spez §7.4, Regel 6] Auflösung einer lebenden Kurzkennung ergibt das richtige Objekt'
);

-- [Spez §7.4, Regeln 1+2] Zweiter Aufruf für dasselbe Objekt wird mit einer
-- verständlichen Meldung abgelehnt, statt am partiellen Unique-Index auf
-- object_id mit einem rohen Fehler zu scheitern.
SELECT throws_ok(
    $$ SELECT pm.assign_short_id('00000000-0000-0000-0000-000000000002') $$,
    '23505',
    NULL,
    'zweiter Aufruf von pm.assign_short_id() für dasselbe Objekt wird abgelehnt'
);

-- Unbekanntes Objekt: pm.assign_short_id() prüft ausdrücklich gegen
-- pm.object_registry, bevor es überhaupt eine Kandidatin zieht.
SELECT throws_ok(
    $$ SELECT pm.assign_short_id('00000000-0000-0000-0000-000000000099') $$,
    '23503',
    NULL,
    'pm.assign_short_id() für ein nicht registriertes Objekt wird abgelehnt'
);

-- Scheitert die Fachzeilenanlage bereits an einer unbekannten Objektart, wird
-- pm.assign_short_id() nie erreicht — es entsteht keine verwaiste
-- Kurzkennung.
CREATE TABLE pm_test.ghosts (
    id uuid PRIMARY KEY
);

CREATE TRIGGER ghosts_register_object
    AFTER INSERT ON pm_test.ghosts
    FOR EACH ROW
    EXECUTE FUNCTION pm.register_object('shortid_ghost');

SELECT throws_ok(
    $$ INSERT INTO pm_test.ghosts (id) VALUES ('00000000-0000-0000-0000-000000000005') $$,
    '23503',
    NULL,
    'gescheiterte Registrierung erreicht pm.assign_short_id() nicht'
);

SELECT is(
    (SELECT count(*) FROM pm.short_ids
      WHERE object_id = '00000000-0000-0000-0000-000000000005'),
    0::bigint,
    'gescheiterte Registrierung hinterlässt keine Kurzkennung'
);

-- [Rechte] Kurzkennungen entstehen ausschließlich über pm.assign_short_id()
-- (aufgerufen aus pm.register_object()); editor und reader dürfen
-- pm.short_ids nur lesen.
SELECT ok(
    has_table_privilege('editor', 'pm.short_ids', 'SELECT')
    AND NOT has_table_privilege('editor', 'pm.short_ids', 'INSERT')
    AND NOT has_table_privilege('editor', 'pm.short_ids', 'UPDATE')
    AND NOT has_table_privilege('editor', 'pm.short_ids', 'DELETE'),
    'editor darf pm.short_ids nur lesen, nicht schreiben'
);

SELECT ok(
    has_table_privilege('reader', 'pm.short_ids', 'SELECT')
    AND NOT has_table_privilege('reader', 'pm.short_ids', 'INSERT')
    AND NOT has_table_privilege('reader', 'pm.short_ids', 'UPDATE')
    AND NOT has_table_privilege('reader', 'pm.short_ids', 'DELETE'),
    'reader darf pm.short_ids nur lesen, nicht schreiben'
);

SELECT ok(
    has_function_privilege('editor', 'pm.resolve_short_id(text)', 'EXECUTE')
    AND has_function_privilege('reader', 'pm.resolve_short_id(text)', 'EXECUTE')
    AND NOT has_function_privilege('editor', 'pm.assign_short_id(uuid)', 'EXECUTE'),
    'pm.resolve_short_id() ist für editor/reader ausführbar, pm.assign_short_id() nicht'
);

SELECT * FROM finish();
ROLLBACK;
