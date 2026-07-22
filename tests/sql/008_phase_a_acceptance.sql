BEGIN;
SELECT plan(10);

-- Vollständiges Abnahmekriterium für Phase A (siehe Umsetzungsentwurf,
-- Abschnitt 11): Eine künstliche Test-Fachtabelle kann eine Zeile anlegen,
-- automatisch registrieren, über Bereiche, Herkunft und Beziehungen
-- verwenden und nur nach ausdrücklicher Auflösung blockierender
-- Abhängigkeiten löschen. Läuft vollständig unabhängig von den isolierten
-- Einzeltests (002-007) und legt seine eigene Prüfumgebung an.

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

-- 1: zwei Fachobjekte einfügen, jeweils automatisch registriert.
INSERT INTO pm_test.widgets (id) VALUES
    ('00000000-0000-0000-0000-000000000001'), -- A
    ('00000000-0000-0000-0000-000000000002'); -- B

SELECT results_eq(
    $$ SELECT object_type FROM pm.object_registry
       WHERE id IN (
           '00000000-0000-0000-0000-000000000001',
           '00000000-0000-0000-0000-000000000002'
       )
       ORDER BY id $$,
    ARRAY['widget', 'widget'],
    'beide Fachobjekte sind automatisch registriert'
);

-- 2: Bereichszuordnung anlegen.
INSERT INTO pm.areas (key, title) VALUES
    ('acceptance_area', '{"de": "Abnahme", "en": "Acceptance"}'::jsonb);

SELECT lives_ok(
    $$ INSERT INTO pm.object_areas (object_id, area_id)
       SELECT '00000000-0000-0000-0000-000000000001', id
       FROM pm.areas WHERE key = 'acceptance_area' $$,
    'Bereichszuordnung für A wird angelegt'
);

-- 3: Herkunft anlegen.
SELECT lives_ok(
    $$ INSERT INTO pm.object_origins (object_id, source_system, source_reference)
       VALUES ('00000000-0000-0000-0000-000000000001', 'jira', 'ACCEPT-1') $$,
    'Herkunft für A wird angelegt'
);

-- 4: Beziehungsart und erlaubten Endpunkt anlegen; Beziehung A -> B einfügen.
INSERT INTO pm.relation_types (key, title, description, description_required, acyclic)
VALUES (
    'acceptance_references',
    '{"de": "x", "en": "x"}'::jsonb,
    '{"de": "x", "en": "x"}'::jsonb,
    false, false
);

INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
VALUES ('acceptance_references', 'widget', 'widget');

SELECT lives_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       VALUES (
           '00000000-0000-0000-0000-000000000001',
           '00000000-0000-0000-0000-000000000002',
           'acceptance_references'
       ) $$,
    'Beziehung A -> B wird angelegt'
);

-- 5: Löschung von A ist blockiert — sowohl durch die Beziehung als auch
-- durch die Herkunft (jeweils ON DELETE RESTRICT, 23001).
SELECT throws_ok(
    $$ DELETE FROM pm_test.widgets WHERE id = '00000000-0000-0000-0000-000000000001' $$,
    '23001',
    NULL,
    'A kann wegen bestehender Beziehung/Herkunft nicht gelöscht werden'
);

-- 5b: Löschung von B (nur als Beziehungsziel betroffen) ist ebenfalls
-- blockiert.
SELECT throws_ok(
    $$ DELETE FROM pm_test.widgets WHERE id = '00000000-0000-0000-0000-000000000002' $$,
    '23001',
    NULL,
    'B kann wegen bestehender Beziehung als Ziel nicht gelöscht werden'
);

-- 6: Beziehung und Herkunft ausdrücklich entfernen.
SELECT lives_ok(
    $$ DELETE FROM pm.object_relations
       WHERE source_id = '00000000-0000-0000-0000-000000000001'
         AND target_id = '00000000-0000-0000-0000-000000000002'
         AND relation_type = 'acceptance_references' $$,
    'Beziehung A -> B wird entfernt'
);

SELECT lives_ok(
    $$ DELETE FROM pm.object_origins
       WHERE object_id = '00000000-0000-0000-0000-000000000001' $$,
    'Herkunft für A wird entfernt'
);

-- 7: Fachzeile A erfolgreich löschen.
SELECT lives_ok(
    $$ DELETE FROM pm_test.widgets WHERE id = '00000000-0000-0000-0000-000000000001' $$,
    'A kann nach Entfernen von Beziehung und Herkunft gelöscht werden'
);

-- 8: Registerzeile und Bereichszuordnung von A sind verschwunden.
SELECT is(
    (
        (SELECT count(*) FROM pm.object_registry
          WHERE id = '00000000-0000-0000-0000-000000000001')
        +
        (SELECT count(*) FROM pm.object_areas
          WHERE object_id = '00000000-0000-0000-0000-000000000001')
    ),
    0::bigint,
    'Registerzeile und Bereichszuordnung von A sind nach dem Löschen verschwunden'
);

SELECT * FROM finish();
ROLLBACK;
