BEGIN;
SELECT plan(29);

SELECT has_table('pm', 'object_relations', 'pm.object_relations existiert');

-- Isolierte Prüfumgebung: eigene künstliche Objektarten und Fachtabellen,
-- unabhängig von jeder anderen Testdatei. Eigene Endpunktregeln, analog zu
-- den Beziehungsarten aus project/002_relation_types.sql, da Phase A bewusst
-- noch keine wirklichen Projektendpunkte enthält.
DROP SCHEMA IF EXISTS pm_test CASCADE;
CREATE SCHEMA pm_test;

CREATE TABLE pm_test.widgets (
    id uuid PRIMARY KEY
);

CREATE TABLE pm_test.gadgets (
    id uuid PRIMARY KEY
);

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

-- Testobjekte mit innerhalb dieser Testtransaktion eindeutigen festen UUIDs.
INSERT INTO pm_test.widgets (id) VALUES
    ('00000000-0000-0000-0000-000000000001'), -- K1 (Rolle: kep_lite-artig)
    ('00000000-0000-0000-0000-000000000002'); -- K2 (Rolle: kep_lite-artig)

INSERT INTO pm_test.gadgets (id) VALUES
    ('00000000-0000-0000-0000-000000000011'), -- I1 (Rolle: issue-artig)
    ('00000000-0000-0000-0000-000000000012'), -- I2 (Rolle: issue-artig)
    ('00000000-0000-0000-0000-000000000013'), -- I3 (Rolle: issue-artig)
    ('00000000-0000-0000-0000-000000000021'), -- P1 (Rolle: policy-artig)
    ('00000000-0000-0000-0000-000000000022'); -- P2 (Rolle: policy-artig)

-- Eigene Beziehungsarten für diesen Test, unabhängig von
-- project/002_relation_types.sql.
INSERT INTO pm.relation_types (key, title, description, description_required, acyclic) VALUES
    ('t_derived_from', '{"de": "x", "en": "x"}'::jsonb, '{"de": "x", "en": "x"}'::jsonb, false, true),
    ('t_implements',   '{"de": "x", "en": "x"}'::jsonb, '{"de": "x", "en": "x"}'::jsonb, false, false),
    ('t_supersedes',   '{"de": "x", "en": "x"}'::jsonb, '{"de": "x", "en": "x"}'::jsonb, true,  true),
    ('t_references',   '{"de": "x", "en": "x"}'::jsonb, '{"de": "x", "en": "x"}'::jsonb, true,  false);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints
           (relation_type, source_type, target_type, max_targets_per_source)
       VALUES ('t_derived_from', 'widget', 'gadget', 1) $$,
    'Endpunkt t_derived_from widget->gadget (Höchstgrenze 1 Ziel) wird registriert'
);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
       VALUES ('t_derived_from', 'gadget', 'gadget') $$,
    'Endpunkt t_derived_from gadget->gadget (unbegrenzt) wird registriert'
);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
       VALUES ('t_references', 'gadget', 'gadget') $$,
    'Endpunkt t_references gadget->gadget wird registriert'
);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints
           (relation_type, source_type, target_type, max_sources_per_target)
       VALUES ('t_references', 'widget', 'gadget', 1) $$,
    'Endpunkt t_references widget->gadget (Höchstgrenze 1 Quelle) wird registriert'
);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
       VALUES ('t_supersedes', 'gadget', 'gadget') $$,
    'Endpunkt t_supersedes gadget->gadget wird registriert'
);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
       VALUES ('t_implements', 'gadget', 'widget') $$,
    'Endpunkt t_implements gadget->widget wird registriert'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       VALUES (
           '00000000-0000-0000-0000-000000000001',
           '00000000-0000-0000-0000-000000000011',
           't_derived_from'
       ) $$,
    'K1 t_derived_from I1 wird angelegt (registrierter Endpunkt)'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       VALUES (
           '00000000-0000-0000-0000-000000000001',
           '00000000-0000-0000-0000-000000000011',
           't_implements'
       ) $$,
    '23514',
    NULL,
    't_implements widget->gadget ist nicht registriert und wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       VALUES (
           '00000000-0000-0000-0000-000000000011',
           '00000000-0000-0000-0000-000000000011',
           't_references'
       ) $$,
    '23514',
    NULL,
    'Selbstbeziehung wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       VALUES (
           '00000000-0000-0000-0000-000000000021',
           '00000000-0000-0000-0000-000000000022',
           't_supersedes'
       ) $$,
    '23514',
    NULL,
    't_supersedes ohne Beschreibung wird abgelehnt (description_required)'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type, description)
       VALUES (
           '00000000-0000-0000-0000-000000000021',
           '00000000-0000-0000-0000-000000000022',
           't_supersedes',
           '{"de": "P1 ersetzt P2.", "en": "P1 supersedes P2."}'::jsonb
       ) $$,
    't_supersedes mit vollständiger Beschreibung wird angelegt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       VALUES (
           '00000000-0000-0000-0000-000000000001',
           '00000000-0000-0000-0000-000000000012',
           't_derived_from'
       ) $$,
    '23514',
    NULL,
    'zweites Ziel überschreitet max_targets_per_source = 1'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       VALUES (
           '00000000-0000-0000-0000-000000000011',
           '00000000-0000-0000-0000-000000000012',
           't_derived_from'
       ) $$,
    'I1 t_derived_from I2 wird angelegt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       VALUES (
           '00000000-0000-0000-0000-000000000011',
           '00000000-0000-0000-0000-000000000012',
           't_derived_from'
       ) $$,
    '23505',
    NULL,
    'dieselbe Beziehung kann nicht doppelt angelegt werden'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       VALUES (
           '00000000-0000-0000-0000-000000000012',
           '00000000-0000-0000-0000-000000000011',
           't_derived_from'
       ) $$,
    '23514',
    NULL,
    'umgekehrte Kante würde einen zweigliedrigen Zyklus schließen und wird abgelehnt'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       VALUES (
           '00000000-0000-0000-0000-000000000012',
           '00000000-0000-0000-0000-000000000013',
           't_derived_from'
       ) $$,
    'I2 t_derived_from I3 wird angelegt (Kette I1->I2->I3)'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       VALUES (
           '00000000-0000-0000-0000-000000000013',
           '00000000-0000-0000-0000-000000000011',
           't_derived_from'
       ) $$,
    '23514',
    NULL,
    'mehrgliedriger Zyklus I1->I2->I3->I1 wird abgelehnt'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type, description)
       VALUES (
           '00000000-0000-0000-0000-000000000001',
           '00000000-0000-0000-0000-000000000013',
           't_references',
           jsonb_build_object('de', 'K1 verweist auf I3.', 'en', 'K1 references I3.')
       ) $$,
    'K1 t_references I3 wird angelegt (erste Quelle für max_sources_per_target = 1)'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type, description)
       VALUES (
           '00000000-0000-0000-0000-000000000002',
           '00000000-0000-0000-0000-000000000013',
           't_references',
           jsonb_build_object('de', 'K2 verweist auf I3.', 'en', 'K2 references I3.')
       ) $$,
    '23514',
    NULL,
    'zweite Quelle überschreitet max_sources_per_target = 1'
);

SELECT throws_ok(
    $$ UPDATE pm.object_relations
       SET target_id = '00000000-0000-0000-0000-000000000012'
       WHERE source_id = '00000000-0000-0000-0000-000000000001'
         AND target_id = '00000000-0000-0000-0000-000000000011'
         AND relation_type = 't_derived_from' $$,
    '23514',
    NULL,
    'target_id ist nach Anlage unveränderlich'
);

SELECT throws_ok(
    $$ UPDATE pm.object_relations
       SET source_id = '00000000-0000-0000-0000-000000000002'
       WHERE source_id = '00000000-0000-0000-0000-000000000001'
         AND target_id = '00000000-0000-0000-0000-000000000011'
         AND relation_type = 't_derived_from' $$,
    '23514',
    NULL,
    'source_id ist nach Anlage unveränderlich'
);

SELECT throws_ok(
    $$ UPDATE pm.object_relations
       SET relation_type = 't_references'
       WHERE source_id = '00000000-0000-0000-0000-000000000001'
         AND target_id = '00000000-0000-0000-0000-000000000011'
         AND relation_type = 't_derived_from' $$,
    '23514',
    NULL,
    'relation_type ist nach Anlage unveränderlich'
);

SELECT throws_ok(
    $$ UPDATE pm.object_relations
       SET created_at = created_at + interval '1 second'
       WHERE source_id = '00000000-0000-0000-0000-000000000001'
         AND target_id = '00000000-0000-0000-0000-000000000011'
         AND relation_type = 't_derived_from' $$,
    '23514',
    NULL,
    'created_at ist nach Anlage unveränderlich'
);

SELECT lives_ok(
    $$ UPDATE pm.object_relations
       SET description = jsonb_build_object(
           'de', 'K1 wurde aus I1 abgeleitet.',
           'en', 'K1 was derived from I1.'
       )
       WHERE source_id = '00000000-0000-0000-0000-000000000001'
         AND target_id = '00000000-0000-0000-0000-000000000011'
         AND relation_type = 't_derived_from' $$,
    'description darf nach Anlage geändert werden'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type, description)
       VALUES (
           '00000000-0000-0000-0000-000000000012',
           '00000000-0000-0000-0000-000000000001',
           't_implements',
           '{"de": "Nur Deutsch"}'::jsonb
       ) $$,
    '23514',
    NULL,
    'unvollständige description wird abgelehnt, auch wenn nicht verpflichtend'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type, description)
       VALUES (
           '00000000-0000-0000-0000-000000000013',
           '00000000-0000-0000-0000-000000000001',
           't_implements',
           '{"de": "x", "en": "y", "nl": "z"}'::jsonb
       ) $$,
    '23514',
    NULL,
    'unbekannte Sprache nl in description wird abgelehnt'
);

-- ON DELETE RESTRICT statt CASCADE: Eine bestehende Beziehung blockiert
-- die Löschung beider beteiligten Objekte. PostgreSQL meldet dies als
-- 23001 (restrict_violation).
SELECT throws_ok(
    $$ DELETE FROM pm_test.gadgets
       WHERE id = '00000000-0000-0000-0000-000000000011' $$,
    '23001',
    NULL,
    'Objekt mit bestehender Beziehung als Ziel kann nicht gelöscht werden'
);

SELECT throws_ok(
    $$ DELETE FROM pm_test.widgets
       WHERE id = '00000000-0000-0000-0000-000000000001' $$,
    '23001',
    NULL,
    'Objekt mit bestehender Beziehung als Quelle kann nicht gelöscht werden'
);

SELECT * FROM finish();
ROLLBACK;
