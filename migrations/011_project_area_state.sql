-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Zieht Projekt und Bereich (§7.4, Rahmen: Projekt / Rahmen: Bereich) auf
-- Fassung 7 nach: beiden Rahmen fehlte bisher der Zustand, dem Projekt
-- zusätzlich die Umfangsangabe.
--
-- Zustandswerte als englische technische Token, wie bereits bei
-- pm.kep_lites.status (010_kep_lites.sql, Branch wip/kep-lite) gehandhabt:
--   Projekt   aktiv->active, ruhend->dormant, abgeschlossen->closed
--   Bereich   aktiv->active, überholt->deprecated
--   Umfangsangabe   gewichtet->weighted, nicht gewichtet->unweighted
--
-- Beide Spalten sind NOT NULL ohne DEFAULT (§7.1.1, Regel 4: kein Vorgabewert
-- für eine Angabe, die ein Urteil ausdrückt). Zum Zeitpunkt dieser Migration
-- enthalten pm.projects und pm.areas noch keine Zeilen — die anfängliche
-- Projektstruktur (project/003_projects.sql) läuft absichtlich erst danach,
-- damit sie die neuen Spalten von Anfang an mit echten Werten füllen kann,
-- statt sie nachträglich aufzufüllen.
--
-- Prüfregel "ein Projekt im Zustand abgeschlossen nimmt keine neuen
-- Fachgegenstände auf": ein Trigger auf pm.object_projects prüft beim
-- Zuordnen (INSERT) und beim Umhängen (UPDATE OF project_id) den Zustand des
-- Ziel-Projekts.

SET ROLE schema_owner;

-- Die beiden neuen Spalten sind NOT NULL ohne DEFAULT und setzen daher leere
-- Tabellen voraus (siehe oben). Für den jetzigen Arbeitsbaum stimmt das,
-- weil project/003_projects.sql erst nach dieser Migration läuft — aber ohne
-- diesen Vorabtest würde eine künftig verschobene Reihenfolge oder ein
-- bereits befüllter Arbeitsbaum mit einer wenig erklärenden technischen
-- Fehlermeldung an der NOT-NULL-Bedingung scheitern, statt mit einer klaren
-- Meldung an dieser Stelle.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pm.projects)
       OR EXISTS (SELECT 1 FROM pm.areas)
    THEN
        RAISE EXCEPTION
            '011_project_area_state.sql verlangt leere Projekt- und Bereichstabellen';
    END IF;
END;
$$;

ALTER TABLE pm.projects
    ADD COLUMN state text NOT NULL,
    ADD COLUMN scope_mode text NOT NULL,
    ADD CONSTRAINT projects_state_is_valid
        CHECK (state IN ('active', 'dormant', 'closed')),
    ADD CONSTRAINT projects_scope_mode_is_valid
        CHECK (scope_mode IN ('weighted', 'unweighted'));

COMMENT ON COLUMN pm.projects.state IS
    'Zustand des Projekts (§7.4): active (aktiv), dormant (ruhend) oder '
    'closed (abgeschlossen). Kein Vorgabewert. closed blockiert die '
    'Neuzuordnung von Fachgegenständen (pm.prevent_object_assignment_to_closed_project).';
COMMENT ON COLUMN pm.projects.scope_mode IS
    'Umfangsangabe (§7.4): weighted (gewichtet, Vorgänge tragen einen Umfang) '
    'oder unweighted (nicht gewichtet, reine Abzählung). Kein Vorgabewert.';

ALTER TABLE pm.areas
    ADD COLUMN state text NOT NULL,
    ADD CONSTRAINT areas_state_is_valid
        CHECK (state IN ('active', 'deprecated'));

COMMENT ON COLUMN pm.areas.state IS
    'Zustand des Bereichs (§7.4): active (aktiv) oder deprecated (überholt). '
    'Kein Vorgabewert.';

-- Ein Projekt im Zustand closed nimmt keine neuen Fachgegenstände auf —
-- weder als erstmalige Zuordnung noch als Umhängen aus einem anderen
-- Projekt. Bereits zugeordnete Objekte bleiben unangetastet: die Regel
-- verlangt keinen Rückzug, nur eine Sperre für Neuzugänge.
CREATE FUNCTION pm.prevent_object_assignment_to_closed_project()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_state text;
BEGIN
    SELECT p.state
      INTO v_state
      FROM pm.projects AS p
     WHERE p.id = NEW.project_id;

    IF v_state = 'closed' THEN
        RAISE EXCEPTION
            'Projekt % ist abgeschlossen und nimmt keine neuen Fachgegenstände auf',
            NEW.project_id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.prevent_object_assignment_to_closed_project() IS
    '§7.4, Rahmen Projekt, Prüfregeln: ein Projekt im Zustand closed nimmt '
    'keine neuen Fachgegenstände auf. Prüft sowohl die erstmalige Zuordnung '
    '(INSERT) als auch das Umhängen (UPDATE OF project_id).';

CREATE TRIGGER object_projects_prevent_assignment_to_closed_project
    BEFORE INSERT OR UPDATE OF project_id
    ON pm.object_projects
    FOR EACH ROW
    EXECUTE FUNCTION pm.prevent_object_assignment_to_closed_project();

RESET ROLE;
