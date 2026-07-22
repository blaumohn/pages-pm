-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Sprachkonfiguration und zentrale Prüffunktion für alle Sprachkarten-Spalten
-- im System (pm.areas.title/description, pm.relation_types.title/description,
-- später fachliche Felder wie pm.sprints.goal).
--
-- Diese Migration muss vor allen Migrationen ausgeführt werden, die
-- pm.validate_language_map() verwenden. Sie muss insbesondere vor
-- 004_areas.sql und 006_relation_types.sql laufen.
--
-- Zwei Ebenen pro Sprache: konfiguriert (Zeile in pm.languages vorhanden)
-- und verpflichtend (is_required). Bewusst KEINE Standardsprache: Pages PM
-- braucht kein automatisches Sprach-Fallback in den Daten. Alle
-- Pflichtsprachen sind gleichrangig. Eine Anzeige- oder Vorzugssprache ist
-- Sache der Anfrage beziehungsweise des Benutzers (Benutzereinstellung,
-- Accept-Language, CLI-Parameter), keine Eigenschaft von pm.languages.
--
-- Diese Unterscheidung (konfiguriert vs. verpflichtend) erlaubt, eine neue
-- Sprache zunächst optional einzuführen, bestehende Inhalte nachzuziehen und
-- sie erst danach zur Pflicht zu machen.
--
-- Diese Kernmigration legt bewusst noch keine Sprachen fest. Deutsch und
-- Englisch sind Eigenschaften der konkreten Pages-PM-Installation, nicht
-- des Kernschemas. Sie werden nach dieser Migration durch
-- project/001_languages.sql ergänzt. Ein anderes Projekt kann stattdessen
-- eine eigene Projektkonfiguration mit anderen Sprachen verwenden.
--
-- pm.languages wird nur durch kontrollierte Schema-Migrationen oder
-- Projektkonfiguration verändert, nicht durch die gewöhnliche Anwendung.
-- Änderungen an der Sprachliste können bestehende Sprachkarten ungültig
-- machen. Eine eigene Verwaltungsfunktion ist noch nicht Teil dieses Standes.

SET ROLE schema_owner;

CREATE TABLE pm.languages (
    code        text    PRIMARY KEY,
    autonym     text    NOT NULL,
    is_required boolean NOT NULL DEFAULT true,

    CONSTRAINT languages_code_has_valid_format
        CHECK (code ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),

    CONSTRAINT languages_autonym_not_blank
        CHECK (
            btrim(autonym) <> ''
            AND autonym = btrim(autonym)
        )
);

COMMENT ON TABLE pm.languages IS
    'Systemweite Sprachkonfiguration. Änderungen erfolgen zunächst nur durch '
    'kontrollierte Schema-Migrationen: neue Sprache optional anlegen, Inhalte '
    'ergänzen, Vollständigkeit prüfen und erst danach zur Pflichtsprache machen.';
COMMENT ON COLUMN pm.languages.autonym IS
    'Eigenbezeichnung der Sprache in sich selbst (z. B. "Deutsch", "English") — '
    'bewusst kein fachlicher Text, der selbst wieder übersetzt werden müsste, '
    'sonst entstünde eine rekursive Sprachkarte für die Sprachliste selbst.';
COMMENT ON COLUMN pm.languages.is_required IS
    'Wenn wahr, muss jede Sprachkarte im System diesen Sprachcode enthalten '
    '(geprüft durch pm.validate_language_map()). Pflichtsprachen sind '
    'gleichrangig; Pages PM definiert bewusst keine Standardsprache.';

-- Keine Sprachen in dieser Kernmigration — siehe project/001_languages.sql.

-- Gemeinsame Prüfung für alle Sprachkarten-Spalten im System. p_allow_null
-- erlaubt optionale Felder wie pm.areas.description.
CREATE FUNCTION pm.validate_language_map(
    p_value      jsonb,
    p_allow_null boolean DEFAULT false
) RETURNS void
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    missing_languages text[];
    unknown_languages text[];
BEGIN
    IF p_value IS NULL THEN
        IF p_allow_null THEN
            RETURN;
        END IF;
        RAISE EXCEPTION 'Sprachkarte darf nicht NULL sein'
            USING ERRCODE = '23514';
    END IF;

    IF jsonb_typeof(p_value) <> 'object'
       OR p_value = '{}'::jsonb
    THEN
        RAISE EXCEPTION 'Sprachkarte muss ein nicht leeres JSON-Objekt sein'
            USING ERRCODE = '23514';
    END IF;

    IF jsonb_path_exists(p_value, '$.* ? (@.type() != "string")') THEN
        RAISE EXCEPTION 'Alle Werte einer Sprachkarte müssen Zeichenketten sein'
            USING ERRCODE = '23514';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM jsonb_each_text(p_value) AS entry(code, text_value)
         WHERE btrim(entry.text_value) = ''
    ) THEN
        RAISE EXCEPTION 'Sprachkarte darf keine leeren Textwerte enthalten'
            USING ERRCODE = '23514';
    END IF;

    SELECT array_agg(l.code ORDER BY l.code) INTO missing_languages
      FROM pm.languages l
     WHERE l.is_required AND NOT p_value ? l.code;

    IF missing_languages IS NOT NULL THEN
        RAISE EXCEPTION 'Sprachkarte enthält nicht alle Pflichtsprachen: %', missing_languages
            USING ERRCODE = '23514';
    END IF;

    SELECT array_agg(entry.code ORDER BY entry.code) INTO unknown_languages
      FROM jsonb_object_keys(p_value) AS entry(code)
     WHERE NOT EXISTS (SELECT 1 FROM pm.languages l WHERE l.code = entry.code);

    IF unknown_languages IS NOT NULL THEN
        RAISE EXCEPTION 'Sprachkarte enthält unbekannte Sprachen: %', unknown_languages
            USING ERRCODE = '23514';
    END IF;
END;
$$;

COMMENT ON FUNCTION pm.validate_language_map IS
    'Prüft Form (nicht leeres Objekt, nur Zeichenketten, keine reinen Leerraumwerte), '
    'Pflichtsprachen-Vollständigkeit und Abwesenheit unbekannter Sprachcodes.';

-- Die Sprachkonfiguration ist kein gewöhnliches Fachdatum.
-- migrator darf sie unmittelbar verwalten; editor und reader dürfen
-- sie nur lesen.
GRANT SELECT, INSERT, UPDATE, DELETE ON pm.languages TO migrator;
GRANT SELECT ON pm.languages TO editor, reader;

RESET ROLE;
