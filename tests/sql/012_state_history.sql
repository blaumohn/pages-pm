BEGIN;
SELECT plan(20);

SELECT has_table('pm', 'state_history', 'pm.state_history existiert');

-- Isolierte Prüfumgebung: eigene Fachtabelle und Objektart, unabhängig von
-- jeder anderen Testdatei.
DROP SCHEMA IF EXISTS pm_test CASCADE;
CREATE SCHEMA pm_test;

CREATE TABLE pm_test.widgets (
    id uuid PRIMARY KEY
);

INSERT INTO pm.object_types (key, table_name) VALUES
    ('history_widget', 'pm_test.widgets'::regclass);

CREATE TRIGGER widgets_register_object
    AFTER INSERT ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.register_object('history_widget');

CREATE TRIGGER widgets_deregister_object
    BEFORE DELETE ON pm_test.widgets
    FOR EACH ROW
    EXECUTE FUNCTION pm.deregister_object('history_widget');

INSERT INTO pm_test.widgets (id) VALUES
    ('00000000-0000-0000-0000-000000000001'), -- A
    ('00000000-0000-0000-0000-000000000002'); -- B

-- [Spez P-010] erster Eintrag erhält seq = 1.
SELECT is(
    pm.append_state_history(
        '00000000-0000-0000-0000-000000000001',
        'state_change',
        '{"de": "Erster Wechsel", "en": "First change"}'::jsonb
    ),
    1,
    '[Spez P-010] erster Eintrag eines Objekts erhält seq = 1'
);

-- [Spez P-010] zweiter Eintrag desselben Objekts erhält seq = 2.
SELECT is(
    pm.append_state_history(
        '00000000-0000-0000-0000-000000000001',
        'state_change',
        '{"de": "Zweiter Wechsel", "en": "Second change"}'::jsonb
    ),
    2,
    '[Spez P-010] zweiter Eintrag desselben Objekts erhält seq = 2'
);

-- [Spez P-010, Platznummer je Objekt] ein anderes Objekt beginnt wieder bei
-- seq = 1 — die Platznummer läuft je Objekt, nicht installationsweit.
SELECT is(
    pm.append_state_history(
        '00000000-0000-0000-0000-000000000002',
        'state_change',
        '{"de": "Erster Wechsel bei B", "en": "First change on B"}'::jsonb
    ),
    1,
    '[Spez P-010] ein anderes Objekt beginnt wieder bei seq = 1'
);

-- Nicht registriertes Objekt wird abgewiesen.
SELECT throws_ok(
    $$ SELECT pm.append_state_history(
           '00000000-0000-0000-0000-000000000099',
           'state_change',
           '{"de": "x", "en": "y"}'::jsonb
       ) $$,
    '23503',
    NULL,
    'nicht registriertes Objekt wird abgewiesen'
);

-- Ungültige Ereignisart wird abgewiesen.
SELECT throws_ok(
    $$ SELECT pm.append_state_history(
           '00000000-0000-0000-0000-000000000001',
           'made_up_event',
           '{"de": "x", "en": "y"}'::jsonb
       ) $$,
    '23514',
    NULL,
    'ungültige Ereignisart wird abgewiesen'
);

-- text_change ohne change_kind wird abgewiesen.
SELECT throws_ok(
    $$ SELECT pm.append_state_history(
           '00000000-0000-0000-0000-000000000001',
           'text_change',
           '{"de": "x", "en": "y"}'::jsonb
       ) $$,
    '23514',
    NULL,
    'text_change ohne change_kind wird abgewiesen'
);

-- text_change mit gültigem change_kind wird angenommen.
SELECT lives_ok(
    $$ SELECT pm.append_state_history(
           '00000000-0000-0000-0000-000000000001',
           'text_change',
           '{"de": "x", "en": "y"}'::jsonb,
           'editorial'
       ) $$,
    'text_change mit gültigem change_kind wird angenommen'
);

-- Eine andere Ereignisart mit gesetztem change_kind wird abgewiesen.
SELECT throws_ok(
    $$ SELECT pm.append_state_history(
           '00000000-0000-0000-0000-000000000001',
           'state_change',
           '{"de": "x", "en": "y"}'::jsonb,
           'editorial'
       ) $$,
    '23514',
    NULL,
    'change_kind bei einer anderen Ereignisart als text_change wird abgewiesen'
);

-- Ungültiger Grund (reiner Leerraumwert) wird abgewiesen.
SELECT throws_ok(
    $$ SELECT pm.append_state_history(
           '00000000-0000-0000-0000-000000000001',
           'state_change',
           '{"de": "   ", "en": "y"}'::jsonb
       ) $$,
    '23514',
    NULL,
    'ungültiger Grund (reiner Leerraumwert) wird abgewiesen'
);

-- database_actor entspricht session_user.
SELECT is(
    (SELECT database_actor FROM pm.state_history
      WHERE object_id = '00000000-0000-0000-0000-000000000001'
        AND seq = 1),
    session_user::text,
    'database_actor entspricht session_user'
);

-- [Rechte] echter Rollenwechsel statt bloßer Metadatenprüfung: editor kann
-- über die Schreibfunktion einen Eintrag anlegen, aber nicht unmittelbar in
-- pm.state_history schreiben. Der Rollenwechsel geschieht ausschließlich
-- INNERHALB der an pgTAP übergebenen SQL-Zeichenkette (SET LOCAL ROLE), die
-- äußere Sitzung bleibt unter ihrer ursprünglichen Anmelderolle. So brauchen
-- editor/reader kein USAGE auf dem Schema tap, in dem pgTAP hier
-- eingerichtet ist (siehe scripts/test-sql.sh) — nur
-- tap.lives_ok()/tap.throws_ok() selbst laufen unter der prüfenden
-- Sitzungsrolle.
--
-- Bei throws_ok() wird die fehlschlagende Anweisung zurückgerollt; damit
-- wird auch das SET LOCAL ROLE aus dieser Anweisung aufgehoben. Bei
-- lives_ok() erfolgt kein Fehler-Rollback, deshalb wird die Rolle dort
-- ausdrücklich zurückgesetzt, damit sie nicht in die folgenden Testfälle
-- hinein bestehen bleibt.
SELECT tap.lives_ok(
    $$
    SET LOCAL ROLE editor;
    SELECT pm.append_state_history(
        '00000000-0000-0000-0000-000000000001',
        'state_change',
        '{"de": "Durch Editor", "en": "By editor"}'::jsonb
    );
    RESET ROLE;
    $$,
    'editor kann über die Schreibfunktion einen Verlaufseintrag anlegen'
);

SELECT tap.throws_ok(
    $$
    SET LOCAL ROLE editor;
    INSERT INTO pm.state_history (
        object_id, seq, database_actor, event_kind, reason
    )
    VALUES (
        '00000000-0000-0000-0000-000000000001',
        99,
        'editor',
        'state_change',
        '{"de": "Direkt", "en": "Direct"}'::jsonb
    );
    $$,
    '42501',
    NULL,
    'editor kann nicht unmittelbar in pm.state_history schreiben'
);

-- session_user bleibt in jedem Fall die ursprüngliche Anmelderolle (dieser
-- Sitzung), auch während SET LOCAL ROLE editor current_user vorübergehend
-- ändert und pm.append_state_history() intern als schema_owner läuft
-- (SECURITY DEFINER). database_actor zeichnet also die technische
-- Anmelderolle auf, nicht die per SET ROLE aktive Rolle.
SELECT is(
    (SELECT database_actor FROM pm.state_history
      WHERE object_id = '00000000-0000-0000-0000-000000000001'
        AND event_kind = 'state_change'
        AND reason = '{"de": "Durch Editor", "en": "By editor"}'::jsonb),
    session_user::text,
    'database_actor zeichnet die Anmelderolle auf, nicht die per SET ROLE aktive Rolle'
);

SELECT ok(
    has_table_privilege('reader', 'pm.state_history', 'SELECT')
    AND NOT has_table_privilege('reader', 'pm.state_history', 'INSERT')
    AND NOT has_table_privilege('reader', 'pm.state_history', 'UPDATE')
    AND NOT has_table_privilege('reader', 'pm.state_history', 'DELETE'),
    'reader darf pm.state_history nur lesen'
);

SELECT tap.lives_ok(
    $$
    SET LOCAL ROLE reader;
    SELECT count(*) FROM pm.state_history;
    RESET ROLE;
    $$,
    'reader kann den Zustandsverlauf lesen'
);

SELECT tap.throws_ok(
    $$
    SET LOCAL ROLE reader;
    DELETE FROM pm.state_history;
    $$,
    '42501',
    NULL,
    'reader kann den Zustandsverlauf nicht löschen'
);

SELECT tap.throws_ok(
    $$
    SET LOCAL ROLE reader;
    UPDATE pm.state_history SET reason = reason;
    $$,
    '42501',
    NULL,
    'reader kann den Zustandsverlauf nicht ändern'
);

SELECT tap.throws_ok(
    $$
    SET LOCAL ROLE reader;
    INSERT INTO pm.state_history (
        object_id, seq, database_actor, event_kind, reason
    )
    VALUES (
        '00000000-0000-0000-0000-000000000001',
        99,
        session_user,
        'state_change',
        '{"de": "Direkt", "en": "Direct"}'::jsonb
    );
    $$,
    '42501',
    NULL,
    'reader kann keinen Verlaufseintrag anlegen'
);

-- Objekt mit Verlauf kann normal nicht gelöscht werden (ON DELETE RESTRICT).
SELECT throws_ok(
    $$ DELETE FROM pm_test.widgets WHERE id = '00000000-0000-0000-0000-000000000002' $$,
    '23001',
    NULL,
    'Objekt mit Zustandsverlauf kann normal nicht gelöscht werden'
);

SELECT * FROM finish();
ROLLBACK;
