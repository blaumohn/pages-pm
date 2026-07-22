BEGIN;
SELECT plan(16);

SELECT has_table('pm', 'relation_types', 'pm.relation_types existiert');
SELECT has_table('pm', 'relation_type_endpoints', 'pm.relation_type_endpoints existiert');

SELECT results_eq(
    $$ SELECT key FROM pm.relation_types ORDER BY key $$,
    ARRAY['derived_from', 'implements', 'references', 'supersedes'],
    'die vier Anfangs-Beziehungsarten sind vorhanden'
);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_types (key, title, description)
       VALUES (
           'blocks',
           '{"de": "blockiert", "en": "blocks"}'::jsonb,
           '{"de": "Das Quellobjekt blockiert das Zielobjekt.", "en": "The source object blocks the target object."}'::jsonb
       ) $$,
    'neue Beziehungsart mit vollständiger Sprachkarte wird angelegt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.relation_types (key, title, description)
       VALUES (
           'related_to',
           '{"de": "verwandt mit"}'::jsonb,
           '{"de": "x", "en": "y"}'::jsonb
       ) $$,
    '23514',
    NULL,
    'fehlende Pflichtsprache im Titel wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.relation_types (key, title, description)
       VALUES (
           'Related To',
           '{"de": "x", "en": "y"}'::jsonb,
           '{"de": "x", "en": "y"}'::jsonb
       ) $$,
    '23514',
    NULL,
    'ungültiges Schlüsselformat wird abgelehnt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
       VALUES ('unbekannt', 'issue', 'issue') $$,
    '23503',
    NULL,
    'Endpunkt für unbekannte Beziehungsart wird abgelehnt'
);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
       VALUES ('derived_from', 'kep_lite', 'issue') $$,
    'gültiger Endpunkt wird angelegt'
);

SELECT throws_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
       VALUES ('derived_from', 'kep_lite', 'issue') $$,
    '23505',
    NULL,
    'dieselbe Endpunktkombination kann nicht doppelt angelegt werden'
);

SELECT throws_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type, max_targets_per_source)
       VALUES ('derived_from', 'kep_lite', 'policy', 0) $$,
    '23514',
    NULL,
    'max_targets_per_source muss positiv sein'
);

SELECT throws_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type, max_sources_per_target)
       VALUES ('derived_from', 'kep_lite', 'runbook', -1) $$,
    '23514',
    NULL,
    'max_sources_per_target muss positiv sein'
);

SELECT lives_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
       VALUES ('derived_from', 'adr', 'issue') $$,
    'NULL bei beiden Kardinalitätsgrenzen (unbegrenzt) ist zulässig'
);

SELECT throws_ok(
    $$ INSERT INTO pm.relation_type_endpoints (relation_type, source_type, target_type)
       VALUES ('derived_from', 'unbekannter_typ', 'issue') $$,
    '23503',
    NULL,
    'unbekannte Objektart wird durch den Fremdschlüssel auf pm.object_types abgelehnt'
);

SELECT throws_ok(
    $$ UPDATE pm.relation_types SET key = 'renamed' WHERE key = 'blocks' $$,
    '23514',
    NULL,
    'key ist nach Anlage unveränderlich'
);

SELECT throws_ok(
    $$ INSERT INTO pm.relation_types (key, title, description)
       VALUES (
           'follows',
           '{"de": "folgt auf", "en": "follows"}'::jsonb,
           '{"de": "Nur Deutsch"}'::jsonb
       ) $$,
    '23514',
    NULL,
    'fehlende Pflichtsprache in description wird abgelehnt'
);

SELECT results_eq(
    $$ SELECT description_required, acyclic
       FROM pm.relation_types
       WHERE key = 'supersedes' $$,
    $$ VALUES (true, true) $$,
    'description_required und acyclic werden korrekt gespeichert'
);

SELECT * FROM finish();
ROLLBACK;
