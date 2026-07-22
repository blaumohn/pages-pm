-- Einmalige Einrichtung der Rollen und des Migrationsverzeichnisses.
-- Läuft als PostgreSQL-Superuser. Nicht idempotent, absichtlich: ein bereits
-- vorhandenes Objekt soll einen klaren Fehler geben, kein stilles Überspringen.
-- Passwörter werden hier NICHT gesetzt (siehe Hinweis am Dateiende).

CREATE ROLE schema_owner
    NOLOGIN;

CREATE ROLE migrator
    LOGIN
    NOINHERIT;

-- Jede Mitgliedschaftsoption braucht ein eigenes GRANT (PostgreSQL erlaubt
-- pro Anweisung nur eine WITH-Option). Ein erneutes GRANT ändert dieselbe
-- Mitgliedschaft; nicht genannte Optionen behalten ihren bisherigen Wert.
GRANT schema_owner TO migrator
    WITH INHERIT FALSE;

GRANT schema_owner TO migrator
    WITH SET TRUE;

GRANT schema_owner TO migrator
    WITH ADMIN FALSE;

CREATE ROLE editor
    LOGIN
    NOINHERIT;

CREATE ROLE reader
    LOGIN
    NOINHERIT;

CREATE SCHEMA pm
    AUTHORIZATION schema_owner;

CREATE SCHEMA pm_meta
    AUTHORIZATION schema_owner;

-- Verhindert, dass gewöhnliche Rollen ungeplant Objekte im Schema public
-- anlegen (Standardrecht PUBLIC CREATE ON SCHEMA public existiert sonst
-- weiter, auch wenn Pages PM dieses Schema fachlich nicht verwendet).
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- editor bearbeitet Projektinhalte, reader liest sie. migrator verwaltet
-- Fachkonfiguration (Sprachen, Objektarten, Beziehungsarten, Bereiche)
-- unmittelbar über eigene Tabellenrechte, nicht nur über SET ROLE
-- schema_owner — project/*.sql läuft direkt als migrator und braucht daher
-- ebenfalls USAGE auf pm. Die Tabellenrechte selbst werden jeweils in der
-- zuständigen Migration ausdrücklich vergeben. Nur migrator benötigt Zugriff
-- auf pm_meta.schema_migrations.
GRANT USAGE ON SCHEMA pm TO migrator, editor, reader;
GRANT USAGE ON SCHEMA pm_meta TO migrator;

SET ROLE schema_owner;

CREATE TABLE pm_meta.schema_migrations (
    version     text        PRIMARY KEY,
    checksum    text        NOT NULL,
    applied_at  timestamptz NOT NULL DEFAULT statement_timestamp(),
    applied_by  text        NOT NULL DEFAULT session_user
);

RESET ROLE;

GRANT SELECT ON pm_meta.schema_migrations TO migrator;

-- Passwörter danach interaktiv setzen, nicht versioniert:
--   \password migrator
--   \password editor
--   \password reader
