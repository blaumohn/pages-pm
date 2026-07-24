-- Läuft als migrator und wechselt für diese Migration zu schema_owner.
--
-- Gemeinsame Hilfsfunktionen für die Fachtabellen aus Phase B (ab 009):
-- Prüfung von Sprachkarten mit Mindestlänge je vorhandenem Sprachwert und
-- gemeinsamer updated_at-Trigger. Diese Migration legt keine Tabelle an.

SET ROLE schema_owner;

-- Ergänzt pm.validate_language_map() um eine Mindestlänge je vorhandenem
-- Sprachwert nach btrim(). Für Pflichttexte wie pm.sprints.goal oder
-- pm.issues.title, bei denen eine formal gültige, aber inhaltsleere oder
-- zu kurze Sprachkarte fachlich nicht ausreicht.
--
-- RETURNS void und löst bei Verletzung eine Ausnahme aus, wie
-- pm.validate_language_map(). Kann deshalb NICHT unmittelbar in einer
-- CHECK-Bedingung verwendet werden (CHECK braucht einen booleschen
-- Ausdruck) — jede Fachtabelle ruft sie stattdessen aus einem eigenen
-- BEFORE INSERT OR UPDATE-Prüftrigger per PERFORM auf, genau wie die
-- bestehenden validate_area_language_maps()/validate_object_relation_
-- language_maps()-Trigger pm.validate_language_map() aufrufen.
CREATE FUNCTION pm.validate_nonempty_language_map(
    p_value          jsonb,
    p_minimum_length integer,
    p_allow_null     boolean DEFAULT false
) RETURNS void
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    too_short_languages text[];
BEGIN
    IF p_minimum_length IS NULL OR p_minimum_length < 1 THEN
        RAISE EXCEPTION
            'p_minimum_length muss mindestens 1 sein'
            USING ERRCODE = '22023';
    END IF;

    PERFORM pm.validate_language_map(p_value, p_allow_null);

    IF p_value IS NULL THEN
        RETURN;
    END IF;

    SELECT array_agg(entry.code ORDER BY entry.code)
      INTO too_short_languages
      FROM jsonb_each_text(p_value) AS entry(code, text_value)
     WHERE length(btrim(entry.text_value)) < p_minimum_length;

    IF too_short_languages IS NOT NULL THEN
        RAISE EXCEPTION
            'Sprachkarte unterschreitet die Mindestlänge % '
            'bei den Sprachen: %',
            p_minimum_length,
            array_to_string(too_short_languages, ', ')
            USING ERRCODE = '23514';
    END IF;
END;
$$;

COMMENT ON FUNCTION pm.validate_nonempty_language_map(
    jsonb,
    integer,
    boolean
) IS
    'Wie pm.validate_language_map(), zusätzlich muss jeder vorhandene '
    'Sprachwert nach btrim() mindestens p_minimum_length Zeichen besitzen. '
    'p_allow_null übernimmt dieselbe Bedeutung wie in validate_language_map(). '
    'RETURNS void und löst bei Verletzung eine Ausnahme aus — daher nicht in '
    'CHECK-Bedingungen verwendbar, sondern per PERFORM in einem eigenen '
    'BEFORE INSERT OR UPDATE-Prüftrigger je Fachtabelle.';

-- Gemeinsamer BEFORE-UPDATE-Trigger für Fachtabellen mit updated_at.
-- editor erhält auf updated_at kein eigenes UPDATE-Recht (siehe GRANTs der
-- jeweiligen Fachtabellenmigration). Der Trigger setzt den Wert bei jeder
-- zulässigen Änderung selbst und ignoriert dabei einen gegebenenfalls von
-- höher berechtigten Rollen übergebenen Wert.
CREATE FUNCTION pm.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := statement_timestamp();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pm.set_updated_at() IS
    'BEFORE-UPDATE-Triggerfunktion für Fachtabellen mit updated_at; '
    'setzt NEW.updated_at stets auf statement_timestamp().';

RESET ROLE;
