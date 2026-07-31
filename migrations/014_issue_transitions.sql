-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Der fachliche Zustandswechsel eines Vorgangs (§7.6) als einzige,
-- geschlossene Schreibstelle: pm.transition_issue(). 013_issues.sql hat
-- editor bewusst KEIN UPDATE-Recht auf state gegeben und die Regeln über
-- einen Übergang im Kontext (§7.6, Regel 1 Abschluss, Regel 12
-- Abhängigkeitsschranke) ausdrücklich zurückgestellt. Diese Migration holt
-- sie nach und verbindet sie mit dem Zustandsverlauf (P-010) in einem
-- einzigen Aufruf.
--
-- Eine Regel aus §7.6 bleibt absichtlich offen:
--   * Regel 11 (Vorhaben-Schranke): Sprint ist nicht Teil des ersten
--     Go-live; es gibt keine Sprinttabelle, gegen die geprüft werden könnte.
--
-- Zu Regel 5 ("ein Epos wird nicht selbst bearbeitet"): Sie ist keine
-- Zustandssperre. §7.6 stellt das seit der Klarstellung bei Regel 5
-- ausdrücklich fest, und §9.3 zeigt ein Epos im Zustand in Arbeit. Das Epos
-- folgt derselben Übergangstabelle wie jede andere Vorgangsart. Für das Epos
-- gilt beim Abschluss zusätzlich, dass es mindestens einen Kindvorgang
-- besitzen muss. Wie bei jedem Elternvorgang darf außerdem kein Kind offen
-- sein. Eine Sperre gegen `in_progress` wäre dagegen in sich widersprüchlich:
-- der einzige Weg nach `done` führt über `in_progress` und `in_review`, ein
-- gesperrtes Epos könnte nie abgeschlossen werden.
--
-- Warum SECURITY DEFINER: editor besitzt kein UPDATE-Recht auf state und
-- soll es auch nicht bekommen. Die Funktion gehört schema_owner und ist der
-- einzige Weg, state zu bewegen. Sie prüft deshalb vollständig selbst; sie
-- ersetzt aber keinen der Trigger aus 013_issues.sql, sondern läuft in sie
-- hinein: Pflicht-ab-bereit, Sprachkarten, Kriterienschema, blocker_reason-
-- und finished_at-Pflicht, ready_threshold_reached/issue_kind_locked
-- (Regel 6, "Rückwege löschen nichts") wirken über das UPDATE unverändert
-- weiter.

SET ROLE schema_owner;

-- ---------------------------------------------------------------------
-- Übergangstabelle (§7.6, "Zustände und Übergänge") als verwaltete Tabelle
-- statt als CASE-Kette in der Funktion — dasselbe Muster wie
-- pm.issue_hierarchy_rules (013) und pm.relation_type_endpoints (006).
-- Sie ist damit abfragbar: P-013 (Schwellenauskunft) braucht später genau
-- diese Liste, um "was ist von hier aus möglich?" beantworten zu können,
-- ohne den Funktionsrumpf zu lesen.
--
-- done und discarded treten nirgends als from_state auf: "abgeschlossen hat
-- keinen Rückweg" (§7.6), und ein verworfener Vorgang wird nicht
-- wiederbelebt. Eine später erkannte Lücke ist ein neuer Vorgang mit
-- Verweis auf den alten.
-- ---------------------------------------------------------------------

CREATE TABLE pm.issue_state_transitions (
    from_state text NOT NULL,
    to_state   text NOT NULL,
    PRIMARY KEY (from_state, to_state),
    CONSTRAINT issue_state_transitions_is_not_self
        CHECK (from_state <> to_state)
);

COMMENT ON TABLE pm.issue_state_transitions IS
    'Zulässige Zustandsübergänge eines Vorgangs (§7.6, "Zustände und '
    'Übergänge"). Ein Zustand ohne Zeile als from_state ist endgültig '
    '(done, discarded). Gilt für alle Vorgangsarten gleichermaßen — auch '
    'für das Epos (§7.6, Regel 5 ist keine Zustandssperre).';

INSERT INTO pm.issue_state_transitions (from_state, to_state) VALUES
    ('inbox',         'clarification'),
    ('inbox',         'ready'),
    ('inbox',         'discarded'),

    ('clarification', 'ready'),
    ('clarification', 'inbox'),
    ('clarification', 'discarded'),

    ('ready',         'planned'),
    ('ready',         'in_progress'),
    ('ready',         'discarded'),

    ('planned',       'in_progress'),
    ('planned',       'ready'),
    ('planned',       'discarded'),

    ('in_progress',   'blocked'),
    ('in_progress',   'in_review'),
    ('in_progress',   'discarded'),

    ('blocked',       'in_progress'),
    ('blocked',       'discarded'),

    ('in_review',     'done'),
    ('in_review',     'in_progress');

-- ---------------------------------------------------------------------
-- Offene unmittelbare Vorgänger über depends_on (§7.6, Regel 12). Eigene
-- benannte Funktion, weil dieselbe Frage später auch für eine Auskunft
-- ("warum darf ich noch nicht beginnen?") gebraucht wird und dann nicht ein
-- zweites Mal mit womöglich abweichender Zustandsliste nachgebaut werden
-- soll. Nur unmittelbare Vorgänger, nicht der transitive Abschluss: Regel 12
-- spricht ausdrücklich vom "unmittelbaren Vorgänger", und ein mittelbarer
-- Vorgänger ist bereits über seinen eigenen Übergang nach in_progress
-- geprüft worden.
-- ---------------------------------------------------------------------

CREATE FUNCTION pm.issue_open_dependencies(p_issue_id uuid)
RETURNS TABLE (issue_id uuid, state text)
LANGUAGE sql
STABLE
AS $$
    SELECT target.id, target.state
      FROM pm.object_relations AS rel
      JOIN pm.issues AS target ON target.id = rel.target_id
     WHERE rel.source_id = p_issue_id
       AND rel.relation_type = 'depends_on'
       AND target.state NOT IN ('done', 'discarded')
     ORDER BY target.id;
$$;

COMMENT ON FUNCTION pm.issue_open_dependencies(uuid) IS
    'Unmittelbare depends_on-Vorgänger von p_issue_id, die weder done noch '
    'discarded sind (§7.6, Regel 12). Projektübergreifende Kanten sind '
    'ausdrücklich eingeschlossen — depends_on kennt keine Projektschranke '
    '(§7.6, Regel 4 gilt nur für die Hierarchie).';

CREATE FUNCTION pm.issue_open_children(p_issue_id uuid)
RETURNS TABLE (issue_id uuid, state text)
LANGUAGE sql
STABLE
AS $$
    SELECT child.id, child.state
      FROM pm.issues AS child
     WHERE child.parent_id = p_issue_id
       AND child.state NOT IN ('done', 'discarded')
     ORDER BY child.id;
$$;

COMMENT ON FUNCTION pm.issue_open_children(uuid) IS
    'Unmittelbare Kindvorgänge von p_issue_id, die weder done noch discarded '
    'sind (§7.6, Regel 1: "kein Kindvorgang steht offen"). Nur die '
    'unmittelbare Ebene: ein Kind kann selbst nur abgeschlossen werden, wenn '
    'seine eigenen Kinder geschlossen sind — die Prüfung trägt also über die '
    'ganze Tiefe, ohne rekursiv zu sein.';

-- ---------------------------------------------------------------------
-- Der Zustandswechsel selbst.
--
-- Parameter:
--   p_blocker_reason  gehört zum Übergang nach blocked. Ohne ihn ist
--                     blocked überhaupt nicht erreichbar: der Trigger aus
--                     013 verlangt blocker_reason in blocked und verbietet
--                     ihn außerhalb — ein Vorabsetzen durch editor ist damit
--                     unmöglich. Beim Verlassen von blocked setzt die
--                     Funktion ihn selbst zurück.
--                     Die Nachschärfung eines bestehenden Blockadegrunds
--                     OHNE Zustandswechsel bleibt bewusst ein gewöhnliches
--                     UPDATE durch editor: sie ist kein Zustandswechsel und
--                     soll keinen künstlichen blocked -> in_progress ->
--                     blocked und keinen falschen Verlaufseintrag erzwingen.
--   p_reason          Grund des Zustandswechsels (P-010). Pflicht bei jedem
--                     Übergang.
--   p_override_reason ausschließlich die bewusste Übergehung einer offenen
--                     depends_on-Abhängigkeit (Regel 12). Getrennt von
--                     p_reason, weil Zustandswechsel und Übergehung in P-010
--                     zwei verschiedene Ereignisarten sind und beide einen
--                     eigenen Grund tragen.
--
-- Zwei Verlaufseinträge bei einer Übergehung, nicht einer: state_change
-- beantwortet "warum jetzt in Arbeit?", override beantwortet "warum trotz
-- offener Abhängigkeit?". Ein zusammengelegter Eintrag könnte die Frage
-- "wie oft wurde übergangen?" (§7.6, Regel 12, Gewinn) nur noch über den
-- Grundtext beantworten.
--
-- p_reason wird NICHT vorab geprüft, sondern erst durch den Trigger auf
-- pm.state_history (012) — an einer Stelle, mit einer Fehlermeldung. Dass
-- der Verlaufseintrag damit nach dem UPDATE scheitern kann, ist kein Mangel,
-- sondern der Nachweis: ein Zustandswechsel ohne Verlaufseintrag ist
-- unmöglich, weil beides im selben Aufruf und in derselben Transaktion erfolgt
-- und gemeinsam zurückgerollt wird.
-- ---------------------------------------------------------------------

CREATE FUNCTION pm.transition_issue(
    p_issue_id        uuid,
    p_target_state    text,
    p_reason          jsonb,
    p_blocker_reason  jsonb DEFAULT NULL,
    p_override_reason jsonb DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pm
AS $$
DECLARE
    v_issue          pm.issues%ROWTYPE;
    v_open_dependency uuid;
    v_open_child      uuid;
BEGIN
    -- Sperrt den Vorgang für die Dauer der Transaktion. Ohne sie könnten
    -- zwei gleichzeitige Aufrufe denselben Ausgangszustand lesen, beide ihre
    -- Übergangsprüfung bestehen und zwei widersprüchliche Verlaufseinträge
    -- erzeugen.
    SELECT * INTO v_issue FROM pm.issues WHERE id = p_issue_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vorgang % existiert nicht', p_issue_id
            USING ERRCODE = '23503';
    END IF;

    -- 1. Ist der Übergang überhaupt vorgesehen? Deckt zugleich einen
    --    unbekannten Zielzustand, den Wechsel auf denselben Zustand und
    --    jeden Versuch, einen endgültigen Zustand wieder zu verlassen.
    IF NOT EXISTS (
        SELECT 1 FROM pm.issue_state_transitions
         WHERE from_state = v_issue.state AND to_state = p_target_state
    ) THEN
        RAISE EXCEPTION 'Übergang % -> % ist für einen Vorgang nicht zulässig',
            v_issue.state, p_target_state
            USING ERRCODE = '23514';
    END IF;

    -- 2. Blockadegrund gehört genau zum Übergang nach blocked.
    IF p_target_state = 'blocked' AND p_blocker_reason IS NULL THEN
        RAISE EXCEPTION 'Der Wechsel nach blocked verlangt einen Blockadegrund'
            USING ERRCODE = '23514';
    END IF;
    IF p_target_state <> 'blocked' AND p_blocker_reason IS NOT NULL THEN
        RAISE EXCEPTION
            'Ein Blockadegrund ist beim Wechsel nach % unzulässig', p_target_state
            USING ERRCODE = '23514';
    END IF;

    -- 3. Abhängigkeitsschranke (Regel 12), nur beim Wechsel nach in_progress
    --    — auch aus blocked heraus, denn die Schranke hängt am Zielzustand,
    --    nicht am Weg dorthin.
    IF p_target_state = 'in_progress' THEN
        SELECT issue_id INTO v_open_dependency
          FROM pm.issue_open_dependencies(p_issue_id) LIMIT 1;

        IF v_open_dependency IS NOT NULL AND p_override_reason IS NULL THEN
            RAISE EXCEPTION
                'Vorgang % hängt von dem noch offenen Vorgang % ab; '
                'der Wechsel nach in_progress verlangt einen Übergehungsgrund',
                p_issue_id, v_open_dependency
                USING ERRCODE = '23514';
        END IF;
    END IF;

    -- Eine Übergehung ohne etwas zu Übergehendes wäre ein Verlaufseintrag
    -- über ein Ereignis, das nicht stattgefunden hat. Sie wird abgewiesen,
    -- nicht stillschweigend verworfen.
    IF p_override_reason IS NOT NULL
       AND (p_target_state <> 'in_progress' OR v_open_dependency IS NULL)
    THEN
        RAISE EXCEPTION
            'Ein Übergehungsgrund ist nur bei einer offenen '
            'depends_on-Abhängigkeit und nur beim Wechsel nach in_progress zulässig'
            USING ERRCODE = '23514';
    END IF;

    -- 4. Abschluss (Regel 1): erfüllte Kriterien und keine offenen Kinder.
    --    Nur für done — discarded ist kein Abschluss, sondern die
    --    Feststellung, dass die Arbeit nicht ausgeführt wird.
    IF p_target_state = 'done' THEN
        IF jsonb_path_exists(v_issue.criteria, '$[*] ? (@.stand != "fulfilled")') THEN
            RAISE EXCEPTION
                'Vorgang % kann nicht abgeschlossen werden: nicht jedes '
                'Abschlusskriterium trägt den Stand fulfilled', p_issue_id
                USING ERRCODE = '23514';
        END IF;

        -- Vor der Prüfung auf offene Kinder: ein Epos ohne jede Zerlegung
        -- erfüllt "kein Kind steht offen" zwar leer, aber sein Abschluss
        -- folgt laut Regel 5 aus den Kindern — ohne Kinder gibt es nichts,
        -- woraus er folgen könnte.
        IF v_issue.issue_kind = 'epic'
           AND NOT EXISTS (
               SELECT 1
                 FROM pm.issues AS child
                WHERE child.parent_id = p_issue_id
           )
        THEN
            RAISE EXCEPTION
                'Epos % kann nicht abgeschlossen werden: es besitzt keinen Kindvorgang',
                p_issue_id
                USING ERRCODE = '23514';
        END IF;

        SELECT issue_id INTO v_open_child
          FROM pm.issue_open_children(p_issue_id) LIMIT 1;

        IF v_open_child IS NOT NULL THEN
            RAISE EXCEPTION
                'Vorgang % kann nicht abgeschlossen werden: Kindvorgang % steht offen',
                p_issue_id, v_open_child
                USING ERRCODE = '23514';
        END IF;
    END IF;

    -- 5. Zustand und Zeitpunkte. Ein endgültiger Zustand ist nicht wieder
    --    verlassbar (siehe Übergangstabelle), deshalb braucht finished_at
    --    keinen Rücksetzweg. started_at wird nur beim ERSTEN Erreichen von
    --    in_progress gesetzt; ein Rückweg über blocked oder in_review ändert
    --    den Beginn nicht.
    UPDATE pm.issues
       SET state          = p_target_state,
           blocker_reason = CASE
                                WHEN p_target_state = 'blocked' THEN p_blocker_reason
                                ELSE NULL
                            END,
           started_at     = CASE
                                WHEN p_target_state = 'in_progress'
                                     AND started_at IS NULL
                                THEN statement_timestamp()
                                ELSE started_at
                            END,
           finished_at    = CASE
                                WHEN p_target_state IN ('done', 'discarded')
                                THEN statement_timestamp()
                                ELSE finished_at
                            END
     WHERE id = p_issue_id;

    -- 6. Verlauf. Erfolgt im selben Aufruf und in derselben Transaktion wie das
    --    UPDATE: scheitert der Verlaufseintrag, wird auch der Zustandswechsel
    --    zurückgerollt.
    PERFORM pm.append_state_history(p_issue_id, 'state_change', p_reason);

    IF p_override_reason IS NOT NULL THEN
        PERFORM pm.append_state_history(p_issue_id, 'override', p_override_reason);
    END IF;
END;
$$;

COMMENT ON FUNCTION pm.transition_issue(uuid, text, jsonb, jsonb, jsonb) IS
    'Einziger fachlicher Schreibweg für pm.issues.state (§7.6). Prüft den '
    'Übergang gegen pm.issue_state_transitions, verlangt einen Blockadegrund '
    'für blocked, setzt die Abhängigkeitsschranke (Regel 12) mit begründeter '
    'Übergehung durch und sperrt den Abschluss bei unerfüllten Kriterien, '
    'offenen Kindern oder einem Epos ohne Kind (Regeln 1 und 5). Zustand, '
    'Zeitpunkte und Zustandsverlauf (P-010) werden atomar fortgeschrieben.';

REVOKE ALL ON FUNCTION pm.transition_issue(uuid, text, jsonb, jsonb, jsonb) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION pm.transition_issue(uuid, text, jsonb, jsonb, jsonb)
    TO migrator, editor;

GRANT SELECT ON pm.issue_state_transitions TO editor, reader;

REVOKE ALL ON FUNCTION pm.issue_open_dependencies(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION pm.issue_open_children(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION pm.issue_open_dependencies(uuid) TO editor, reader;
GRANT EXECUTE ON FUNCTION pm.issue_open_children(uuid) TO editor, reader;

-- ---------------------------------------------------------------------
-- Umgehungsweg schließen: finished_at ist ausschließlich Folge des
-- Zustandswechsels nach done oder discarded. Solange editor die Spalte
-- unmittelbar schreiben darf, ließe sich ein Abschlusszeitpunkt ohne
-- Zustandswechsel setzen oder ein bereits belegter nachträglich
-- umschreiben — beides ohne Verlaufseintrag.
--
-- blocker_reason behält editor ausdrücklich: sein Inhalt kann sich während
-- derselben Blockade sachlich ändern ("wartet auf Zugang" -> "Zugang
-- erteilt, wartet auf Freigabe"), und der Trigger aus 013 hält ihn
-- weiterhin in blocked verpflichtend und außerhalb unzulässig.
-- ---------------------------------------------------------------------

REVOKE UPDATE (finished_at) ON pm.issues FROM editor;

RESET ROLE;
