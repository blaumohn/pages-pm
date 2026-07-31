BEGIN;
SELECT plan(38);

SELECT has_table('pm', 'issue_state_transitions', 'pm.issue_state_transitions existiert');
SELECT has_function(
    'pm', 'transition_issue',
    ARRAY['uuid', 'text', 'jsonb', 'jsonb', 'jsonb'],
    'pm.transition_issue() existiert'
);

-- Wie in tests/sql/013_issues.sql: pgTAP läuft als postgres, editor besitzt
-- kein USAGE auf dem Schema tap. Diese Hilfsfunktion wechselt deshalb nur
-- für die geprüfte Anweisung die Rolle.
CREATE FUNCTION pg_temp.as_editor(p_sql text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    SET ROLE editor;
    BEGIN
        EXECUTE p_sql;
    EXCEPTION
        WHEN OTHERS THEN
            RESET ROLE;
            RAISE;
    END;
    RESET ROLE;
END;
$$;

INSERT INTO pm.projects (key, title, state, scope_mode) VALUES
    ('test_transition_project_a', '{"de": "Übergangsprojekt A", "en": "Transition project A"}'::jsonb, 'active', 'unweighted'),
    ('test_transition_project_b', '{"de": "Übergangsprojekt B", "en": "Transition project B"}'::jsonb, 'active', 'unweighted');

-- Die Vorgänge werden hier unmittelbar in ihrem Ausgangszustand angelegt.
-- Das ist zulässig, weil pm.enforce_issue_initial_state() wörtlich
-- current_user = 'editor' prüft und dieser Testlauf als postgres läuft
-- (§5, Ablauf F: kontrollierter Import). Der jeweils GEPRÜFTE Zustandswechsel
-- läuft anschließend ausschließlich über pm.transition_issue().
INSERT INTO pm.issues (
    id, title, description, state, issue_kind, urgency, criteria, parent_id, finished_at
) VALUES
    -- gewöhnlicher Übergang, verbotener Übergang
    ('00000000-0000-0000-0000-000000000301',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'inbox', 'task', NULL, '[]'::jsonb, NULL, NULL),

    -- endgültiger Zustand
    ('00000000-0000-0000-0000-000000000302',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'done', 'task', 'low', '[]'::jsonb, NULL, statement_timestamp()),

    -- Epos: folgt der gewöhnlichen Übergangstabelle (§7.6, Regel 5)
    ('00000000-0000-0000-0000-000000000303',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'ready', 'epic', 'low', '[]'::jsonb, NULL, NULL),

    -- Übergehungsgrund ohne offene Abhängigkeit
    ('00000000-0000-0000-0000-000000000304',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'ready', 'task', 'low', '[]'::jsonb, NULL, NULL),

    -- depends_on innerhalb eines Projekts: 310 hängt von dem offenen 311 ab
    ('00000000-0000-0000-0000-000000000310',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'ready', 'task', 'low', '[]'::jsonb, NULL, NULL),
    ('00000000-0000-0000-0000-000000000311',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'inbox', 'task', NULL, '[]'::jsonb, NULL, NULL),

    -- depends_on über Projektgrenzen hinweg: 312 (Projekt A) -> 313 (Projekt B)
    ('00000000-0000-0000-0000-000000000312',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'ready', 'task', 'low', '[]'::jsonb, NULL, NULL),
    ('00000000-0000-0000-0000-000000000313',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'inbox', 'task', NULL, '[]'::jsonb, NULL, NULL),

    -- unerfülltes Abschlusskriterium
    ('00000000-0000-0000-0000-000000000320',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'in_review', 'bug', 'low',
     '[{"schluessel": "K1", "text": {"de": "Kriterium", "en": "Criterion"}, "stand": "open"}]'::jsonb,
     NULL, NULL),

    -- offenes Kind (321 ist Elternvorgang von 322)
    ('00000000-0000-0000-0000-000000000321',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'in_review', 'feature', 'low',
     '[{"schluessel": "K1", "text": {"de": "Kriterium", "en": "Criterion"}, "stand": "fulfilled"}]'::jsonb,
     NULL, NULL),
    ('00000000-0000-0000-0000-000000000322',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'inbox', 'task', NULL, '[]'::jsonb, '00000000-0000-0000-0000-000000000321', NULL),

    -- Epos MIT Kind: der erlaubte Abschlussweg (333 ist Kind von 332)
    ('00000000-0000-0000-0000-000000000332',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'in_review', 'epic', 'low', '[]'::jsonb, NULL, NULL),
    ('00000000-0000-0000-0000-000000000333',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'inbox', 'task', NULL, '[]'::jsonb, '00000000-0000-0000-0000-000000000332', NULL),

    -- Epos ohne Kinder gegenüber gewöhnlichem Vorgang ohne Kinder
    ('00000000-0000-0000-0000-000000000330',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'in_review', 'epic', 'low', '[]'::jsonb, NULL, NULL),
    ('00000000-0000-0000-0000-000000000331',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'in_review', 'task', 'low', '[]'::jsonb, NULL, NULL),

    -- Blockade
    ('00000000-0000-0000-0000-000000000340',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'in_progress', 'task', 'low', '[]'::jsonb, NULL, NULL),

    -- künstlicher Verlaufsfehler
    ('00000000-0000-0000-0000-000000000350',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'inbox', 'task', NULL, '[]'::jsonb, NULL, NULL),

    -- Rechte
    ('00000000-0000-0000-0000-000000000360',
     '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
     'inbox', 'task', NULL, '[]'::jsonb, NULL, NULL);

INSERT INTO pm.object_projects (object_id, project_id)
SELECT id, (SELECT id FROM pm.projects WHERE key = 'test_transition_project_a')
  FROM pm.issues
 WHERE id::text LIKE '00000000-0000-0000-0000-0000000003%'
   AND id <> '00000000-0000-0000-0000-000000000313';

INSERT INTO pm.object_projects (object_id, project_id)
VALUES ('00000000-0000-0000-0000-000000000313',
        (SELECT id FROM pm.projects WHERE key = 'test_transition_project_b'));

INSERT INTO pm.object_relations (source_id, target_id, relation_type) VALUES
    ('00000000-0000-0000-0000-000000000310',
     '00000000-0000-0000-0000-000000000311', 'depends_on'),
    ('00000000-0000-0000-0000-000000000312',
     '00000000-0000-0000-0000-000000000313', 'depends_on');

-- ------------------------------------------------------------------
-- Übergangstabelle (§7.6, "Zustände und Übergänge").
-- ------------------------------------------------------------------

-- 3
SELECT lives_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000301',
           'clarification',
           '{"de": "Wird beurteilt", "en": "Under assessment"}'::jsonb) $$,
    'erlaubter Übergang inbox -> clarification'
);

-- 4
SELECT is(
    (SELECT state FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000301'),
    'clarification',
    'der Zustand ist nach dem Übergang fortgeschrieben'
);

-- 5
SELECT is(
    (SELECT count(*) FROM pm.state_history
      WHERE object_id = '00000000-0000-0000-0000-000000000301'
        AND event_kind = 'state_change'),
    1::bigint,
    'der Übergang hat genau einen state_change-Eintrag erzeugt'
);

-- 6: clarification -> in_progress steht nicht in der Übergangstabelle.
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000301',
           'in_progress',
           '{"de": "Grund", "en": "Reason"}'::jsonb) $$,
    '23514', NULL,
    'ein in der Übergangstabelle nicht vorgesehener Übergang wird abgewiesen'
);

-- 7: done hat keinen Rückweg.
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000302',
           'in_progress',
           '{"de": "Grund", "en": "Reason"}'::jsonb) $$,
    '23514', NULL,
    'ein endgültiger Zustand kann nicht wieder verlassen werden'
);

-- 8: unbekannter Zielzustand fällt unter dieselbe Prüfung.
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000301',
           'erledigt',
           '{"de": "Grund", "en": "Reason"}'::jsonb) $$,
    '23514', NULL,
    'ein unbekannter Zielzustand wird abgewiesen'
);

-- 9
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '99999999-9999-9999-9999-999999999999',
           'clarification',
           '{"de": "Grund", "en": "Reason"}'::jsonb) $$,
    '23503', NULL,
    'ein nicht vorhandener Vorgang wird abgewiesen'
);

-- ------------------------------------------------------------------
-- Epos: keine Zustandssperre (§7.6, Regel 5; Beispiel §9.3).
-- ------------------------------------------------------------------

-- 10
SELECT lives_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000303',
           'in_progress',
           '{"de": "Kinder werden bearbeitet", "en": "Children in progress"}'::jsonb) $$,
    'ein Epos darf nach in_progress wechseln'
);

-- ------------------------------------------------------------------
-- Abhängigkeitsschranke und begründete Übergehung (§7.6, Regel 12).
-- ------------------------------------------------------------------

-- 11
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000310',
           'in_progress',
           '{"de": "Grund", "en": "Reason"}'::jsonb) $$,
    '23514', NULL,
    'in_progress wird bei offener depends_on-Abhängigkeit abgewiesen'
);

-- 12
SELECT lives_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000310',
           'in_progress',
           '{"de": "Beginnt trotzdem", "en": "Starting anyway"}'::jsonb,
           NULL,
           '{"de": "Vorgänger blockiert uns nicht", "en": "Predecessor does not block us"}'::jsonb) $$,
    'in_progress ist mit Übergehungsgrund trotz offener Abhängigkeit erlaubt'
);

-- 13
SELECT results_eq(
    $$ SELECT event_kind FROM pm.state_history
        WHERE object_id = '00000000-0000-0000-0000-000000000310'
        ORDER BY seq $$,
    $$ VALUES ('state_change'), ('override') $$,
    'die Übergehung erzeugt einen eigenen override-Eintrag neben dem state_change'
);

-- 14: der Beginn wird beim ersten Erreichen von in_progress gesetzt.
SELECT isnt(
    (SELECT started_at FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000310'),
    NULL,
    'started_at ist nach dem ersten Wechsel nach in_progress gesetzt'
);

-- 15: depends_on kennt keine Projektschranke — die Abhängigkeit wirkt
-- projektübergreifend genauso.
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000312',
           'in_progress',
           '{"de": "Grund", "en": "Reason"}'::jsonb) $$,
    '23514', NULL,
    'eine offene projektübergreifende Abhängigkeit hält die Schranke ebenfalls'
);

-- 16
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000304',
           'in_progress',
           '{"de": "Grund", "en": "Reason"}'::jsonb,
           NULL,
           '{"de": "Übergehung", "en": "Override"}'::jsonb) $$,
    '23514', NULL,
    'ein Übergehungsgrund ohne offene Abhängigkeit wird abgewiesen'
);

-- ------------------------------------------------------------------
-- Abschluss (§7.6, Regel 1) und Epos-Abschluss (Regel 5).
-- ------------------------------------------------------------------

-- 17
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000320',
           'done',
           '{"de": "Grund", "en": "Reason"}'::jsonb) $$,
    '23514', NULL,
    'done wird bei einem nicht erfüllten Abschlusskriterium abgewiesen'
);

-- 18
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000321',
           'done',
           '{"de": "Grund", "en": "Reason"}'::jsonb) $$,
    '23514', NULL,
    'done wird bei einem offenen Kindvorgang abgewiesen'
);

-- 19: das Kind wird verworfen — discarded zählt wie done als geschlossen.
SELECT lives_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000322',
           'discarded',
           '{"de": "Wird nicht ausgeführt", "en": "Will not be done"}'::jsonb) $$,
    'der Kindvorgang kann verworfen werden'
);

-- 20
SELECT lives_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000321',
           'done',
           '{"de": "Alle Kinder geschlossen", "en": "All children closed"}'::jsonb) $$,
    'done ist erlaubt, wenn nur noch done/discarded-Kinder bestehen'
);

-- 21
SELECT isnt(
    (SELECT finished_at FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000321'),
    NULL,
    'finished_at wird beim Abschluss automatisch gesetzt'
);

-- 22
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000330',
           'done',
           '{"de": "Grund", "en": "Reason"}'::jsonb) $$,
    '23514', NULL,
    'ein Epos ohne Kindvorgang kann nicht abgeschlossen werden'
);

-- 23–24: Positive Gegenprobe zum kinderlosen Epos — das Epos 332 besitzt
-- ein zunächst offenes Kind. Nach dessen Verwerfung darf das Epos
-- abgeschlossen werden.
SELECT lives_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000333',
           'discarded',
           '{"de": "Wird nicht ausgeführt", "en": "Will not be done"}'::jsonb) $$,
    'das Kind des Epos kann geschlossen werden'
);

-- 24
SELECT lives_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000332',
           'done',
           '{"de": "Zerlegung abgeschlossen", "en": "Breakdown complete"}'::jsonb) $$,
    'ein Epos mit mindestens einem geschlossenen Kind kann abgeschlossen werden'
);

-- 25: die Epos-Regel gilt nur für das Epos; ein gewöhnlicher Vorgang ohne
-- Kinder bleibt nach seiner eigenen Art und seinen Kriterien behandelbar.
SELECT lives_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000331',
           'done',
           '{"de": "Fertig", "en": "Finished"}'::jsonb) $$,
    'ein gewöhnlicher Vorgang ohne Kinder kann abgeschlossen werden'
);

-- ------------------------------------------------------------------
-- Blockade (§7.6, Regel 6): der Blockadegrund gehört zum Übergang.
-- ------------------------------------------------------------------

-- 26
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000340',
           'blocked',
           '{"de": "Grund", "en": "Reason"}'::jsonb) $$,
    '23514', NULL,
    'blocked ohne Blockadegrund wird abgewiesen'
);

-- 27
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000340',
           'in_review',
           '{"de": "Grund", "en": "Reason"}'::jsonb,
           '{"de": "Blockadegrund", "en": "Blocker reason"}'::jsonb) $$,
    '23514', NULL,
    'ein Blockadegrund außerhalb des Wechsels nach blocked wird abgewiesen'
);

-- 28
SELECT lives_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000340',
           'blocked',
           '{"de": "Wartet auf Zugang", "en": "Waiting for access"}'::jsonb,
           '{"de": "Zugang fehlt", "en": "Access missing"}'::jsonb) $$,
    'blocked mit Blockadegrund ist erlaubt'
);

-- 29: Nachschärfung des Blockadegrunds während derselben Blockade — kein
-- Zustandswechsel, deshalb ausdrücklich weiterhin ein gewöhnliches UPDATE.
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        UPDATE pm.issues
           SET blocker_reason = '{"de": "Zugang erteilt, wartet auf Freigabe", "en": "Access granted, awaiting approval"}'::jsonb
         WHERE id = '00000000-0000-0000-0000-000000000340'
    $sql$) $$,
    'editor kann den Blockadegrund während derselben Blockade nachschärfen'
);

-- 30
SELECT lives_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000340',
           'in_progress',
           '{"de": "Zugang da", "en": "Access available"}'::jsonb) $$,
    'blocked kann wieder verlassen werden'
);

-- 31
SELECT is(
    (SELECT blocker_reason FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000340'),
    NULL,
    'der Blockadegrund wird beim Verlassen von blocked zurückgesetzt'
);

-- ------------------------------------------------------------------
-- Die dauerhaften Pflichtschwellen aus Migration 013 greifen auch über den
-- neuen fachlichen Übergangsweg: pm.transition_issue() ersetzt die Trigger
-- nicht, sondern löst sie durch ihr UPDATE aus. 301 steht in clarification
-- und trägt noch keine Dringlichkeit; clarification -> ready ist laut
-- Übergangstabelle erlaubt, scheitert hier also ausschließlich an der
-- Pflichtschwelle.
-- ------------------------------------------------------------------

-- 32
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000301',
           'ready',
           '{"de": "Grund", "en": "Reason"}'::jsonb) $$,
    '23514', NULL,
    'die Pflichtschwelle ab bereit greift auch über pm.transition_issue()'
);

-- ------------------------------------------------------------------
-- Atomarität von Zustand und Verlauf (P-010). Der Grund wird erst vom
-- Trigger auf pm.state_history geprüft, also nach dem UPDATE auf
-- pm.issues — ein unvollständiger Grund ist damit der künstliche
-- Verlaufsfehler, den §2 des Zustandsdokuments verlangt.
-- ------------------------------------------------------------------

-- 33
SELECT throws_ok(
    $$ SELECT pm.transition_issue(
           '00000000-0000-0000-0000-000000000350',
           'clarification',
           '{"de": "Nur deutsch"}'::jsonb) $$,
    '23514', NULL,
    'ein Zustandswechsel mit unvollständigem Grund scheitert am Verlaufseintrag'
);

-- 34
SELECT is(
    (SELECT state FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000350'),
    'inbox',
    'der Zustand ist nach dem gescheiterten Verlaufseintrag unverändert'
);

-- 35
SELECT is(
    (SELECT count(*) FROM pm.state_history
      WHERE object_id = '00000000-0000-0000-0000-000000000350'),
    0::bigint,
    'der Verlauf ist nach dem gescheiterten Verlaufseintrag unverändert'
);

-- ------------------------------------------------------------------
-- Rechte: pm.transition_issue() ist der einzige Schreibweg auf state.
-- ------------------------------------------------------------------

-- 36
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000360',
            'clarification',
            '{"de": "Durch Editor", "en": "By editor"}'::jsonb)
    $sql$) $$,
    'editor kann pm.transition_issue() ausführen'
);

-- 37
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        UPDATE pm.issues SET state = 'ready'
         WHERE id = '00000000-0000-0000-0000-000000000360'
    $sql$) $$,
    '42501', NULL,
    'editor kann state weiterhin nicht unmittelbar ändern'
);

-- 38
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        UPDATE pm.issues
           SET finished_at = statement_timestamp()
         WHERE id = '00000000-0000-0000-0000-000000000360'
    $sql$) $$,
    '42501', NULL,
    'editor kann finished_at nicht unmittelbar ändern'
);

SELECT * FROM finish();
ROLLBACK;
