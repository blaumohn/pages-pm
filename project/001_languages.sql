-- Pages-PM-spezifische Projektkonfiguration, keine Schema-Migration.
-- Muss nach migrations/002_languages.sql laufen und wird als migrator
-- ausgeführt. Die nötigen Rechte werden dort unmittelbar auf pm.languages
-- vergeben.
--
-- Für dieses Repository sind Deutsch und Englisch beide Pflichtsprachen.
-- Ein anderes Projekt, das dieses Schema wiederverwendet, kann stattdessen
-- eine eigene project/001_languages.sql mit anderen Sprachen einsetzen.

INSERT INTO pm.languages (code, autonym, is_required) VALUES
    ('de', 'Deutsch', true),
    ('en', 'English', true);
