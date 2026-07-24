BEGIN;

SELECT plan(13);

SELECT has_function(
    'pm',
    'validate_nonempty_language_map',
    ARRAY['jsonb', 'integer', 'boolean'],
    'pm.validate_nonempty_language_map(jsonb, integer, boolean) existiert'
);

SELECT has_function(
    'pm',
    'set_updated_at',
    ARRAY[]::text[],
    'pm.set_updated_at() existiert'
);

SELECT lives_ok(
    $$ SELECT pm.validate_nonempty_language_map(
           '{"de": "Renderer bauen", "en": "Build renderer"}'::jsonb,
           3
       ) $$,
    'gültige Pflicht-Sprachkarte wird angenommen'
);

SELECT lives_ok(
    $$ SELECT pm.validate_nonempty_language_map(
           '{"de": "abc", "en": "xyz"}'::jsonb,
           3
       ) $$,
    'Sprachkarte mit genau der Mindestlänge wird angenommen'
);

SELECT throws_ok(
    $$ SELECT pm.validate_nonempty_language_map(
           '{"de": "ab", "en": "xyz"}'::jsonb,
           3
       ) $$,
    '23514',
    NULL,
    'zu kurzer Sprachwert wird abgelehnt'
);

SELECT throws_ok(
    $$ SELECT pm.validate_nonempty_language_map(
           '{"de": "   ", "en": "xyz"}'::jsonb,
           1
       ) $$,
    '23514',
    NULL,
    'nach btrim() leerer Sprachwert wird abgelehnt'
);

SELECT throws_ok(
    $$ SELECT pm.validate_nonempty_language_map(
           '{"de": "a", "en": "b"}'::jsonb,
           3
       ) $$,
    '23514',
    'Sprachkarte unterschreitet die Mindestlänge 3 bei den Sprachen: de, en',
    'Fehlermeldung nennt alle zu kurzen Sprachwerte'
);

SELECT lives_ok(
    $$ SELECT pm.validate_nonempty_language_map(NULL, 3, true) $$,
    'NULL wird bei p_allow_null = true angenommen'
);

SELECT throws_ok(
    $$ SELECT pm.validate_nonempty_language_map(NULL, 3) $$,
    '23514',
    NULL,
    'NULL wird bei p_allow_null = false als Vorgabe abgelehnt'
);

SELECT throws_ok(
    $$ SELECT pm.validate_nonempty_language_map(
           '{"de": "x", "en": "y"}'::jsonb,
           0
       ) $$,
    '22023',
    NULL,
    'Mindestlänge 0 wird als ungültiger Parameter abgelehnt'
);

SELECT throws_ok(
    $$ SELECT pm.validate_nonempty_language_map(
           '{"de": "x", "en": "y"}'::jsonb,
           NULL
       ) $$,
    '22023',
    NULL,
    'Mindestlänge NULL wird als ungültiger Parameter abgelehnt'
);

-- Isolierte, sitzungsbezogene Prüftabelle für die Triggerfunktion.
CREATE TEMP TABLE timestamped (
    id         uuid PRIMARY KEY,
    updated_at timestamptz NOT NULL DEFAULT statement_timestamp()
);

CREATE TRIGGER timestamped_set_updated_at
    BEFORE UPDATE ON timestamped
    FOR EACH ROW
    EXECUTE FUNCTION pm.set_updated_at();

INSERT INTO timestamped (id) VALUES
    ('00000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000002');

-- Ein einziges UPDATE versucht, updated_at auf einen frei gewählten
-- vergangenen Wert zu setzen.
UPDATE timestamped
   SET updated_at = '2000-01-01'::timestamptz;

SELECT ok(
    (
        SELECT bool_and(
            updated_at <> '2000-01-01'::timestamptz
        )
          FROM timestamped
    ),
    'set_updated_at() überschreibt einen frei übergebenen Wert'
);

SELECT is(
    (
        SELECT count(DISTINCT updated_at)
          FROM timestamped
    ),
    1::bigint,
    'set_updated_at() verwendet für alle Zeilen derselben Anweisung dieselbe Anweisungszeit'
);

SELECT * FROM finish();

ROLLBACK;
