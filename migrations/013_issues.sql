-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Erste echte Fachart (§7.6, Vorgang): ausführbare Arbeit oder ein
-- steuerbarer Befund. Trägt das gemeinsame Mindestraster (§7.3) über die
-- bestehende Grundlage (object_registry, short_ids, object_projects,
-- object_areas, state_history) und ergänzt die eigenen Pflicht- und
-- optionalen Angaben aus §7.6.
--
-- Bewusst NICHT Teil dieser Migration:
--   * Sammelvorgang (§7.6.1) als zulässige Vorgangsart. Ohne Beiträge-
--     Nebenfolge, Mindesthandlung und einen echten Richtlinienverweis (§7.9,
--     Fachart existiert noch nicht) wäre er nur formal anlegbar, aber
--     fachlich unvollständig. Die CHECK-Bedingung auf issue_kind lässt
--     'collector' deshalb absichtlich noch nicht zu; er folgt als eigene
--     additive Migration.
--   * Sprintauswahl, Sprintrolle, Regel 11 (Vorhaben-Schranke) — Sprint ist
--     ausdrücklich nicht Teil des ersten Go-live (Phase-B-Entscheidung zu
--     §12.5).
--   * Regel 1 (Abschluss: erfüllte Kriterien, kein offener Kindvorgang),
--     Regel 5 ("ein Epos wird nicht selbst bearbeitet") und Regel 12
--     (Abhängigkeitsschranke, übergehbar) — allesamt Regeln über einen
--     Zustandsübergang im Kontext, keine reinen Spaltenregeln. Sie gehören
--     geschlossen in die spätere atomare Übergangsfunktion
--     pm.transition_issue(). Damit dazwischen kein rohes UPDATE diese Regeln
--     umgeht, erhält editor in dieser Migration KEIN UPDATE-Recht auf state
--     überhaupt (siehe GRANTs am Ende) — state wird bei der Anlage gesetzt
--     und bleibt bis zur Übergangsfunktion unveränderlich.
--   * Verantwortung (P-004): existiert als fachliche Identität noch nicht
--     (siehe bereits 012_state_history.sql) — kein Feld dafür hier.
--   * Übergehungen (Nebenfolge aus Regel 12): fällt mit der Übergangs-
--     funktion zusammen, nutzt pm.state_history (event_kind = 'override',
--     bereits in 012 vorgesehen), keine eigene Tabelle hier.
--   * Die Abschlusssperre bei offenen Kindvorgängen ist spezifiziert (Regel 1),
--     aber ebenfalls eine Regel über einen Zustandsübergang: sie prüft
--     pm.transition_issue() beim Wechsel nach `done`. Eine automatische
--     Zustandsausbreitung von Kindern auf den Elternvorgang ist damit NICHT
--     vorausgesetzt. Ein Epos folgt dabei der gewöhnlichen Übergangstabelle;
--     "nicht selbst bearbeitet" (Regel 5) sperrt weder `in_progress` noch
--     `in_review`, verlangt für den Abschluss aber mindestens einen Kindvorgang.
--
-- Zwei Klassen von Prüfregeln, technisch unterschiedlich behandelt:
--   * Regeln über Spalten EINER Zeile (Sprachkarten, Kriterienschema,
--     issue_kind-Sperre, blocker_reason/finished_at-Pflicht, Kindart-
--     Kompatibilität gegenüber dem bereits bestehenden Elternvorgang und den
--     bereits bestehenden eigenen Kindern) laufen als gewöhnliche BEFORE-
--     Trigger auf pm.issues — alle beteiligten Zeilen sind zum Prüfzeitpunkt
--     bereits vorhanden.
--   * Regeln, die pm.object_projects und/oder pm.projects einbeziehen
--     (Umfang-Pflicht nur bei scope_mode = weighted; Eltern- und Kindvorgang
--     im selben Projekt) laufen als DEFERRABLE INITIALLY DEFERRED Constraint-
--     Trigger, wie schon pm.enforce_object_project_assignment_required()
--     in 009_projects.sql: Fachzeile, Registrierung und Projektzuordnung
--     entstehen als mehrere Anweisungen derselben Transaktion, und ein
--     Projekt kann nachträglich seinen scope_mode wechseln oder ein Vorgang
--     kann nachträglich umgehängt werden — eine sofortige Prüfung sähe in
--     all diesen Fällen einen unvollständigen Zwischenstand. Deshalb liegen
--     auf allen drei betroffenen Tabellen (pm.issues, pm.object_projects,
--     pm.projects) je eigene Constraint-Trigger, die dieselbe Prüffunktion
--     je betroffenem Vorgang aufrufen.

SET ROLE schema_owner;

CREATE TABLE pm.issues (
    id                   uuid PRIMARY KEY
        DEFAULT uuidv7(),

    title                jsonb NOT NULL,
    description          jsonb NOT NULL,

    -- Kein Vorgabewert (§7.1.1, Regel 5). Gültige Werte entsprechen den neun
    -- Zuständen aus §7.6. Die Übergangstabelle selbst ist NICHT Teil dieser
    -- Migration, siehe Kopf.
    state                text NOT NULL
        CHECK (
            state IN (
                'inbox', 'clarification', 'ready', 'planned', 'in_progress',
                'blocked', 'in_review', 'done', 'discarded'
            )
        ),

    -- Vorgangsart, Pflicht ab bereit. 'collector' (Sammelvorgang) bewusst
    -- noch nicht zulässig, siehe Kopf.
    issue_kind           text
        CHECK (issue_kind IS NULL OR issue_kind IN (
            'epic', 'feature', 'bug', 'task', 'maintenance'
        )),

    -- Wahr, sobald state erstmals 'in_progress' erreicht hat; danach nie
    -- wieder falsch. Trägt die dauerhafte Unveränderlichkeit von issue_kind
    -- (Regel: "unveränderlich nach Wechsel in in Arbeit") — ein Vergleich
    -- gegen OLD.state allein würde das nicht leisten, sobald der Vorgang
    -- inzwischen in einem anderen Zustand (blockiert, in Prüfung,
    -- abgeschlossen, verworfen) steht. editor erhält kein UPDATE-Recht auf
    -- diese Spalte; der Trigger unten berechnet sie bei jeder Änderung
    -- selbst und ignoriert einen extern gesetzten Wert vollständig.
    issue_kind_locked    boolean NOT NULL DEFAULT false,

    -- Wahr, sobald state erstmals die Schwelle "ab bereit" erreicht hat
    -- (pm.issue_state_meets_ready_threshold); danach nie wieder falsch.
    -- Trägt Regel 6 ("Rückwege löschen nichts"): ohne diese Spalte würde
    -- ein Rückweg z. B. von bereit nach in Klärung die Pflichtprüfungen für
    -- issue_kind/urgency/criteria/scope stillschweigend wieder abschalten.
    -- Dieselbe Begründung und dieselbe Sperre gegen direkte Änderungen wie
    -- bei issue_kind_locked.
    ready_threshold_reached boolean NOT NULL DEFAULT false,

    urgency              text
        CHECK (urgency IS NULL OR urgency IN ('low', 'medium', 'high', 'critical')),

    -- Umfang, Pflicht ab bereit NUR bei Projekten mit scope_mode =
    -- 'weighted'. Die Prüfung selbst läuft als verzögerter Constraint-
    -- Trigger (siehe Kopf), weil sie pm.object_projects/pm.projects braucht.
    scope                text
        CHECK (scope IS NULL OR scope IN ('small', 'medium', 'large')),

    -- Punktfolge (§7.2: "gegen das Schema der Fachart geprüft, nicht
    -- abfragbar") — deshalb jsonb, keine Kindtabelle. Form-, Eindeutigkeits-
    -- und Sprachkartenprüfung je Eintrag im Trigger unten; hier nur die
    -- Grundform (Array).
    criteria             jsonb NOT NULL DEFAULT '[]'::jsonb
        CHECK (jsonb_typeof(criteria) = 'array'),

    parent_id            uuid
        REFERENCES pm.issues(id)
        ON DELETE RESTRICT,

    -- Pflicht in blockiert, sonst unzulässig (Regel 6) — geprüft im Trigger
    -- unten, weil das vom Zustand abhängt.
    blocker_reason       jsonb,

    implementation_notes jsonb,

    started_at           timestamptz,
    -- Pflicht in abgeschlossen und verworfen — geprüft im Trigger unten.
    finished_at          timestamptz,

    created_at           timestamptz NOT NULL
        DEFAULT statement_timestamp(),
    updated_at           timestamptz NOT NULL
        DEFAULT statement_timestamp(),

    CONSTRAINT issues_parent_is_not_self
        CHECK (parent_id IS NULL OR parent_id <> id)
);

COMMENT ON TABLE pm.issues IS
    'Vorgang (§7.6): ausführbare Arbeit oder ein steuerbarer Befund. Erste '
    'Fachart, die das gemeinsame Mindestraster (§7.3) über object_registry, '
    'short_ids, object_projects, object_areas und state_history trägt.';
COMMENT ON COLUMN pm.issues.title IS
    'Nicht leere Sprachkarte. Im Zustand inbox genügt eine Sprache '
    '(§7.6, "Sprachen im Eingang"), sonst gilt P-005 vollständig — geprüft '
    'im Trigger, nicht per CHECK, weil das vom Zustand abhängt.';
COMMENT ON COLUMN pm.issues.description IS
    'Wie title: Anlass und gewünschtes Ergebnis, dieselbe Eingang-Ausnahme.';
COMMENT ON COLUMN pm.issues.issue_kind IS
    'Vorgangsart. Ab dem ersten Erreichen von in_progress dauerhaft '
    'unveränderlich (issue_kind_locked). Pflicht ab bereit.';
COMMENT ON COLUMN pm.issues.urgency IS
    'Dringlichkeit. Kein Vorgabewert (Urteil). Pflicht ab bereit.';
COMMENT ON COLUMN pm.issues.scope IS
    'Umfang. Pflicht ab bereit, nur wenn das unmittelbare Projekt '
    'scope_mode = weighted trägt (verzögerte Prüfung, siehe Kopf).';
COMMENT ON COLUMN pm.issues.criteria IS
    'Abschlusskriterien als Punktfolge: [{schluessel, text (Sprachkarte), '
    'stand: open|fulfilled}], keine weiteren Felder, schluessel eindeutig '
    'innerhalb der Punktfolge. Pflicht ab bereit (mindestens ein Eintrag) '
    'bei issue_kind IN (feature, bug).';
COMMENT ON COLUMN pm.issues.parent_id IS
    'Elternvorgang (§7.6, Regel 2-4): Kindart-Kompatibilität und '
    'Zyklenfreiheit unmittelbar geprüft; gemeinsames Projekt verzögert '
    'geprüft (siehe Kopf).';
COMMENT ON COLUMN pm.issues.blocker_reason IS
    'Blockadegrund als Sprachkarte. Pflicht in blockiert, sonst unzulässig '
    '(Regel 6).';
COMMENT ON COLUMN pm.issues.implementation_notes IS
    'Optionale Sprachkarte für Umsetzungsplan/Notizen.';
COMMENT ON COLUMN pm.issues.started_at IS
    'Beginn. Fachliche Angabe, keine Bearbeitungsspur — optional, keine '
    'genannte Schwelle in §7.6.';
COMMENT ON COLUMN pm.issues.finished_at IS
    'Abschlusszeitpunkt. Pflicht in done und discarded.';

-- ---------------------------------------------------------------------
-- Registrierung (§7.3, gemeinsames Mindestraster) nach dem Muster aus
-- 003_object_registry.sql/010_short_ids.sql.
-- ---------------------------------------------------------------------

INSERT INTO pm.object_types (key, table_name, requires_project_assignment)
VALUES ('issue', 'pm.issues'::regclass, true);

CREATE TRIGGER issues_register_object
    AFTER INSERT ON pm.issues
    FOR EACH ROW
    EXECUTE FUNCTION pm.register_object('issue');

CREATE TRIGGER issues_deregister_object
    BEFORE DELETE ON pm.issues
    FOR EACH ROW
    EXECUTE FUNCTION pm.deregister_object('issue');

-- ---------------------------------------------------------------------
-- Anfangszustand: ein normaler, per editor angelegter Vorgang beginnt immer
-- im Eingang — alles andere ist Zustandsverlauf, nicht Anlage. Ohne diese
-- Regel könnte editor schon vor pm.transition_issue() z. B. direkt einen
-- Vorgang im Zustand done anlegen und damit Zustandsübergänge, Verlauf,
-- Abhängigkeitsschranke und Übergehungsgrund vollständig umgehen. migrator
-- bleibt für kontrollierte Importe historischer Inhalte (§5, Ablauf F; P-007)
-- uneingeschränkt — ein importierter Vorgang muss trotzdem alle übrigen
-- Constraints dieser Migration erfüllen (Pflichtfelder, Kriterien,
-- finished_at, ...), nur der Anfangszustand selbst ist nicht auf inbox
-- beschränkt. Regel über die Anlage (INSERT), keine Übergangsregel — bleibt
-- deshalb hier und nicht in der späteren pm.transition_issue().
-- current_user statt session_user: erkennt die wirksame Schreibrolle auch,
-- wenn ein technischer Login SET ROLE editor verwendet. Ein späterer
-- SECURITY-DEFINER-Schreibweg muss diese Anfangszustandsregel ausdrücklich
-- erhalten; er darf sie nicht durch die Eigentümerrolle umgehen.
-- ---------------------------------------------------------------------

CREATE FUNCTION pm.enforce_issue_initial_state()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF current_user = 'editor' AND NEW.state <> 'inbox' THEN
        RAISE EXCEPTION 'editor darf Vorgänge nur im Zustand inbox anlegen'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.enforce_issue_initial_state() IS
    'editor darf pm.issues nur mit state = inbox anlegen; migrator bleibt '
    'für kontrollierte Importe (§5, Ablauf F) uneingeschränkt.';

CREATE TRIGGER issues_enforce_initial_state
    BEFORE INSERT ON pm.issues
    FOR EACH ROW
    EXECUTE FUNCTION pm.enforce_issue_initial_state();

-- ---------------------------------------------------------------------
-- Gemeinsame Schwellenfunktion "ab bereit" (§7.1.1), an einer Stelle
-- benannt, damit sie nicht mehrfach mit abweichenden Zustandslisten
-- nachgebaut wird. discarded ist bewusst NICHT enthalten: ein Vorgang, der
-- unmittelbar aus Eingang/in Klärung verworfen wird, hat die Schwelle nie
-- erreicht (Regel 6, "Rückwege löschen nichts", gilt nur für bereits
-- erreichte Schwellen).
-- ---------------------------------------------------------------------

CREATE FUNCTION pm.issue_state_meets_ready_threshold(p_state text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT p_state IN (
        'ready', 'planned', 'in_progress', 'blocked', 'in_review', 'done'
    );
$$;

COMMENT ON FUNCTION pm.issue_state_meets_ready_threshold(text) IS
    'Wahr für Zustände ab bereit (§7.1.1), OHNE discarded — ein direkt aus '
    'Eingang/in Klärung verworfener Vorgang hat die Schwelle nie erreicht.';

-- ---------------------------------------------------------------------
-- Sprachkarten: title/description mit der Eingang-Ausnahme aus §7.6;
-- blocker_reason/implementation_notes vollständig, aber optional.
-- pm.validate_language_map()/pm.validate_nonempty_language_map()
-- (002_languages.sql, 008_common_field_functions.sql) verlangen bei
-- Vorhandensein immer ALLE Pflichtsprachen — dafür ist die Eingang-
-- Ausnahme zu eng. Diese Hilfsfunktion prüft dieselbe statische Grundform
-- (nicht leeres Objekt, nur Zeichenketten, keine Leerraumwerte, nur
-- konfigurierte Sprachcodes, Mindestlänge je vorhandenem Wert) OHNE die
-- Vollständigkeitsprüfung — bewusst hier und nicht in
-- 008_common_field_functions.sql, weil die Ausnahme spezifisch für §7.6
-- ist, kein allgemeines Muster.
-- ---------------------------------------------------------------------

CREATE FUNCTION pm.validate_partial_language_map(
    p_value          jsonb,
    p_minimum_length integer
) RETURNS void
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    unknown_languages   text[];
    too_short_languages text[];
BEGIN
    IF p_value IS NULL THEN
        RAISE EXCEPTION 'Sprachkarte darf nicht NULL sein'
            USING ERRCODE = '23514';
    END IF;

    IF jsonb_typeof(p_value) <> 'object' OR p_value = '{}'::jsonb THEN
        RAISE EXCEPTION 'Sprachkarte muss ein nicht leeres JSON-Objekt sein'
            USING ERRCODE = '23514';
    END IF;

    IF jsonb_path_exists(p_value, '$.* ? (@.type() != "string")') THEN
        RAISE EXCEPTION 'Alle Werte einer Sprachkarte müssen Zeichenketten sein'
            USING ERRCODE = '23514';
    END IF;

    SELECT array_agg(entry.code ORDER BY entry.code) INTO unknown_languages
      FROM jsonb_object_keys(p_value) AS entry(code)
     WHERE NOT EXISTS (SELECT 1 FROM pm.languages l WHERE l.code = entry.code);

    IF unknown_languages IS NOT NULL THEN
        RAISE EXCEPTION 'Sprachkarte enthält unbekannte Sprachen: %', unknown_languages
            USING ERRCODE = '23514';
    END IF;

    SELECT array_agg(entry.code ORDER BY entry.code) INTO too_short_languages
      FROM jsonb_each_text(p_value) AS entry(code, text_value)
     WHERE length(btrim(entry.text_value)) < p_minimum_length;

    IF too_short_languages IS NOT NULL THEN
        RAISE EXCEPTION
            'Sprachkarte unterschreitet die Mindestlänge % bei den Sprachen: %',
            p_minimum_length, array_to_string(too_short_languages, ', ')
            USING ERRCODE = '23514';
    END IF;
END;
$$;

COMMENT ON FUNCTION pm.validate_partial_language_map(jsonb, integer) IS
    'Wie pm.validate_nonempty_language_map(), aber OHNE die Pflichtsprachen-'
    'Vollständigkeitsprüfung. Ausschließlich für pm.issues.title/description '
    'im Zustand inbox (§7.6, "Sprachen im Eingang").';

CREATE FUNCTION pm.validate_issue_language_maps()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.state = 'inbox' THEN
        PERFORM pm.validate_partial_language_map(NEW.title, 2);
        PERFORM pm.validate_partial_language_map(NEW.description, 2);
    ELSE
        PERFORM pm.validate_nonempty_language_map(NEW.title, 2);
        PERFORM pm.validate_nonempty_language_map(NEW.description, 2);
    END IF;

    PERFORM pm.validate_language_map(NEW.blocker_reason, true);
    PERFORM pm.validate_language_map(NEW.implementation_notes, true);

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.validate_issue_language_maps() IS
    'title/description: im Zustand inbox genügt eine Sprache, sonst gilt '
    'P-005 vollständig (§7.6, "Sprachen im Eingang"). blocker_reason/'
    'implementation_notes: vollständige Sprachkarte, wenn vorhanden '
    '(allow_null = true) — die Anwesenheitspflicht von blocker_reason in '
    'blockiert prüft pm.enforce_issue_field_thresholds() separat.';

CREATE TRIGGER issues_validate_language_maps
    BEFORE INSERT OR UPDATE OF
        title, description, state, blocker_reason, implementation_notes
    ON pm.issues
    FOR EACH ROW
    EXECUTE FUNCTION pm.validate_issue_language_maps();

-- ---------------------------------------------------------------------
-- Abschlusskriterien: geschlossenes Schema und Pflicht ab bereit bei
-- feature/bug.
-- ---------------------------------------------------------------------

CREATE FUNCTION pm.validate_issue_criteria()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_entry      jsonb;
    v_key        text;
    v_seen_keys  text[] := '{}';
BEGIN
    FOR v_entry IN SELECT * FROM jsonb_array_elements(NEW.criteria)
    LOOP
        IF jsonb_typeof(v_entry) <> 'object' THEN
            RAISE EXCEPTION 'Abschlusskriterium muss ein JSON-Objekt sein: %', v_entry
                USING ERRCODE = '23514';
        END IF;

        IF NOT (v_entry ? 'schluessel')
           OR NOT (v_entry ? 'text')
           OR NOT (v_entry ? 'stand')
        THEN
            RAISE EXCEPTION
                'Abschlusskriterium benötigt schluessel, text und stand: %', v_entry
                USING ERRCODE = '23514';
        END IF;

        -- Schließt das Schema: keine Felder außer den drei erlaubten.
        IF (v_entry - 'schluessel' - 'text' - 'stand') <> '{}'::jsonb THEN
            RAISE EXCEPTION 'Abschlusskriterium enthält unbekannte Felder: %', v_entry
                USING ERRCODE = '23514';
        END IF;

        IF jsonb_typeof(v_entry->'schluessel') <> 'string' THEN
            RAISE EXCEPTION 'Abschlusskriterium.schluessel muss eine Zeichenkette sein: %', v_entry
                USING ERRCODE = '23514';
        END IF;

        v_key := btrim(v_entry->>'schluessel');
        IF v_key = '' OR v_key !~ '^[A-Za-z0-9_-]+$' THEN
            RAISE EXCEPTION
                'Abschlusskriterium.schluessel hat ein ungültiges Format: %',
                v_entry->>'schluessel'
                USING ERRCODE = '23514';
        END IF;
        IF v_entry->>'schluessel' <> v_key THEN
            RAISE EXCEPTION
                'Abschlusskriterium.schluessel muss bereits getrimmt gespeichert werden: %',
                v_entry->>'schluessel'
                USING ERRCODE = '23514';
        END IF;
        IF v_key = ANY(v_seen_keys) THEN
            RAISE EXCEPTION
                'Abschlusskriterium.schluessel % ist innerhalb der Punktfolge nicht eindeutig',
                v_key
                USING ERRCODE = '23514';
        END IF;
        v_seen_keys := array_append(v_seen_keys, v_key);

        IF jsonb_typeof(v_entry->'stand') <> 'string'
           OR v_entry->>'stand' NOT IN ('open', 'fulfilled')
        THEN
            RAISE EXCEPTION 'Abschlusskriterium.stand muss open oder fulfilled sein: %', v_entry
                USING ERRCODE = '23514';
        END IF;

        PERFORM pm.validate_nonempty_language_map(v_entry->'text', 1);
    END LOOP;

    IF NEW.ready_threshold_reached
       AND NEW.issue_kind IN ('feature', 'bug')
       AND jsonb_array_length(NEW.criteria) = 0
    THEN
        RAISE EXCEPTION
            'Vorgangsart % verlangt ab bereit mindestens ein Abschlusskriterium',
            NEW.issue_kind
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.validate_issue_criteria() IS
    'Prüft das geschlossene Schema jedes Eintrags von pm.issues.criteria '
    '(§7.6, "Schema des dynamischen Feldes"): genau schluessel/text/stand, '
    'schluessel formatgeprüft und innerhalb der Punktfolge eindeutig, stand '
    'typgeprüft. Erzwingt ab bereit mindestens ein Kriterium bei issue_kind '
    'IN (feature, bug).';

CREATE TRIGGER issues_validate_criteria
    BEFORE INSERT OR UPDATE OF criteria, state, issue_kind
    ON pm.issues
    FOR EACH ROW
    EXECUTE FUNCTION pm.validate_issue_criteria();

-- ---------------------------------------------------------------------
-- issue_kind_locked, übrige Pflicht-ab-bereit-Felder (issue_kind, urgency),
-- blocker_reason- und finished_at-Pflicht. scope bewusst NICHT hier —
-- siehe den verzögerten Constraint-Trigger weiter unten.
-- ---------------------------------------------------------------------

CREATE FUNCTION pm.enforce_issue_field_thresholds()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE'
       AND OLD.issue_kind_locked
       AND NEW.issue_kind IS DISTINCT FROM OLD.issue_kind
    THEN
        RAISE EXCEPTION
            'issue_kind ist seit dem ersten Erreichen von in_progress unveränderlich'
            USING ERRCODE = '23514';
    END IF;

    -- Beide Spalten sind monoton: einmal wahr, bleiben sie wahr (Regel 6,
    -- "Rückwege löschen nichts"). Ignorieren einen extern gesetzten Wert vollständig
    -- — editor besitzt ohnehin kein UPDATE-Recht auf diese Spalten (siehe
    -- GRANTs).
    NEW.issue_kind_locked :=
        (TG_OP = 'UPDATE' AND OLD.issue_kind_locked)
        OR NEW.state = 'in_progress';
    NEW.ready_threshold_reached :=
        (TG_OP = 'UPDATE' AND OLD.ready_threshold_reached)
        OR pm.issue_state_meets_ready_threshold(NEW.state);

    IF NEW.ready_threshold_reached THEN
        IF NEW.issue_kind IS NULL THEN
            RAISE EXCEPTION 'issue_kind ist ab bereit Pflicht'
                USING ERRCODE = '23514';
        END IF;
        IF NEW.urgency IS NULL THEN
            RAISE EXCEPTION 'urgency ist ab bereit Pflicht'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    IF NEW.state = 'blocked' AND NEW.blocker_reason IS NULL THEN
        RAISE EXCEPTION 'blocker_reason ist in blockiert Pflicht'
            USING ERRCODE = '23514';
    END IF;
    IF NEW.state <> 'blocked' AND NEW.blocker_reason IS NOT NULL THEN
        RAISE EXCEPTION 'blocker_reason ist außerhalb von blockiert unzulässig'
            USING ERRCODE = '23514';
    END IF;

    IF NEW.state IN ('done', 'discarded') AND NEW.finished_at IS NULL THEN
        RAISE EXCEPTION 'finished_at ist in % Pflicht', NEW.state
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.enforce_issue_field_thresholds() IS
    '§7.6: issue_kind_locked (dauerhaft, ab in_progress), Pflicht-ab-bereit '
    'für issue_kind/urgency, blocker_reason- und finished_at-Pflicht je '
    'Zustand. scope-Pflicht läuft verzögert, siehe unten.';

CREATE TRIGGER issues_enforce_field_thresholds
    BEFORE INSERT OR UPDATE OF
        state, issue_kind, urgency, blocker_reason, finished_at
    ON pm.issues
    FOR EACH ROW
    EXECUTE FUNCTION pm.enforce_issue_field_thresholds();

-- ---------------------------------------------------------------------
-- Hierarchie, Teil 1 (unmittelbar): Zyklenfreiheit (Regel 3) und
-- Kindart-Kompatibilität (Regel 2) gegenüber dem bestehenden Elternvorgang
-- UND den bestehenden eigenen Kindern. Erlaubte Eltern-/Kindart-
-- Kombinationen als verwaltete Tabelle, wie pm.relation_type_endpoints
-- statt eines Enums.
-- ---------------------------------------------------------------------

CREATE TABLE pm.issue_hierarchy_rules (
    parent_kind text NOT NULL,
    child_kind  text NOT NULL,
    PRIMARY KEY (parent_kind, child_kind)
);

COMMENT ON TABLE pm.issue_hierarchy_rules IS
    'Erlaubte Elternart -> Kindart-Kombinationen (§7.6, Regel 2). Eine '
    'Vorgangsart ohne Zeile als parent_kind darf keine Kinder haben; eine '
    'Vorgangsart, die in keiner Zeile als child_kind auftritt (epic), darf '
    'selbst kein Elternvorgang haben.';

INSERT INTO pm.issue_hierarchy_rules (parent_kind, child_kind) VALUES
    ('epic', 'feature'),
    ('epic', 'bug'),
    ('epic', 'task'),
    ('epic', 'maintenance'),
    ('feature', 'bug'),
    ('feature', 'task'),
    ('feature', 'maintenance');

CREATE FUNCTION pm.prevent_issue_hierarchy_cycle()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.parent_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        WITH RECURSIVE ancestors (id, parent_id) AS (
            SELECT i.id, i.parent_id
              FROM pm.issues AS i
             WHERE i.id = NEW.parent_id

            UNION ALL

            SELECT i.id, i.parent_id
              FROM pm.issues AS i
              JOIN ancestors AS a ON i.id = a.parent_id
        )
        SELECT 1 FROM ancestors WHERE id = NEW.id
    ) THEN
        RAISE EXCEPTION
            'Vorgang % kann nicht Vorfahre seines eigenen Elternvorgangs % werden (Zyklus)',
            NEW.id, NEW.parent_id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.prevent_issue_hierarchy_cycle() IS
    'Verhindert mehrgliedrige Zyklen in pm.issues.parent_id (§7.6, Regel 3).';

CREATE TRIGGER issues_prevent_hierarchy_cycle
    BEFORE INSERT OR UPDATE OF parent_id
    ON pm.issues
    FOR EACH ROW
    EXECUTE FUNCTION pm.prevent_issue_hierarchy_cycle();

CREATE FUNCTION pm.enforce_issue_hierarchy_rules()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_parent_kind text;
    v_child       record;
BEGIN
    -- Gegenüber dem eigenen (ggf. neuen) Elternvorgang. Ohne festgelegte
    -- eigene Vorgangsart lässt sich Regel 2 nicht prüfen (issue_kind ist
    -- erst ab bereit Pflicht, kann aber schon vorher gesetzt sein) — bis
    -- dahin wird die Kombination nicht geprüft.
    IF NEW.parent_id IS NOT NULL AND NEW.issue_kind IS NOT NULL THEN
        SELECT issue_kind INTO v_parent_kind
          FROM pm.issues WHERE id = NEW.parent_id;

        IF v_parent_kind IS NULL THEN
            RAISE EXCEPTION
                'Elternvorgang % hat noch keine festgelegte Vorgangsart', NEW.parent_id
                USING ERRCODE = '23514';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM pm.issue_hierarchy_rules
             WHERE parent_kind = v_parent_kind AND child_kind = NEW.issue_kind
        ) THEN
            RAISE EXCEPTION
                'Vorgangsart % erlaubt keine Kindart %', v_parent_kind, NEW.issue_kind
                USING ERRCODE = '23514';
        END IF;
    END IF;

    -- Gegenüber den eigenen bestehenden Kindern: nur relevant, wenn sich die
    -- eigene issue_kind ändert (ein reiner parent_id-Wechsel dieses
    -- Vorgangs betrifft dessen Kinder nicht).
    IF TG_OP = 'UPDATE'
       AND NEW.issue_kind IS DISTINCT FROM OLD.issue_kind
       AND NEW.issue_kind IS NOT NULL
    THEN
        FOR v_child IN SELECT id, issue_kind FROM pm.issues WHERE parent_id = NEW.id
        LOOP
            IF v_child.issue_kind IS NOT NULL AND NOT EXISTS (
                SELECT 1 FROM pm.issue_hierarchy_rules
                 WHERE parent_kind = NEW.issue_kind AND child_kind = v_child.issue_kind
            ) THEN
                RAISE EXCEPTION
                    'Vorgangsart % erlaubt Kindvorgang % (Art %) nicht mehr',
                    NEW.issue_kind, v_child.id, v_child.issue_kind
                    USING ERRCODE = '23514';
            END IF;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.enforce_issue_hierarchy_rules() IS
    '§7.6, Regel 2: erlaubte Eltern-/Kindart-Kombination, geprüft sowohl '
    'gegenüber dem eigenen Elternvorgang als auch gegenüber allen '
    'bestehenden eigenen Kindern (bei Änderung der eigenen Vorgangsart).';

CREATE TRIGGER issues_enforce_hierarchy_rules
    BEFORE INSERT OR UPDATE OF parent_id, issue_kind
    ON pm.issues
    FOR EACH ROW
    EXECUTE FUNCTION pm.enforce_issue_hierarchy_rules();

-- ---------------------------------------------------------------------
-- Verzögerte, tabellenübergreifende Prüfungen (siehe Kopf): Umfang-Pflicht
-- bei scope_mode = weighted, gemeinsames Projekt zwischen Eltern- und
-- Kindvorgang (Regel 4). Beide Prüffunktionen nehmen eine object_id/
-- issue_id entgegen und lesen den aktuellen (innerhalb der Transaktion
-- bereits sichtbaren) Stand neu — deshalb sind sie unabhängig von der
-- Reihenfolge der auslösenden Anweisungen korrekt, solange die Constraint-
-- Trigger DEFERRABLE INITIALLY DEFERRED sind.
-- ---------------------------------------------------------------------

CREATE FUNCTION pm.check_issue_scope_threshold(p_issue_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_ready_threshold_reached boolean;
    v_scope                  text;
    v_scope_mode              text;
BEGIN
    SELECT ready_threshold_reached, scope
      INTO v_ready_threshold_reached, v_scope
      FROM pm.issues WHERE id = p_issue_id;

    IF NOT FOUND OR NOT v_ready_threshold_reached THEN
        RETURN;
    END IF;

    SELECT p.scope_mode
      INTO v_scope_mode
      FROM pm.object_projects AS op
      JOIN pm.projects AS p ON p.id = op.project_id
     WHERE op.object_id = p_issue_id;

    IF v_scope_mode = 'weighted' AND v_scope IS NULL THEN
        RAISE EXCEPTION
            'Vorgang % benötigt ab bereit einen Umfang (Projekt ist scope_mode = weighted)',
            p_issue_id
            USING ERRCODE = '23514';
    END IF;
END;
$$;

COMMENT ON FUNCTION pm.check_issue_scope_threshold(uuid) IS
    'Umfang-Pflicht ab bereit bei scope_mode = weighted (§7.6). Liest den '
    'aktuellen Stand neu, no-op wenn das Objekt (noch) keine Vorgangszeile '
    'oder (noch) kein Projekt hat.';

CREATE FUNCTION pm.check_issue_parent_project_match(p_issue_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_parent_id      uuid;
    v_own_project    uuid;
    v_parent_project uuid;
BEGIN
    SELECT parent_id INTO v_parent_id FROM pm.issues WHERE id = p_issue_id;

    IF NOT FOUND OR v_parent_id IS NULL THEN
        RETURN;
    END IF;

    SELECT project_id INTO v_own_project
      FROM pm.object_projects WHERE object_id = p_issue_id;
    SELECT project_id INTO v_parent_project
      FROM pm.object_projects WHERE object_id = v_parent_id;

    IF v_own_project IS NOT NULL
       AND v_parent_project IS NOT NULL
       AND v_own_project <> v_parent_project
    THEN
        RAISE EXCEPTION
            'Vorgang % und sein Elternvorgang % gehören nicht demselben Projekt an',
            p_issue_id, v_parent_id
            USING ERRCODE = '23514';
    END IF;
END;
$$;

COMMENT ON FUNCTION pm.check_issue_parent_project_match(uuid) IS
    'Eltern- und Kindvorgang im selben Projekt (§7.6, Regel 4), geprüft aus '
    'Sicht des Kindvorgangs p_issue_id.';

CREATE FUNCTION pm.check_issue_children_project_match(p_issue_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_child_id uuid;
BEGIN
    FOR v_child_id IN SELECT id FROM pm.issues WHERE parent_id = p_issue_id
    LOOP
        PERFORM pm.check_issue_parent_project_match(v_child_id);
    END LOOP;
END;
$$;

COMMENT ON FUNCTION pm.check_issue_children_project_match(uuid) IS
    'Ruft pm.check_issue_parent_project_match() für jeden unmittelbaren '
    'Kindvorgang von p_issue_id auf — für den Fall, dass sich p_issue_id '
    'selbst das Projekt ändert.';

-- pm.issues: state oder scope selbst geändert (z. B. scope auf NULL gesetzt
-- oder state erreicht erstmals die Schwelle). Ohne diesen Trigger würde nur
-- eine Änderung an pm.object_projects/pm.projects die Prüfung auslösen,
-- nicht eine Änderung an pm.issues selbst.
CREATE FUNCTION pm.issues_check_scope_threshold_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pm.check_issue_scope_threshold(NEW.id);
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER issues_enforce_scope_threshold
    AFTER INSERT OR UPDATE OF state, scope ON pm.issues
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION pm.issues_check_scope_threshold_trigger();

-- pm.issues: neuer/geänderter Elternbezug dieses Vorgangs.
CREATE FUNCTION pm.issues_check_parent_project_match_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pm.check_issue_parent_project_match(NEW.id);
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER issues_enforce_parent_project_match
    AFTER INSERT OR UPDATE OF parent_id ON pm.issues
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION pm.issues_check_parent_project_match_trigger();

-- pm.object_projects: Umfang-Schwelle UND Projektgleichheit für das
-- betroffene Objekt selbst (falls Elternvorgang vorhanden) sowie für alle
-- seine Kinder (falls es selbst Elternvorgang ist) — ein Umhängen kann
-- beide Richtungen brechen. Läuft für JEDE Objektart (pm.object_projects
-- ist die generische Zuordnungstabelle); pm.check_issue_scope_threshold()/
-- pm.check_issue_parent_project_match() sind für Nicht-Vorgänge ein No-op
-- (NOT FOUND in pm.issues).
CREATE FUNCTION pm.object_projects_check_issue_rules_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pm.check_issue_scope_threshold(NEW.object_id);
    PERFORM pm.check_issue_parent_project_match(NEW.object_id);
    PERFORM pm.check_issue_children_project_match(NEW.object_id);
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER object_projects_enforce_issue_rules
    AFTER INSERT OR UPDATE OF project_id ON pm.object_projects
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION pm.object_projects_check_issue_rules_trigger();

-- pm.projects: ein Wechsel von scope_mode kann rückwirkend Vorgänge ohne
-- scope ungültig machen. Prüft alle Vorgänge, die diesem Projekt
-- unmittelbar zugeordnet sind.
CREATE FUNCTION pm.projects_check_issue_scope_threshold_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_object_id uuid;
BEGIN
    FOR v_object_id IN
        SELECT op.object_id FROM pm.object_projects AS op WHERE op.project_id = NEW.id
    LOOP
        PERFORM pm.check_issue_scope_threshold(v_object_id);
    END LOOP;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER projects_enforce_issue_scope_threshold
    AFTER UPDATE OF scope_mode ON pm.projects
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION pm.projects_check_issue_scope_threshold_trigger();

-- ---------------------------------------------------------------------
-- Identität, updated_at.
-- ---------------------------------------------------------------------

CREATE FUNCTION pm.prevent_issue_identity_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id THEN
        RAISE EXCEPTION 'pm.issues.id darf nicht geändert werden'
            USING ERRCODE = '23514';
    END IF;
    IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'pm.issues.created_at darf nicht geändert werden'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.prevent_issue_identity_change() IS
    'Verhindert Änderungen an pm.issues.id und .created_at.';

CREATE TRIGGER issues_prevent_identity_change
    BEFORE UPDATE OF id, created_at
    ON pm.issues
    FOR EACH ROW
    EXECUTE FUNCTION pm.prevent_issue_identity_change();

CREATE TRIGGER issues_set_updated_at
    BEFORE UPDATE
    ON pm.issues
    FOR EACH ROW
    EXECUTE FUNCTION pm.set_updated_at();

-- PostgreSQL legt für referenzierende Fremdschlüsselspalten keinen Index
-- automatisch an.
CREATE INDEX issues_parent_id_idx
    ON pm.issues(parent_id);

-- ---------------------------------------------------------------------
-- depends_on-Endpunkt issue -> issue (§8.2). Zyklenprüfung (global) und
-- Projektfreiheit sind bereits generisch in 007_object_relations.sql
-- vorhanden — hier nur die Endpunktzeile selbst.
-- ---------------------------------------------------------------------

INSERT INTO pm.relation_type_endpoints (
    relation_type, source_type, target_type,
    max_targets_per_source, max_sources_per_target
) VALUES ('depends_on', 'issue', 'issue', NULL, NULL);

-- ---------------------------------------------------------------------
-- Rechte. editor erhält bewusst KEIN UPDATE-Recht auf state oder
-- issue_kind_locked (siehe Kopf bzw. Spaltenkommentar). id/created_at sind
-- ohnehin durch den Identitäts-Trigger geschützt, werden hier aber
-- zusätzlich nicht freigegeben. Kein DELETE für editor: object_relations/
-- object_origins/state_history verweisen mit ON DELETE RESTRICT auf
-- object_registry, ein Vorgang mit Verlauf oder Beziehungen ist damit
-- ohnehin geschützt; ein Vorgang OHNE solche Bindungen ließe sich sonst
-- unkontrolliert löschen, was für eine Fachart mit Verlaufspflicht (P-010)
-- nicht gewünscht ist.
GRANT SELECT, INSERT
    ON pm.issues
    TO editor;
GRANT UPDATE (
    title, description, urgency, scope, criteria, parent_id,
    blocker_reason, implementation_notes, started_at, finished_at
)
    ON pm.issues
    TO editor;

GRANT SELECT
    ON pm.issues
    TO reader;

GRANT SELECT
    ON pm.issue_hierarchy_rules
    TO editor, reader;

RESET ROLE;
