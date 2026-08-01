BEGIN;
SELECT plan(58);

-- Benannte Vorgangslebensläufe: die ausführbare Form der fachlichen Beispiele
-- aus §7.6 und §11, nicht die Prüfung einer einzelnen Regel. Die Einzelregeln
-- liegen weiterhin in tests/sql/013_issues.sql und
-- tests/sql/014_issue_transitions.sql; hier läuft jeder Vorgang seinen ganzen
-- Weg. Nach den maßgeblichen Schritten werden Zustand, Pflichtmerkmale und
-- Verlauf geprüft; am Ende jedes Lebenslaufs wird der vollständige Verlauf
-- verglichen.
--
-- Übergreifender Lebenslauftest; keiner einzelnen Migration zugeordnet.
--
-- OFFEN: Lebenslauf 2 ist noch nicht fachlich abgeschlossen. Der Betriebsfall
-- "ein bereits als bereit geltender Vorgang wird wieder ungeklärt" hat in der
-- Übergangstabelle (§7.6) derzeit keinen Weg. Insbesondere fehlen
-- bereit -> in Klärung und eingeplant -> in Klärung.
-- L2 weist deshalb vorerst nur die dauerhafte Pflichtschwelle über die
-- tatsächlich vorhandenen Wege nach. Ob diese Rückwege ergänzt werden,
-- entscheidet der noch ausstehende Quellenvergleich; bis dahin bleibt der
-- Betriebsfall ungeprüft, nicht ersetzt.
--
-- Jeder Schreibschritt läuft als editor. Das ist der Unterschied zu
-- tests/sql/014_issue_transitions.sql, das seine Ausgangszustände als postgres
-- setzt (§5, Ablauf F): hier soll gerade nachgewiesen werden, dass der
-- gewöhnliche Betriebsweg vollständig gangbar ist — Anlage im Eingang,
-- Pflichtfelder über gewöhnliche UPDATEs, Zustand ausschließlich über
-- pm.transition_issue().

-- Wie in tests/sql/013_issues.sql und tests/sql/014_issue_transitions.sql:
-- pgTAP läuft als postgres, editor besitzt kein USAGE auf dem Schema tap.
-- Diese Hilfsfunktion wechselt deshalb nur für die geprüfte Anweisung die
-- Rolle.
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

-- Eigene Hilfsfunktion für Anlageblöcke: Vorgang und Projektzuordnung
-- entstehen vor der verzögerten P-002-Prüfung (009_projects.sql).
-- Nach der vollständigen Anlage wird die Prüfung bewusst ausgelöst.
-- Anschließend wird wieder auf DEFERRED gestellt, da
-- SET CONSTRAINTS ALL IMMEDIATE sonst für die restliche Testtransaktion gilt
-- und die nächste Vorgangsanlage vor ihrer Projektzuordnung scheitert.
--
-- pg_temp.as_editor() bleibt davon unberührt: Es dient gewöhnlichen
-- Änderungen und verändert den Constraint-Modus nicht.
CREATE FUNCTION pg_temp.create_as_editor(p_sql text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    SET CONSTRAINTS ALL DEFERRED;
    PERFORM pg_temp.as_editor(p_sql);
    SET CONSTRAINTS ALL IMMEDIATE;
    SET CONSTRAINTS ALL DEFERRED;
END;
$$;

INSERT INTO pm.projects (key, title, state, scope_mode) VALUES (
    'test_lifecycle_project',
    '{"de": "Lebenslaufprojekt", "en": "Lifecycle project"}'::jsonb,
    'active',
    'unweighted'
);

-- ==================================================================
-- Lebenslauf 1 — einfache Aufgabe
--
--     Eingang -> in Klärung -> bereit -> in Arbeit -> in Prüfung
--             -> abgeschlossen
--
-- Der vollständige gewöhnliche Weg einer Aufgabe ohne Abhängigkeit, ohne
-- Kinder und ohne Blockade.
-- ==================================================================

-- 1
SELECT lives_ok(
    $$
    SELECT pg_temp.create_as_editor($sql$
        INSERT INTO pm.issues (
            id,
            title,
            description,
            state,
            issue_kind
        ) VALUES (
            '00000000-0000-0000-0000-000000000401',
            '{"de": "Fallback-Kette umsetzen", "en": "Implement fallback chain"}'::jsonb,
            '{"de": "Anlass und gewünschtes Ergebnis", "en": "Reason and desired outcome"}'::jsonb,
            'inbox',
            'task'
        );
        INSERT INTO pm.object_projects (object_id, project_id)
        VALUES (
            '00000000-0000-0000-0000-000000000401',
            (SELECT id
               FROM pm.projects
              WHERE key = 'test_lifecycle_project')
        );
    $sql$);
    $$,
    'L1: editor legt die Aufgabe im Eingang an und ordnet sie einem Projekt zu'
);

-- 2
SELECT is(
    (SELECT state FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000401'),
    'inbox',
    'L1: ein von editor angelegter Vorgang beginnt im Eingang'
);

-- 3: Die Anlage ist kein Zustandswechsel (P-010).
SELECT is(
    (SELECT count(*) FROM pm.state_history
      WHERE object_id = '00000000-0000-0000-0000-000000000401'),
    0::bigint,
    'L1: die Anlage selbst erzeugt keinen Verlaufseintrag'
);

-- 4: gemeinsames Mindestraster (§7.3, §7.4).
SELECT isnt(
    (SELECT value FROM pm.short_ids
      WHERE object_id = '00000000-0000-0000-0000-000000000401'),
    NULL,
    'L1: die Anlage vergibt eine Kurzkennung'
);

-- 5
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000401',
            'clarification',
            '{"de": "Wird beurteilt", "en": "Under assessment"}'::jsonb)
    $sql$) $$,
    'L1: Eingang -> in Klärung'
);

-- 6
SELECT is(
    (SELECT state FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000401'),
    'clarification',
    'L1: der Vorgang steht in in Klärung'
);

-- 7: Die Pflichtschwelle "ab bereit" (§7.1.1) wirkt über den Übergangsweg.
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000401',
            'ready',
            '{"de": "Beurteilt", "en": "Assessed"}'::jsonb)
    $sql$) $$,
    '23514',
    NULL,
    'L1: bereit wird ohne Dringlichkeit abgewiesen'
);

-- 8
SELECT is(
    (SELECT count(*) FROM pm.state_history
      WHERE object_id = '00000000-0000-0000-0000-000000000401'),
    1::bigint,
    'L1: der abgewiesene Übergang hat keinen Verlaufseintrag erzeugt'
);

-- 9
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        UPDATE pm.issues SET urgency = 'medium'
         WHERE id = '00000000-0000-0000-0000-000000000401'
    $sql$) $$,
    'L1: editor ergänzt die Dringlichkeit in in Klärung'
);

-- 10
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000401',
            'ready',
            '{"de": "Beurteilt und bereit", "en": "Assessed and ready"}'::jsonb)
    $sql$) $$,
    'L1: in Klärung -> bereit'
);

-- 11
SELECT ok(
    (SELECT ready_threshold_reached FROM pm.issues
      WHERE id = '00000000-0000-0000-0000-000000000401'),
    'L1: die Schwelle ab bereit ist erreicht'
);

-- 12
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000401',
            'in_progress',
            '{"de": "Arbeit begonnen", "en": "Work started"}'::jsonb)
    $sql$) $$,
    'L1: bereit -> in Arbeit'
);

-- 13
SELECT isnt(
    (SELECT started_at FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000401'),
    NULL,
    'L1: der Beginn ist gesetzt'
);

-- 14
SELECT ok(
    (SELECT issue_kind_locked FROM pm.issues
      WHERE id = '00000000-0000-0000-0000-000000000401'),
    'L1: die Vorgangsart ist ab in Arbeit gesperrt'
);

-- 15
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000401',
            'in_review',
            '{"de": "Arbeit beendet", "en": "Work finished"}'::jsonb)
    $sql$) $$,
    'L1: in Arbeit -> in Prüfung'
);

-- 16
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000401',
            'done',
            '{"de": "Geprüft und abgeschlossen", "en": "Reviewed and done"}'::jsonb)
    $sql$) $$,
    'L1: in Prüfung -> abgeschlossen'
);

-- 17
SELECT isnt(
    (SELECT finished_at FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000401'),
    NULL,
    'L1: der Abschlusszeitpunkt ist gesetzt'
);

-- 18: Der Verlauf trägt jeden erfolgreichen Wechsel genau einmal, in der
-- Reihenfolge des Lebenslaufs, und keinen der abgewiesenen.
SELECT results_eq(
    $$ SELECT event_kind, reason->>'de'
         FROM pm.state_history
        WHERE object_id = '00000000-0000-0000-0000-000000000401'
        ORDER BY seq $$,
    $$ VALUES ('state_change', 'Wird beurteilt'),
              ('state_change', 'Beurteilt und bereit'),
              ('state_change', 'Arbeit begonnen'),
              ('state_change', 'Arbeit beendet'),
              ('state_change', 'Geprüft und abgeschlossen') $$,
    'L1: der Verlauf gibt den ganzen Lebenslauf wieder'
);

-- ==================================================================
-- Lebenslauf 2 — Nacharbeit und dauerhafte Schwelle (§7.6, Regel 6)
--
-- Vorläufig: siehe den Vermerk OFFEN im Dateikopf. Dieser Lebenslauf prüft
-- Nacharbeit nach einer Prüfung und die dauerhafte Pflichtschwelle. Die
-- Rücknahme der Bereitschaft wegen einer neuen Grundfrage bildet er nicht ab.
--
--     Eingang -> bereit -> in Arbeit -> in Prüfung -> in Arbeit
--             -> verworfen
--
-- Ein Fehler, weil §7.6 für Fehler und Funktion ab bereit mindestens ein
-- Abschlusskriterium verlangt — damit lassen sich neben der Dringlichkeit
-- auch die Kriterien prüfen.
--
-- Zwei verschiedene Nachweise derselben Regel:
--   * in Prüfung -> in Arbeit ist der Rückweg (§7.6, Regel 1: "Ablesbar
--     bleibt der Rückweg"). Er führt in einen früheren Arbeitszustand und
--     löscht die einmal erreichte Schwelle nicht.
--   * in Arbeit -> verworfen ist kein Rückweg, sondern der endgültige
--     Abbruch. Er ist der einzige aus einem Zustand ab bereit erreichbare
--     Zustand, der die Schwelle selbst nicht auslöst
--     (pm.issue_state_meets_ready_threshold() enthält discarded absichtlich
--     nicht). ready_threshold_reached bleibt trotzdem wahr — genau dafür
--     wird das Merkmal gespeichert, statt aus dem Zustand abgeleitet.
-- ==================================================================

-- 19
SELECT lives_ok(
    $$
    SELECT pg_temp.create_as_editor($sql$
        INSERT INTO pm.issues (
            id,
            title,
            description,
            state,
            issue_kind,
            urgency,
            criteria
        ) VALUES (
            '00000000-0000-0000-0000-000000000411',
            '{"de": "Platzhalter bleibt stehen", "en": "Placeholder remains"}'::jsonb,
            '{"de": "Anlass und gewünschtes Ergebnis", "en": "Reason and desired outcome"}'::jsonb,
            'inbox',
            'bug',
            'high',
            '[{"schluessel": "K1",
               "text": {"de": "Der Platzhalter verschwindet", "en": "The placeholder disappears"},
               "stand": "open"}]'::jsonb
        );
        INSERT INTO pm.object_projects (object_id, project_id)
        VALUES (
            '00000000-0000-0000-0000-000000000411',
            (SELECT id
               FROM pm.projects
              WHERE key = 'test_lifecycle_project')
        );
    $sql$);
    $$,
    'L2: editor legt den Fehler im Eingang an'
);

-- 20
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000411',
            'ready',
            '{"de": "Ohne Klärung beurteilt", "en": "Assessed without clarification"}'::jsonb)
    $sql$) $$,
    'L2: Eingang -> bereit'
);

-- 21
SELECT ok(
    (SELECT ready_threshold_reached FROM pm.issues
      WHERE id = '00000000-0000-0000-0000-000000000411'),
    'L2: die Schwelle ab bereit ist erreicht'
);

-- 22
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        UPDATE pm.issues SET criteria = '[]'::jsonb
         WHERE id = '00000000-0000-0000-0000-000000000411'
    $sql$) $$,
    '23514',
    NULL,
    'L2: die Abschlusskriterien eines Fehlers lassen sich ab bereit nicht leeren'
);

-- 23
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000411',
            'in_progress',
            '{"de": "Arbeit begonnen", "en": "Work started"}'::jsonb)
    $sql$) $$,
    'L2: bereit -> in Arbeit'
);

-- 24
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000411',
            'in_review',
            '{"de": "Arbeit beendet", "en": "Work finished"}'::jsonb)
    $sql$) $$,
    'L2: in Arbeit -> in Prüfung'
);

-- 25: der Rückweg.
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000411',
            'in_progress',
            '{"de": "Kriterium durchgefallen", "en": "Criterion failed"}'::jsonb)
    $sql$) $$,
    'L2: in Prüfung -> in Arbeit (Rückweg)'
);

-- 26
SELECT is(
    (SELECT state FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000411'),
    'in_progress',
    'L2: der Vorgang steht nach dem Rückweg wieder in in Arbeit'
);

-- 27
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        UPDATE pm.issues SET urgency = NULL
         WHERE id = '00000000-0000-0000-0000-000000000411'
    $sql$) $$,
    '23514',
    NULL,
    'L2: die Dringlichkeit lässt sich auch nach dem Rückweg nicht leeren'
);

-- 28
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        UPDATE pm.issues SET criteria = '[]'::jsonb
         WHERE id = '00000000-0000-0000-0000-000000000411'
    $sql$) $$,
    '23514',
    NULL,
    'L2: die Abschlusskriterien lassen sich auch nach dem Rückweg nicht leeren'
);

-- 29
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000411',
            'discarded',
            '{"de": "Wird nicht ausgeführt", "en": "Will not be done"}'::jsonb)
    $sql$) $$,
    'L2: in Arbeit -> verworfen'
);

-- 30
SELECT isnt(
    (SELECT finished_at FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000411'),
    NULL,
    'L2: verworfen setzt den Abschlusszeitpunkt'
);

-- 31
SELECT ok(
    (SELECT ready_threshold_reached FROM pm.issues
      WHERE id = '00000000-0000-0000-0000-000000000411'),
    'L2: verworfen setzt die einmal erreichte Schwelle nicht zurück'
);

-- 32
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        UPDATE pm.issues SET urgency = NULL
         WHERE id = '00000000-0000-0000-0000-000000000411'
    $sql$) $$,
    '23514',
    NULL,
    'L2: die Dringlichkeit lässt sich auch im verworfenen Vorgang nicht leeren'
);

-- 33
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        UPDATE pm.issues SET criteria = '[]'::jsonb
         WHERE id = '00000000-0000-0000-0000-000000000411'
    $sql$) $$,
    '23514',
    NULL,
    'L2: die Abschlusskriterien lassen sich auch im verworfenen Vorgang nicht leeren'
);

-- 34
SELECT results_eq(
    $$ SELECT event_kind, reason->>'de'
         FROM pm.state_history
        WHERE object_id = '00000000-0000-0000-0000-000000000411'
        ORDER BY seq $$,
    $$ VALUES ('state_change', 'Ohne Klärung beurteilt'),
              ('state_change', 'Arbeit begonnen'),
              ('state_change', 'Arbeit beendet'),
              ('state_change', 'Kriterium durchgefallen'),
              ('state_change', 'Wird nicht ausgeführt') $$,
    'L2: der Rückweg steht als eigener Eintrag im Verlauf'
);

-- ==================================================================
-- Lebenslauf 3 — Abhängigkeit und Übergehung (§7.6, Regel 12)
--
--     B depends_on A   ->  B nach in Arbeit abgewiesen, solange A offen
--                      ->  mit Übergehungsgrund erlaubt, Übergehung im Verlauf
--     C depends_on A   ->  nach dem Abschluss von A ohne Grund erlaubt
--
-- Der dritte Vorgang C trennt die beiden Wege sauber: B beweist die
-- begründete Übergehung, C den gewöhnlichen Weg über den tatsächlichen
-- Abschluss des Vorgängers (§11, Schritt 4).
-- ==================================================================

-- 35
SELECT lives_ok(
    $$
    SELECT pg_temp.create_as_editor($sql$
        INSERT INTO pm.issues (
            id,
            title,
            description,
            state,
            issue_kind,
            urgency
        ) VALUES
            ('00000000-0000-0000-0000-000000000421',
             '{"de": "Vorgänger A", "en": "Predecessor A"}'::jsonb,
             '{"de": "Anlass und gewünschtes Ergebnis", "en": "Reason and desired outcome"}'::jsonb,
             'inbox', 'task', 'medium'),
            ('00000000-0000-0000-0000-000000000422',
             '{"de": "Nachfolger B", "en": "Successor B"}'::jsonb,
             '{"de": "Anlass und gewünschtes Ergebnis", "en": "Reason and desired outcome"}'::jsonb,
             'inbox', 'task', 'medium'),
            ('00000000-0000-0000-0000-000000000423',
             '{"de": "Nachfolger C", "en": "Successor C"}'::jsonb,
             '{"de": "Anlass und gewünschtes Ergebnis", "en": "Reason and desired outcome"}'::jsonb,
             'inbox', 'task', 'medium');
        INSERT INTO pm.object_projects (object_id, project_id)
        SELECT id,
               (SELECT id FROM pm.projects WHERE key = 'test_lifecycle_project')
          FROM pm.issues
         WHERE id IN ('00000000-0000-0000-0000-000000000421',
                      '00000000-0000-0000-0000-000000000422',
                      '00000000-0000-0000-0000-000000000423');
    $sql$);
    $$,
    'L3: editor legt Vorgänger und beide Nachfolger an'
);

-- 36
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        INSERT INTO pm.object_relations (source_id, target_id, relation_type)
        VALUES ('00000000-0000-0000-0000-000000000422',
                '00000000-0000-0000-0000-000000000421', 'depends_on'),
               ('00000000-0000-0000-0000-000000000423',
                '00000000-0000-0000-0000-000000000421', 'depends_on')
    $sql$) $$,
    'L3: editor verbindet beide Nachfolger über depends_on mit dem Vorgänger'
);

-- 37
SELECT results_eq(
    $$ SELECT issue_id
         FROM pm.issue_open_dependencies('00000000-0000-0000-0000-000000000422') $$,
    $$ VALUES ('00000000-0000-0000-0000-000000000421'::uuid) $$,
    'L3: der offene Vorgänger ist als Abhängigkeit ablesbar'
);

-- 38
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            id,
            'ready',
            '{"de": "Beurteilt und bereit", "en": "Assessed and ready"}'::jsonb)
          FROM pm.issues
         WHERE id IN ('00000000-0000-0000-0000-000000000421',
                      '00000000-0000-0000-0000-000000000422',
                      '00000000-0000-0000-0000-000000000423')
    $sql$) $$,
    'L3: alle drei Vorgänge werden nach bereit geführt'
);

-- 39
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000422',
            'in_progress',
            '{"de": "Arbeit begonnen", "en": "Work started"}'::jsonb)
    $sql$) $$,
    '23514',
    NULL,
    'L3: in Arbeit wird abgewiesen, solange der Vorgänger offen ist'
);

-- 40
SELECT is(
    (SELECT state FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000422'),
    'ready',
    'L3: der abgewiesene Übergang hat den Zustand nicht verändert'
);

-- 41
SELECT is(
    (SELECT count(*) FROM pm.state_history
      WHERE object_id = '00000000-0000-0000-0000-000000000422'),
    1::bigint,
    'L3: der abgewiesene Übergang hat keinen Verlaufseintrag erzeugt'
);

-- 42
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000422',
            'in_progress',
            '{"de": "Arbeit begonnen", "en": "Work started"}'::jsonb,
            NULL,
            '{"de": "Vorgänger hält uns nicht auf", "en": "Predecessor does not hold us up"}'::jsonb)
    $sql$) $$,
    'L3: mit Übergehungsgrund ist in Arbeit trotz offenem Vorgänger erlaubt'
);

-- 43: Zustandswechsel und Übergehung sind zwei Ereignisse (P-010).
SELECT results_eq(
    $$ SELECT event_kind, reason->>'de'
         FROM pm.state_history
        WHERE object_id = '00000000-0000-0000-0000-000000000422'
        ORDER BY seq $$,
    $$ VALUES ('state_change', 'Beurteilt und bereit'),
              ('state_change', 'Arbeit begonnen'),
              ('override',     'Vorgänger hält uns nicht auf') $$,
    'L3: die Übergehung steht als eigener Eintrag neben dem Zustandswechsel'
);

-- 44
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000421',
            'in_progress',
            '{"de": "Arbeit begonnen", "en": "Work started"}'::jsonb);
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000421',
            'in_review',
            '{"de": "Arbeit beendet", "en": "Work finished"}'::jsonb);
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000421',
            'done',
            '{"de": "Geprüft und abgeschlossen", "en": "Reviewed and done"}'::jsonb);
    $sql$) $$,
    'L3: der Vorgänger durchläuft seinen Lebenslauf bis abgeschlossen'
);

-- 45
SELECT is(
    (SELECT count(*) FROM pm.issue_open_dependencies('00000000-0000-0000-0000-000000000423')),
    0::bigint,
    'L3: nach dem Abschluss des Vorgängers steht keine Abhängigkeit mehr offen'
);

-- 46
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000423',
            'in_progress',
            '{"de": "Arbeit begonnen", "en": "Work started"}'::jsonb)
    $sql$) $$,
    'L3: der zweite Nachfolger beginnt nun ohne Übergehungsgrund'
);

-- 47
SELECT results_eq(
    $$ SELECT event_kind
         FROM pm.state_history
        WHERE object_id = '00000000-0000-0000-0000-000000000423'
        ORDER BY seq $$,
    $$ VALUES ('state_change'), ('state_change') $$,
    'L3: der gewöhnliche Weg erzeugt keine Übergehung im Verlauf'
);

-- ==================================================================
-- Lebenslauf 4 — Elternabschluss (§7.6, Regeln 1 und 5)
--
--     Epos E in Prüfung
--     └── Aufgabe T offen
--
--     E -> abgeschlossen  abgewiesen
--     T durchläuft seinen Lebenslauf bis abgeschlossen
--     E -> abgeschlossen  erlaubt
--
-- Das Epos erreicht in Prüfung über den gewöhnlichen Weg
-- (bereit -> in Arbeit -> in Prüfung). Es gibt keine Epos-Sondermatrix;
-- beschränkt ist ausschließlich der Abschluss.
-- ==================================================================

-- 48
SELECT lives_ok(
    $$
    SELECT pg_temp.create_as_editor($sql$
        INSERT INTO pm.issues (
            id,
            title,
            description,
            state,
            issue_kind,
            urgency,
            parent_id
        ) VALUES
            ('00000000-0000-0000-0000-000000000431',
             '{"de": "Epos E", "en": "Epic E"}'::jsonb,
             '{"de": "Anlass und gewünschtes Ergebnis", "en": "Reason and desired outcome"}'::jsonb,
             'inbox', 'epic', 'medium', NULL),
            ('00000000-0000-0000-0000-000000000432',
             '{"de": "Aufgabe T", "en": "Task T"}'::jsonb,
             '{"de": "Anlass und gewünschtes Ergebnis", "en": "Reason and desired outcome"}'::jsonb,
             'inbox', 'task', 'medium', '00000000-0000-0000-0000-000000000431');
        INSERT INTO pm.object_projects (object_id, project_id)
        SELECT id,
               (SELECT id FROM pm.projects WHERE key = 'test_lifecycle_project')
          FROM pm.issues
         WHERE id IN ('00000000-0000-0000-0000-000000000431',
                      '00000000-0000-0000-0000-000000000432');
    $sql$);
    $$,
    'L4: editor legt das Epos und seinen Kindvorgang an'
);

-- 49
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000431',
            'ready',
            '{"de": "Zerlegung steht", "en": "Breakdown established"}'::jsonb);
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000431',
            'in_progress',
            '{"de": "Kinder werden bearbeitet", "en": "Children in progress"}'::jsonb);
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000431',
            'in_review',
            '{"de": "Zerlegung wird geprüft", "en": "Breakdown under review"}'::jsonb);
    $sql$) $$,
    'L4: das Epos erreicht in Prüfung über den gewöhnlichen Weg'
);

-- 50
SELECT is(
    (SELECT state FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000431'),
    'in_review',
    'L4: das Epos steht in in Prüfung'
);

-- 51
SELECT results_eq(
    $$ SELECT issue_id
         FROM pm.issue_open_children('00000000-0000-0000-0000-000000000431') $$,
    $$ VALUES ('00000000-0000-0000-0000-000000000432'::uuid) $$,
    'L4: der Kindvorgang steht offen'
);

-- 52
SELECT throws_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000431',
            'done',
            '{"de": "Zerlegung abgeschlossen", "en": "Breakdown complete"}'::jsonb)
    $sql$) $$,
    '23514',
    NULL,
    'L4: der Abschluss des Epos wird bei offenem Kindvorgang abgewiesen'
);

-- 53
SELECT is(
    (SELECT state FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000431'),
    'in_review',
    'L4: der abgewiesene Abschluss hat den Zustand des Epos nicht verändert'
);

-- 54
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000432',
            'ready',
            '{"de": "Beurteilt und bereit", "en": "Assessed and ready"}'::jsonb);
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000432',
            'in_progress',
            '{"de": "Arbeit begonnen", "en": "Work started"}'::jsonb);
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000432',
            'in_review',
            '{"de": "Arbeit beendet", "en": "Work finished"}'::jsonb);
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000432',
            'done',
            '{"de": "Geprüft und abgeschlossen", "en": "Reviewed and done"}'::jsonb);
    $sql$) $$,
    'L4: der Kindvorgang durchläuft seinen Lebenslauf bis abgeschlossen'
);

-- 55
SELECT is(
    (SELECT count(*) FROM pm.issue_open_children('00000000-0000-0000-0000-000000000431')),
    0::bigint,
    'L4: es steht kein Kindvorgang mehr offen'
);

-- 56
SELECT lives_ok(
    $$ SELECT pg_temp.as_editor($sql$
        SELECT pm.transition_issue(
            '00000000-0000-0000-0000-000000000431',
            'done',
            '{"de": "Zerlegung abgeschlossen", "en": "Breakdown complete"}'::jsonb)
    $sql$) $$,
    'L4: das Epos kann nach dem Abschluss seines Kindvorgangs abgeschlossen werden'
);

-- 57
SELECT isnt(
    (SELECT finished_at FROM pm.issues WHERE id = '00000000-0000-0000-0000-000000000431'),
    NULL,
    'L4: der Abschlusszeitpunkt des Epos ist gesetzt'
);

-- 58: Der abgewiesene Abschluss steht nicht im Verlauf, der spätere schon.
SELECT results_eq(
    $$ SELECT event_kind, reason->>'de'
         FROM pm.state_history
        WHERE object_id = '00000000-0000-0000-0000-000000000431'
        ORDER BY seq $$,
    $$ VALUES ('state_change', 'Zerlegung steht'),
              ('state_change', 'Kinder werden bearbeitet'),
              ('state_change', 'Zerlegung wird geprüft'),
              ('state_change', 'Zerlegung abgeschlossen') $$,
    'L4: der Verlauf des Epos trägt nur die erfolgreichen Wechsel'
);

SELECT * FROM finish();
ROLLBACK;
