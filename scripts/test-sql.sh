#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

DB=pages_pm_test

compose() {
    docker compose -f compose.test.yaml "$@"
}

cleanup() {
    status=$?
    trap - EXIT
    compose down --volumes --remove-orphans || true
    exit "$status"
}
trap cleanup EXIT

compose down --volumes --remove-orphans
compose up --build --wait --force-recreate

echo "Wende Migrationen an..."
compose exec -T postgres_test \
    psql \
        -v ON_ERROR_STOP=1 \
        -U postgres \
        -d "$DB" \
        -f /migrations/001_bootstrap.sql

# Nur für diesen Wegwerf-Testlauf: migrator erhält ein Testpasswort.
compose exec -T postgres_test \
    psql \
        -v ON_ERROR_STOP=1 \
        -U postgres \
        -d "$DB" \
        -c "ALTER ROLE migrator PASSWORD 'test';"

# Migrationen und Projektkonfiguration in expliziter Reihenfolge: project/
# ergänzt die jeweils vorangehende Kernmigration um Pages-PM-spezifische
# Konfiguration für Sprachen und Beziehungsarten.
#
# Objektarten werden nicht über eine eigene Projektdatei vorregistriert,
# sondern ab 009 von der jeweiligen Fachtabellenmigration atomar zusammen
# mit ihrer Tabelle angelegt.
#
# Die Reihenfolge über beide Verzeichnisse hinweg lässt sich nicht allein
# aus den Dateinamen ableiten. Deshalb ist sie hier ausdrücklich aufgeführt,
# statt per Glob ermittelt zu werden.
set -- \
    migrations/002_languages.sql \
    project/001_languages.sql \
    migrations/003_object_registry.sql \
    migrations/004_areas.sql \
    migrations/005_object_origins.sql \
    migrations/006_relation_types.sql \
    project/002_relation_types.sql \
    migrations/007_object_relations.sql \
    migrations/008_common_field_functions.sql

for entry do
    [ -f "$entry" ] || {
        echo "Datei nicht gefunden: $entry" >&2
        exit 1
    }
    echo "  $entry"
    compose exec -T \
        -e PGPASSWORD=test \
        postgres_test \
        psql \
            -v ON_ERROR_STOP=1 \
            -U migrator \
            -d "$DB" \
            -f "/$entry"
done

echo "Richte pgTAP ein..."
compose exec -T postgres_test \
    psql \
        -v ON_ERROR_STOP=1 \
        -U postgres \
        -d "$DB" \
        -c "CREATE SCHEMA IF NOT EXISTS tap;
            CREATE EXTENSION IF NOT EXISTS pgtap SCHEMA tap;"

# pgTAP läuft als postgres und prüft Struktur, Constraints und Trigger.
# Rollenrechte werden später getrennt mit pytest und psycopg geprüft.
echo "Führe pgTAP-Tests aus..."
compose exec -T \
    -e PGOPTIONS="--search_path=tap,pm,public" \
    -e TEST_DB="$DB" \
    postgres_test \
    sh -c 'pg_prove -U postgres -d "$TEST_DB" /tests/*.sql'
