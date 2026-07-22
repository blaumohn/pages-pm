BEGIN;
SELECT plan(6);

SELECT has_table(
    'pm',
    'languages',
    'pm.languages existiert'
);

SELECT results_eq(
    $$ SELECT code
       FROM pm.languages
       WHERE is_required
       ORDER BY code $$,
    ARRAY['de', 'en'],
    'de und en sind Pflichtsprachen'
);

SELECT lives_ok(
    $$ INSERT INTO pm.languages (code, autonym, is_required)
       VALUES ('fr', 'Français', false) $$,
    'eine optionale Sprache kann ergänzt werden'
);

SELECT lives_ok(
    $$ SELECT pm.validate_language_map(
           '{"de": "Deutsch", "en": "English", "fr": "Français"}'::jsonb
       ) $$,
    'vollständige Sprachkarte mit optionaler Sprache wird akzeptiert'
);

SELECT throws_ok(
    $$ SELECT pm.validate_language_map(
           '{"de": "x"}'::jsonb
       ) $$,
    '23514',
    NULL,
    'fehlende Pflichtsprache en wird abgelehnt'
);

SELECT throws_ok(
    $$ SELECT pm.validate_language_map(
           '{"de": "x", "en": "y", "nl": "z"}'::jsonb
       ) $$,
    '23514',
    NULL,
    'unbekannte Sprache nl wird abgelehnt'
);

SELECT * FROM finish();
ROLLBACK;
