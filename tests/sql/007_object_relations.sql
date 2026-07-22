BEGIN;
SELECT plan(27);

SELECT has_table('pm', 'object_relations', 'pm.object_relations existiert');

-- Testobjekte mit innerhalb dieser Testtransaktion eindeutigen deutschen Titeln.
INSERT INTO pm.objects (object_type, title) VALUES
    ('kep_lite', '{"de": "K1", "en": "K1"}'::jsonb),
    ('kep_lite', '{"de": "K2", "en": "K2"}'::jsonb),
    ('issue',    '{"de": "I1", "en": "I1"}'::jsonb),
    ('issue',    '{"de": "I2", "en": "I2"}'::jsonb),
    ('issue',    '{"de": "I3", "en": "I3"}'::jsonb),
    ('policy',   '{"de": "P1", "en": "P1"}'::jsonb),
    ('policy',   '{"de": "P2", "en": "P2"}'::jsonb);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints
           (relation_type, source_type, target_type, max_targets_per_source)
       VALUES ('derived_from', 'kep_lite', 'issue', 1) $$,
    'Endpunkt derived_from kep_lite->issue (Höchstgrenze 1 Ziel) wird registriert'
);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
       VALUES ('derived_from', 'issue', 'issue') $$,
    'Endpunkt derived_from issue->issue (unbegrenzt) wird registriert'
);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
       VALUES ('references', 'issue', 'issue') $$,
    'Endpunkt references issue->issue wird registriert'
);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints
           (relation_type, source_type, target_type, max_sources_per_target)
       VALUES ('references', 'kep_lite', 'issue', 1) $$,
    'Endpunkt references kep_lite->issue (Höchstgrenze 1 Quelle) wird registriert'
);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
       VALUES ('supersedes', 'policy', 'policy') $$,
    'Endpunkt supersedes policy->policy wird registriert'
);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
       VALUES ('implements', 'issue', 'kep_lite') $$,
    'Endpunkt implements issue->kep_lite wird registriert'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'kep_lite' AND title->>'de' = 'K1'),
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I1'),
           'derived_from' $$,
    'K1 derived_from I1 wird angelegt (registrierter Endpunkt)'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'kep_lite' AND title->>'de' = 'K1'),
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I1'),
           'implements' $$,
    '23514',
    NULL,
    'implements kep_lite->issue ist nicht registriert und wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I1'),
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I1'),
           'references' $$,
    '23514',
    NULL,
    'Selbstbeziehung wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'policy' AND title->>'de' = 'P1'),
           (SELECT id FROM pm.objects WHERE object_type = 'policy' AND title->>'de' = 'P2'),
           'supersedes' $$,
    '23514',
    NULL,
    'supersedes ohne Beschreibung wird abgelehnt (description_required)'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type, description)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'policy' AND title->>'de' = 'P1'),
           (SELECT id FROM pm.objects WHERE object_type = 'policy' AND title->>'de' = 'P2'),
           'supersedes',
           '{"de": "P1 ersetzt P2.", "en": "P1 supersedes P2."}'::jsonb $$,
    'supersedes mit vollständiger Beschreibung wird angelegt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'kep_lite' AND title->>'de' = 'K1'),
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I2'),
           'derived_from' $$,
    '23514',
    NULL,
    'zweites Ziel überschreitet max_targets_per_source = 1'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I1'),
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I2'),
           'derived_from' $$,
    'I1 derived_from I2 wird angelegt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I1'),
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I2'),
           'derived_from' $$,
    '23505',
    NULL,
    'dieselbe Beziehung kann nicht doppelt angelegt werden'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I2'),
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I1'),
           'derived_from' $$,
    '23514',
    NULL,
    'umgekehrte Kante würde einen zweigliedrigen Zyklus schließen und wird abgelehnt'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I2'),
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I3'),
           'derived_from' $$,
    'I2 derived_from I3 wird angelegt (Kette I1->I2->I3)'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I3'),
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I1'),
           'derived_from' $$,
    '23514',
    NULL,
    'mehrgliedriger Zyklus I1->I2->I3->I1 wird abgelehnt'
);

SELECT lives_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type, description)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'kep_lite' AND title->>'de' = 'K1'),
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I3'),
           'references',
           jsonb_build_object('de', 'K1 verweist auf I3.', 'en', 'K1 references I3.') $$,
    'K1 references I3 wird angelegt (erste Quelle für max_sources_per_target = 1)'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type, description)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'kep_lite' AND title->>'de' = 'K2'),
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I3'),
           'references',
           jsonb_build_object('de', 'K2 verweist auf I3.', 'en', 'K2 references I3.') $$,
    '23514',
    NULL,
    'zweite Quelle überschreitet max_sources_per_target = 1'
);

SELECT throws_ok(
    $$ UPDATE pm.object_relations AS relation
       SET target_id = (
           SELECT id FROM pm.objects
           WHERE object_type = 'issue' AND title->>'de' = 'I2'
       )
       WHERE relation.source_id = (
           SELECT id FROM pm.objects
           WHERE object_type = 'kep_lite' AND title->>'de' = 'K1'
       )
         AND relation.target_id = (
           SELECT id FROM pm.objects
           WHERE object_type = 'issue' AND title->>'de' = 'I1'
       )
         AND relation.relation_type = 'derived_from' $$,
    '23514',
    NULL,
    'target_id ist nach Anlage unveränderlich'
);

SELECT throws_ok(
    $$ UPDATE pm.object_relations AS relation
       SET source_id = (
           SELECT id FROM pm.objects
           WHERE object_type = 'kep_lite' AND title->>'de' = 'K2'
       )
       WHERE relation.source_id = (
           SELECT id FROM pm.objects
           WHERE object_type = 'kep_lite' AND title->>'de' = 'K1'
       )
         AND relation.target_id = (
           SELECT id FROM pm.objects
           WHERE object_type = 'issue' AND title->>'de' = 'I1'
       )
         AND relation.relation_type = 'derived_from' $$,
    '23514',
    NULL,
    'source_id ist nach Anlage unveränderlich'
);

SELECT throws_ok(
    $$ UPDATE pm.object_relations AS relation
       SET relation_type = 'references'
       WHERE relation.source_id = (
           SELECT id FROM pm.objects
           WHERE object_type = 'kep_lite' AND title->>'de' = 'K1'
       )
         AND relation.target_id = (
           SELECT id FROM pm.objects
           WHERE object_type = 'issue' AND title->>'de' = 'I1'
       )
         AND relation.relation_type = 'derived_from' $$,
    '23514',
    NULL,
    'relation_type ist nach Anlage unveränderlich'
);

SELECT throws_ok(
    $$ UPDATE pm.object_relations AS relation
       SET created_at = relation.created_at + interval '1 second'
       WHERE relation.source_id = (
           SELECT id FROM pm.objects
           WHERE object_type = 'kep_lite' AND title->>'de' = 'K1'
       )
         AND relation.target_id = (
           SELECT id FROM pm.objects
           WHERE object_type = 'issue' AND title->>'de' = 'I1'
       )
         AND relation.relation_type = 'derived_from' $$,
    '23514',
    NULL,
    'created_at ist nach Anlage unveränderlich'
);

SELECT lives_ok(
    $$ UPDATE pm.object_relations AS relation
       SET description = jsonb_build_object(
           'de', 'K1 wurde aus I1 abgeleitet.',
           'en', 'K1 was derived from I1.'
       )
       WHERE relation.source_id = (
           SELECT id FROM pm.objects
           WHERE object_type = 'kep_lite' AND title->>'de' = 'K1'
       )
         AND relation.target_id = (
           SELECT id FROM pm.objects
           WHERE object_type = 'issue' AND title->>'de' = 'I1'
       )
         AND relation.relation_type = 'derived_from' $$,
    'description darf nach Anlage geändert werden'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type, description)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I2'),
           (SELECT id FROM pm.objects WHERE object_type = 'kep_lite' AND title->>'de' = 'K1'),
           'implements',
           '{"de": "Nur Deutsch"}'::jsonb $$,
    '23514',
    NULL,
    'unvollständige description wird abgelehnt, auch wenn nicht verpflichtend'
);

SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type, description)
       SELECT
           (SELECT id FROM pm.objects WHERE object_type = 'issue' AND title->>'de' = 'I3'),
           (SELECT id FROM pm.objects WHERE object_type = 'kep_lite' AND title->>'de' = 'K1'),
           'implements',
           '{"de": "x", "en": "y", "nl": "z"}'::jsonb $$,
    '23514',
    NULL,
    'unbekannte Sprache nl in description wird abgelehnt'
);

SELECT * FROM finish();
ROLLBACK;
