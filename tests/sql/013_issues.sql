BEGIN;
SELECT plan(57);

SELECT has_table('pm', 'issues', 'pm.issues existiert');
SELECT has_table('pm', 'issue_hierarchy_rules', 'pm.issue_hierarchy_rules existiert');

-- pgTAP selbst läuft als postgres. Ein SET ROLE editor um einen
-- lives_ok()/throws_ok()-Aufruf würde auch die pgTAP-Funktion als editor
-- auflösen; editor besitzt jedoch kein USAGE auf dem Schema tap.
-- Diese Hilfsfunktion wechselt deshalb nur für die geprüfte Anweisung
-- die Rolle und stellt sie auch im Fehlerfall wieder her.
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

-- Eigene Testprojekte, unabhängig von der echten Projektkonfiguration aus
-- project/003_projects.sql. test_issue_weighted_project deckt die
-- Umfang-Pflicht ab, test_issue_project_a/b die Projektgleichheit-Tests.
--
-- WICHTIG: Jeder Vorgang, der in diesem Testlauf erfolgreich angelegt wird
-- (also am Ende nicht per throws_ok verworfen ist), erhält unmittelbar
-- danach eine Projektzuordnung. P-002 (pm.enforce_object_project_assignment_
-- required, 009_projects.sql) ist eine verzögerte Prüfung — ohne
-- Zuordnung würde nicht der jeweilige INSERT scheitern, sondern erst das
-- nächste SET CONSTRAINTS ALL IMMEDIATE weiter unten, und zwar wegen eines
-- fachlich falschen, irreführenden Grundes.
INSERT INTO pm.projects (key, title, state, scope_mode) VALUES
    ('test_issue_project_a', '{"de": "Testprojekt A", "en": "Test project A"}'::jsonb, 'active', 'unweighted'),
    ('test_issue_project_b', '{"de": "Testprojekt B", "en": "Test project B"}'::jsonb, 'active', 'unweighted'),
    ('test_issue_weighted_project', '{"de": "Gewichtetes Testprojekt", "en": "Weighted test project"}'::jsonb, 'active', 'weighted');

-- ------------------------------------------------------------------
-- Anfangszustand: current_user = 'editor' darf nur mit state = inbox
-- anlegen (pm.enforce_issue_initial_state). Der Trigger prüft wörtlich
-- current_user = 'editor', nicht "current_user <> 'migrator'" — jede
-- andere ausreichend berechtigte Rolle bleibt uneingeschränkt. Die
-- folgenden "Import"-Fälle laufen deshalb als die ausführende
-- Administrationsrolle dieses Testlaufs (hier effektiv postgres), nicht
-- speziell als migrator; sie prüfen die Triggerbedingung wörtlich.
-- Alle übrigen Pflichtfelder sind hier bereits gültig gesetzt, damit
-- ausschließlich die Anfangszustand-Regel die jeweilige Prüfung auslöst.
-- ------------------------------------------------------------------

-- 3
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        INSERT INTO pm.issues (id, title, description, state)
        VALUES ('00000000-0000-0000-0000-000000000201',
                '{"de": "Testvorgang im Eingang"}'::jsonb,
                '{"de": "Anlass und gewünschtes Ergebnis"}'::jsonb,
                'inbox')
    $sql$) $$,
    'editor kann einen Vorgang im Zustand inbox anlegen'
);

-- 4
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency)
        VALUES ('00000000-0000-0000-0000-000000000291',
                '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
                'ready', 'task', 'low')
    $sql$) $$,
    '23514', NULL,
    'editor kann keinen Vorgang direkt im Zustand ready anlegen'
);

-- 5
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency)
        VALUES ('00000000-0000-0000-0000-000000000292',
                '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
                'in_progress', 'task', 'low')
    $sql$) $$,
    '23514', NULL,
    'editor kann keinen Vorgang direkt im Zustand in_progress anlegen'
);

-- 6
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency, finished_at)
        VALUES ('00000000-0000-0000-0000-000000000293',
                '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
                'done', 'task', 'low', statement_timestamp())
    $sql$) $$,
    '23514', NULL,
    'editor kann keinen Vorgang direkt im Zustand done anlegen'
);

INSERT INTO pm.object_projects (object_id, project_id)
SELECT '00000000-0000-0000-0000-000000000201', id FROM pm.projects WHERE key = 'test_issue_project_a';

-- 7: current_user <> 'editor' darf einen fortgeschrittenen Anfangszustand
-- übernehmen, wenn alle übrigen Pflichten erfüllt sind (z. B. ein
-- kontrollierter Import, §5 Ablauf F).
SELECT lives_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency)
       VALUES ('00000000-0000-0000-0000-000000000210',
               '{"de": "importierter Vorgang", "en": "imported issue"}'::jsonb,
               '{"de": "Anlass", "en": "cause"}'::jsonb,
               'ready', 'task', 'low') $$,
    'current_user <> editor kann direkt im Zustand ready anlegen'
);

INSERT INTO pm.object_projects (object_id, project_id)
SELECT '00000000-0000-0000-0000-000000000210', id FROM pm.projects WHERE key = 'test_issue_project_a';

-- 8: ein solcher Import bleibt an die übrigen Constraints gebunden — hier
-- fehlt finished_at, das done zwingend verlangt.
SELECT throws_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency)
       VALUES ('00000000-0000-0000-0000-000000000211',
               '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
               'done', 'task', 'low') $$,
    '23514', NULL,
    'ein Import im Zustand done ohne finished_at wird trotzdem abgelehnt'
);

-- ------------------------------------------------------------------
-- Sprachkarten: Eingang-Ausnahme sowie blocker_reason/implementation_notes.
-- ------------------------------------------------------------------

-- 9
SELECT throws_ok(
    $$ INSERT INTO pm.issues (id, title, description, state)
       VALUES ('00000000-0000-0000-0000-000000000220',
               '{"fr": "titre"}'::jsonb, '{"de": "gültig"}'::jsonb, 'inbox') $$,
    '23514', NULL,
    'unbekannte Sprache wird auch im Eingang abgelehnt'
);

-- 10
SELECT throws_ok(
    $$ INSERT INTO pm.issues (id, title, description, state)
       VALUES ('00000000-0000-0000-0000-000000000221',
               '{"de": "x"}'::jsonb, '{"de": "gültig"}'::jsonb, 'inbox') $$,
    '23514', NULL,
    'Titel unterhalb der Mindestlänge wird auch im Eingang abgelehnt'
);

-- 11: außerhalb von inbox gilt P-005 vollständig — eine Sprache genügt
-- nicht mehr.
SELECT throws_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency)
       VALUES ('00000000-0000-0000-0000-000000000222',
               '{"de": "nur deutsch"}'::jsonb, '{"de": "nur deutsch", "en": "german only"}'::jsonb,
               'ready', 'task', 'low') $$,
    '23514', NULL,
    'ab bereit ist eine unvollständige Sprachkarte für title unzulässig'
);

-- 12: implementation_notes mit unbekannter Sprache.
SELECT throws_ok(
    $$ UPDATE pm.issues SET implementation_notes = '{"fr": "notes"}'::jsonb
        WHERE id = '00000000-0000-0000-0000-000000000201' $$,
    '23514', NULL,
    'implementation_notes mit unbekannter Sprache wird abgelehnt'
);

-- ------------------------------------------------------------------
-- Abschlusskriterien: Schema und Pflicht ab bereit bei feature/bug.
-- ------------------------------------------------------------------

-- 13: fehlendes Feld.
SELECT throws_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency, criteria)
       VALUES ('00000000-0000-0000-0000-000000000230',
               '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
               'ready', 'feature', 'low',
               '[{"schluessel": "K1", "stand": "open"}]'::jsonb) $$,
    '23514', NULL,
    'Abschlusskriterium ohne text wird abgelehnt'
);

-- 14: unbekanntes Feld.
SELECT throws_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency, criteria)
       VALUES ('00000000-0000-0000-0000-000000000231',
               '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
               'ready', 'feature', 'low',
               '[{"schluessel": "K1", "text": {"de": "Titeltext", "en": "Title text"}, "stand": "open", "extra": 1}]'::jsonb) $$,
    '23514', NULL,
    'Abschlusskriterium mit unbekanntem Feld wird abgelehnt'
);

-- 15: ungültiges Schlüsselformat.
SELECT throws_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency, criteria)
       VALUES ('00000000-0000-0000-0000-000000000232',
               '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
               'ready', 'feature', 'low',
               '[{"schluessel": "K 1!", "text": {"de": "Titeltext", "en": "Title text"}, "stand": "open"}]'::jsonb) $$,
    '23514', NULL,
    'Abschlusskriterium mit ungültigem Schlüsselformat wird abgelehnt'
);

-- 16: nicht getrimmter Schlüssel.
SELECT throws_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency, criteria)
       VALUES ('00000000-0000-0000-0000-000000000233',
               '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
               'ready', 'feature', 'low',
               '[{"schluessel": " K1 ", "text": {"de": "Titeltext", "en": "Title text"}, "stand": "open"}]'::jsonb) $$,
    '23514', NULL,
    'nicht getrimmter Abschlusskriterium-Schlüssel wird abgelehnt'
);

-- 17: doppelter Schlüssel.
SELECT throws_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency, criteria)
       VALUES ('00000000-0000-0000-0000-000000000234',
               '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
               'ready', 'feature', 'low',
               '[{"schluessel": "K1", "text": {"de": "Titeltext", "en": "Title text"}, "stand": "open"},
                 {"schluessel": "K1", "text": {"de": "Zweiter Text", "en": "Second text"}, "stand": "fulfilled"}]'::jsonb) $$,
    '23514', NULL,
    'doppelter Abschlusskriterium-Schlüssel wird abgelehnt'
);

-- 18: ungültiger stand-Wert.
SELECT throws_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency, criteria)
       VALUES ('00000000-0000-0000-0000-000000000235',
               '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
               'ready', 'feature', 'low',
               '[{"schluessel": "K1", "text": {"de": "Titeltext", "en": "Title text"}, "stand": "erledigt"}]'::jsonb) $$,
    '23514', NULL,
    'ungültiger stand-Wert wird abgelehnt'
);

-- 19: unvollständige Sprachkarte im Kriterientext.
SELECT throws_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency, criteria)
       VALUES ('00000000-0000-0000-0000-000000000236',
               '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
               'ready', 'feature', 'low',
               '[{"schluessel": "K1", "text": {"de": "nur deutsch"}, "stand": "open"}]'::jsonb) $$,
    '23514', NULL,
    'unvollständige Sprachkarte im Kriterientext wird abgelehnt'
);

-- 20: feature ab bereit ohne jedes Kriterium wird abgelehnt.
SELECT throws_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency)
       VALUES ('00000000-0000-0000-0000-000000000237',
               '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
               'ready', 'feature', 'low') $$,
    '23514', NULL,
    'feature ab bereit ohne Abschlusskriterium wird abgelehnt'
);

-- 21: task ab bereit braucht dagegen kein Kriterium.
SELECT lives_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency)
       VALUES ('00000000-0000-0000-0000-000000000238',
               '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
               'ready', 'task', 'low') $$,
    'task ab bereit ohne Abschlusskriterium ist zulässig'
);

INSERT INTO pm.object_projects (object_id, project_id)
SELECT '00000000-0000-0000-0000-000000000238', id FROM pm.projects WHERE key = 'test_issue_project_a';

-- 22: vollständig gültiger feature-Vorgang mit einem Kriterium.
SELECT lives_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency, criteria)
       VALUES ('00000000-0000-0000-0000-000000000239',
               '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
               'ready', 'feature', 'low',
               '[{"schluessel": "K1", "text": {"de": "Titeltext", "en": "Title text"}, "stand": "open"}]'::jsonb) $$,
    'feature mit gültigem Abschlusskriterium ab bereit ist zulässig'
);

INSERT INTO pm.object_projects (object_id, project_id)
SELECT '00000000-0000-0000-0000-000000000239', id FROM pm.projects WHERE key = 'test_issue_project_a';

-- ------------------------------------------------------------------
-- ready_threshold_reached: Rückwege löschen nichts (Regel 6). 013 prüft
-- keine Übergangstabelle (die kommt erst mit pm.transition_issue()) — die
-- folgenden direkten state-Änderungen sind deshalb keine Aussage darüber,
-- welche Übergänge später als Fachregel erlaubt sein werden. Sie dienen
-- nur dazu, die dauerhafte Schwelle zu prüfen.
-- ------------------------------------------------------------------

-- 23
SELECT is(
    (SELECT ready_threshold_reached FROM pm.issues
      WHERE id = '00000000-0000-0000-0000-000000000239'),
    true,
    'ready_threshold_reached ist nach Erreichen von bereit wahr'
);

-- 24: 013 verhindert diesen internen Rücksatz nicht (keine Übergangstabelle).
SELECT lives_ok(
    $$ UPDATE pm.issues SET state = 'clarification'
        WHERE id = '00000000-0000-0000-0000-000000000239' $$,
    'interner Rücksatz auf clarification wird von 013 nicht verhindert'
);

-- 25: issue_kind bleibt trotz Rücksatz Pflicht.
SELECT throws_ok(
    $$ UPDATE pm.issues SET issue_kind = NULL
        WHERE id = '00000000-0000-0000-0000-000000000239' $$,
    '23514', NULL,
    'issue_kind bleibt nach einmal erreichter Schwelle Pflicht'
);

-- 26: urgency bleibt trotz Rücksatz Pflicht.
SELECT throws_ok(
    $$ UPDATE pm.issues SET urgency = NULL
        WHERE id = '00000000-0000-0000-0000-000000000239' $$,
    '23514', NULL,
    'urgency bleibt nach einmal erreichter Schwelle Pflicht'
);

-- 27: criteria bleibt trotz Rücksatz Pflicht (feature/bug).
SELECT throws_ok(
    $$ UPDATE pm.issues SET criteria = '[]'::jsonb
        WHERE id = '00000000-0000-0000-0000-000000000239' $$,
    '23514', NULL,
    'Abschlusskriterium bleibt nach einmal erreichter Schwelle Pflicht'
);

-- ------------------------------------------------------------------
-- issue_kind_locked: dauerhaft ab in_progress, nicht nur "aktuell
-- in_progress" (die ursprünglich übersehene Lücke: OLD.state = 'in_progress'
-- allein hätte einen späteren Folgezustand wie in_review nicht erfasst).
-- ------------------------------------------------------------------

INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency)
VALUES ('00000000-0000-0000-0000-000000000240',
        '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
        'ready', 'task', 'low');

INSERT INTO pm.object_projects (object_id, project_id)
SELECT '00000000-0000-0000-0000-000000000240', id FROM pm.projects WHERE key = 'test_issue_project_a';

-- 28
SELECT lives_ok(
    $$ UPDATE pm.issues SET state = 'in_progress'
        WHERE id = '00000000-0000-0000-0000-000000000240' $$,
    'interner Zustandswechsel nach in_progress wird von 013 nicht verhindert'
);

-- 29
SELECT is(
    (SELECT issue_kind_locked FROM pm.issues
      WHERE id = '00000000-0000-0000-0000-000000000240'),
    true,
    'issue_kind_locked ist nach Erreichen von in_progress wahr'
);

-- 30
SELECT throws_ok(
    $$ UPDATE pm.issues SET issue_kind = 'bug'
        WHERE id = '00000000-0000-0000-0000-000000000240' $$,
    '23514', NULL,
    'issue_kind ist unmittelbar nach in_progress unveränderlich'
);

-- 31
SELECT lives_ok(
    $$ UPDATE pm.issues SET state = 'in_review'
        WHERE id = '00000000-0000-0000-0000-000000000240' $$,
    'interner Zustandswechsel nach in_review wird von 013 nicht verhindert'
);

-- 32
SELECT throws_ok(
    $$ UPDATE pm.issues SET issue_kind = 'bug'
        WHERE id = '00000000-0000-0000-0000-000000000240' $$,
    '23514', NULL,
    'issue_kind bleibt auch in einem späteren Folgezustand gesperrt'
);

-- editor besitzt weder ein UPDATE-Recht auf state selbst noch auf
-- issue_kind_locked/ready_threshold_reached.

-- 33: editor darf state nicht direkt ändern (nur SELECT/INSERT, kein UPDATE
-- auf state — siehe GRANTs am Ende der Migration).
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        UPDATE pm.issues SET state = 'clarification'
         WHERE id = '00000000-0000-0000-0000-000000000201'
    $sql$) $$,
    '42501', NULL,
    'editor darf state nicht direkt ändern'
);

-- 34
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        UPDATE pm.issues SET issue_kind_locked = false
         WHERE id = '00000000-0000-0000-0000-000000000240'
    $sql$) $$,
    '42501', NULL,
    'editor darf issue_kind_locked nicht direkt ändern'
);

-- 35
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        UPDATE pm.issues SET ready_threshold_reached = false
         WHERE id = '00000000-0000-0000-0000-000000000240'
    $sql$) $$,
    '42501', NULL,
    'editor darf ready_threshold_reached nicht direkt ändern'
);

-- ------------------------------------------------------------------
-- blocker_reason / finished_at.
-- ------------------------------------------------------------------

INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency)
VALUES ('00000000-0000-0000-0000-000000000250',
        '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
        'ready', 'task', 'low');

INSERT INTO pm.object_projects (object_id, project_id)
SELECT '00000000-0000-0000-0000-000000000250', id FROM pm.projects WHERE key = 'test_issue_project_a';

-- 36
SELECT throws_ok(
    $$ UPDATE pm.issues SET state = 'blocked'
        WHERE id = '00000000-0000-0000-0000-000000000250' $$,
    '23514', NULL,
    'blockiert ohne blocker_reason wird abgelehnt'
);

-- 37: blocker_reason mit unbekannter Sprache.
SELECT throws_ok(
    $$ UPDATE pm.issues
          SET state = 'blocked', blocker_reason = '{"fr": "attend"}'::jsonb
        WHERE id = '00000000-0000-0000-0000-000000000250' $$,
    '23514', NULL,
    'blocker_reason mit unbekannter Sprache wird abgelehnt'
);

-- 38
SELECT lives_ok(
    $$ UPDATE pm.issues
          SET state = 'blocked', blocker_reason = '{"de": "wartet auf Zugriff", "en": "waiting for access"}'::jsonb
        WHERE id = '00000000-0000-0000-0000-000000000250' $$,
    'blockiert mit gültigem blocker_reason ist zulässig'
);

-- 39
SELECT throws_ok(
    $$ UPDATE pm.issues SET state = 'in_progress'
        WHERE id = '00000000-0000-0000-0000-000000000250' $$,
    '23514', NULL,
    'blocker_reason außerhalb von blockiert ist unzulässig'
);

-- 40
SELECT throws_ok(
    $$ UPDATE pm.issues SET state = 'done', blocker_reason = NULL
        WHERE id = '00000000-0000-0000-0000-000000000250' $$,
    '23514', NULL,
    'done ohne finished_at wird abgelehnt'
);

-- 41
SELECT lives_ok(
    $$ UPDATE pm.issues
          SET state = 'done', blocker_reason = NULL, finished_at = statement_timestamp()
        WHERE id = '00000000-0000-0000-0000-000000000250' $$,
    'interner Zustandswechsel nach done mit gesetztem finished_at wird von 013 nicht verhindert'
);

-- ------------------------------------------------------------------
-- Hierarchie (Regel 2, 3, 4).
-- ------------------------------------------------------------------

INSERT INTO pm.issues (id, title, description, state, issue_kind) VALUES
    ('00000000-0000-0000-0000-000000000260', '{"de": "Epos"}'::jsonb, '{"de": "Titeltext"}'::jsonb, 'inbox', 'epic'),
    ('00000000-0000-0000-0000-000000000261', '{"de": "Fehler"}'::jsonb, '{"de": "Titeltext"}'::jsonb, 'inbox', 'bug'),
    ('00000000-0000-0000-0000-000000000262', '{"de": "Epos 2"}'::jsonb, '{"de": "Titeltext"}'::jsonb, 'inbox', 'epic');

INSERT INTO pm.object_projects (object_id, project_id)
SELECT id, (SELECT id FROM pm.projects WHERE key = 'test_issue_project_a')
  FROM pm.issues
 WHERE id IN ('00000000-0000-0000-0000-000000000260',
              '00000000-0000-0000-0000-000000000261',
              '00000000-0000-0000-0000-000000000262');

-- 42: Aufgabe/Funktion unter Epos ist erlaubt.
SELECT lives_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, parent_id)
       VALUES ('00000000-0000-0000-0000-000000000263',
               '{"de": "Untervorgang"}'::jsonb, '{"de": "Titeltext"}'::jsonb, 'inbox', 'task',
               '00000000-0000-0000-0000-000000000260') $$,
    'task unter epic ist erlaubt'
);

INSERT INTO pm.object_projects (object_id, project_id)
SELECT '00000000-0000-0000-0000-000000000263', id FROM pm.projects WHERE key = 'test_issue_project_a';

-- 43: Fehler/Aufgabe/Pflege erlauben laut Regel 2 keine Kinder.
SELECT throws_ok(
    $$ INSERT INTO pm.issues (id, title, description, state, issue_kind, parent_id)
       VALUES ('00000000-0000-0000-0000-000000000264',
               '{"de": "Titeltext"}'::jsonb, '{"de": "Titeltext"}'::jsonb, 'inbox', 'task',
               '00000000-0000-0000-0000-000000000261') $$,
    '23514', NULL,
    'bug erlaubt keinen Untervorgang (Regel 2)'
);

-- 44: epic erscheint in keiner zulässigen Kindart-Liste, kann also selbst
-- keinen Elternvorgang haben.
SELECT throws_ok(
    $$ UPDATE pm.issues SET parent_id = '00000000-0000-0000-0000-000000000260'
        WHERE id = '00000000-0000-0000-0000-000000000262' $$,
    '23514', NULL,
    'epic kann nicht Kind eines anderen Vorgangs sein'
);

-- 45: Zyklus.
SELECT throws_ok(
    $$ UPDATE pm.issues SET parent_id = '00000000-0000-0000-0000-000000000263'
        WHERE id = '00000000-0000-0000-0000-000000000260' $$,
    '23514', NULL,
    'Zyklus in der Vorgangshierarchie wird abgelehnt'
);

-- 46: Eine Änderung der Elternart darf bestehende Kinder nicht nachträglich
-- ungültig machen. bug erlaubt keine Kinder.
SELECT throws_ok(
    $$ UPDATE pm.issues SET issue_kind = 'bug'
        WHERE id = '00000000-0000-0000-0000-000000000260' $$,
    '23514', NULL,
    'Elternart-Wechsel, der bestehende Kinder ungültig macht, wird abgelehnt'
);

-- ------------------------------------------------------------------
-- Projektgleichheit Eltern-/Kindvorgang (Regel 4), verzögerte Prüfung.
-- Jeder Block ist in sich geschlossen (eigene SET CONSTRAINTS DEFERRED ...
-- IMMEDIATE), damit ein vorheriger erfolgreicher Block den Modus nicht für
-- die folgenden Blöcke auf IMMEDIATE stehen lässt (wie in 009_projects.sql).
-- ------------------------------------------------------------------

-- 47: Kindvorgang wird nachträglich in ein anderes Projekt umgehängt.
SELECT throws_ok(
    $$
    SET CONSTRAINTS ALL DEFERRED;
    UPDATE pm.object_projects
       SET project_id = (SELECT id FROM pm.projects WHERE key = 'test_issue_project_b')
     WHERE object_id = '00000000-0000-0000-0000-000000000263';
    SET CONSTRAINTS ALL IMMEDIATE;
    $$,
    '23514', NULL,
    'Umhängen des Kindvorgangs in ein anderes Projekt wird abgelehnt'
);

-- 48: derselbe Fall aus Sicht des Elternvorgangs — der Elternvorgang wird
-- umgehängt, während sein Kind im ursprünglichen Projekt bleibt.
SELECT throws_ok(
    $$
    SET CONSTRAINTS ALL DEFERRED;
    UPDATE pm.object_projects
       SET project_id = (SELECT id FROM pm.projects WHERE key = 'test_issue_project_b')
     WHERE object_id = '00000000-0000-0000-0000-000000000260';
    SET CONSTRAINTS ALL IMMEDIATE;
    $$,
    '23514', NULL,
    'Umhängen des Elternvorgangs, das ein Kind zurücklässt, wird abgelehnt'
);

-- 49: Neuer Kindvorgang und Projektzuordnung werden in derselben
-- Transaktion angelegt. Ein vom Elternvorgang abweichendes Projekt
-- muss bei der verzögerten Prüfung abgelehnt werden.
SELECT throws_ok(
    $$
    SET CONSTRAINTS ALL DEFERRED;
    INSERT INTO pm.issues (id, title, description, state, issue_kind, parent_id)
    VALUES ('00000000-0000-0000-0000-000000000265',
            '{"de": "Titeltext"}'::jsonb, '{"de": "Titeltext"}'::jsonb, 'inbox', 'task',
            '00000000-0000-0000-0000-000000000260');
    INSERT INTO pm.object_projects (object_id, project_id)
    SELECT '00000000-0000-0000-0000-000000000265', id
      FROM pm.projects WHERE key = 'test_issue_project_b';
    SET CONSTRAINTS ALL IMMEDIATE;
    $$,
    '23514', NULL,
    'neuer Kindvorgang in einem anderen Projekt als der Elternvorgang wird abgelehnt'
);

-- ------------------------------------------------------------------
-- Umfang-Pflicht ab bereit bei scope_mode = weighted (verzögert).
-- ------------------------------------------------------------------

-- 50: ready in einem weighted-Projekt ohne scope wird bei der verzögerten
-- Prüfung abgewiesen.
SELECT throws_ok(
    $$
    SET CONSTRAINTS ALL DEFERRED;
    INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency)
    VALUES ('00000000-0000-0000-0000-000000000270',
            '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
            'ready', 'task', 'low');
    INSERT INTO pm.object_projects (object_id, project_id)
    SELECT '00000000-0000-0000-0000-000000000270', id
      FROM pm.projects WHERE key = 'test_issue_weighted_project';
    SET CONSTRAINTS ALL IMMEDIATE;
    $$,
    '23514', NULL,
    'ready ohne scope in einem weighted-Projekt wird abgelehnt'
);

-- 51: mit gesetztem scope besteht dieselbe Prüfung; anschließend zeigt der
-- Rücksatz nach clarification mit nachfolgendem Löschen des scope, dass die
-- einmal erreichte Schwelle die Pflicht weiterträgt ("Rückwege löschen
-- nichts") statt nur "noch in ready" zu prüfen.
SELECT lives_ok(
    $$
    SET CONSTRAINTS ALL DEFERRED;
    INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency, scope)
    VALUES ('00000000-0000-0000-0000-000000000271',
            '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
            'ready', 'task', 'low', 'medium');
    INSERT INTO pm.object_projects (object_id, project_id)
    SELECT '00000000-0000-0000-0000-000000000271', id
      FROM pm.projects WHERE key = 'test_issue_weighted_project';
    SET CONSTRAINTS ALL IMMEDIATE;
    SET CONSTRAINTS ALL DEFERRED;
    $$,
    'ready mit scope in einem weighted-Projekt ist zulässig'
);

-- 52: Der Wechsel eines Projekts von unweighted auf weighted muss
-- bestehende Vorgänge ab der ready-Schwelle erneut prüfen.
SELECT throws_ok(
    $$
    SET CONSTRAINTS ALL DEFERRED;
    INSERT INTO pm.issues (id, title, description, state, issue_kind, urgency)
    VALUES ('00000000-0000-0000-0000-000000000272',
            '{"de": "Titeltext", "en": "Title text"}'::jsonb, '{"de": "Titeltext", "en": "Title text"}'::jsonb,
            'ready', 'task', 'low');
    INSERT INTO pm.object_projects (object_id, project_id)
    SELECT '00000000-0000-0000-0000-000000000272', id
      FROM pm.projects WHERE key = 'test_issue_project_a';
    UPDATE pm.projects SET scope_mode = 'weighted' WHERE key = 'test_issue_project_a';
    SET CONSTRAINTS ALL IMMEDIATE;
    $$,
    '23514', NULL,
    'ein nachträglicher Wechsel auf scope_mode = weighted macht bestehende Vorgänge ohne scope ungültig'
);

UPDATE pm.issues SET state = 'clarification'
 WHERE id = '00000000-0000-0000-0000-000000000271';

-- 53
SELECT throws_ok(
    $$
    SET CONSTRAINTS ALL DEFERRED;
    UPDATE pm.issues SET scope = NULL
     WHERE id = '00000000-0000-0000-0000-000000000271';
    SET CONSTRAINTS ALL IMMEDIATE;
    $$,
    '23514', NULL,
    'scope bleibt nach Rücksatz auf clarification Pflicht (Schwelle einmal erreicht, weighted-Projekt)'
);

-- ------------------------------------------------------------------
-- depends_on: issue -> issue (§8.2), inklusive Zyklenprüfung.
-- ------------------------------------------------------------------

INSERT INTO pm.issues (id, title, description, state, issue_kind) VALUES
    ('00000000-0000-0000-0000-000000000280', '{"de": "Titeltext"}'::jsonb, '{"de": "Titeltext"}'::jsonb, 'inbox', 'task'),
    ('00000000-0000-0000-0000-000000000281', '{"de": "Titeltext"}'::jsonb, '{"de": "Titeltext"}'::jsonb, 'inbox', 'task');

INSERT INTO pm.object_projects (object_id, project_id)
SELECT id, (SELECT id FROM pm.projects WHERE key = 'test_issue_project_a')
  FROM pm.issues WHERE id IN ('00000000-0000-0000-0000-000000000280', '00000000-0000-0000-0000-000000000281');

-- 54
SELECT lives_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       VALUES ('00000000-0000-0000-0000-000000000281',
               '00000000-0000-0000-0000-000000000280', 'depends_on') $$,
    'depends_on issue -> issue ist erlaubt'
);

-- 55: Gegenrichtung würde einen Zyklus schließen.
SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (source_id, target_id, relation_type)
       VALUES ('00000000-0000-0000-0000-000000000280',
               '00000000-0000-0000-0000-000000000281', 'depends_on') $$,
    '23514', NULL,
    'depends_on in Gegenrichtung, die einen Zyklus schließt, wird abgelehnt'
);

-- 56-57: Mehrgliedriger depends_on-Zyklus zwischen Vorgängen.
-- Migration 007 prüft die generische Zyklenlogik; dieser Fall weist nach,
-- dass sie auch für den in Migration 013 ergänzten Endpunkt
-- depends_on: issue -> issue gilt. Bestehende Kante: 281 -> 280.
INSERT INTO pm.issues (
    id,
    title,
    description,
    state,
    issue_kind
) VALUES (
    '00000000-0000-0000-0000-000000000282',
    '{"de": "Titeltext"}'::jsonb,
    '{"de": "Titeltext"}'::jsonb,
    'inbox',
    'task'
);

INSERT INTO pm.object_projects (object_id, project_id)
VALUES (
    '00000000-0000-0000-0000-000000000282',
    (SELECT id
       FROM pm.projects
      WHERE key = 'test_issue_project_a')
);

-- 56
SELECT lives_ok(
    $$ INSERT INTO pm.object_relations (
           source_id,
           target_id,
           relation_type
       ) VALUES (
           '00000000-0000-0000-0000-000000000280',
           '00000000-0000-0000-0000-000000000282',
           'depends_on'
       ) $$,
    'depends_on-Kante 280 -> 282 erweitert die Kette 281 -> 280 -> 282'
);

-- 57
SELECT throws_ok(
    $$ INSERT INTO pm.object_relations (
           source_id,
           target_id,
           relation_type
       ) VALUES (
           '00000000-0000-0000-0000-000000000282',
           '00000000-0000-0000-0000-000000000281',
           'depends_on'
       ) $$,
    '23514',
    NULL,
    'depends_on-Zyklus 281 -> 280 -> 282 -> 281 wird abgelehnt'
);

SELECT * FROM finish();
ROLLBACK;
