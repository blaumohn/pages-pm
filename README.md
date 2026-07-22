<p align="right">Deutsch | <a href="README.en.md">English</a></p>

---

# Pages PM

Ein getestetes PostgreSQL-Fundament für eine repository-orientierte
Projektverwaltung.

## Status

Das getestete relationale Fundament für Sprachen, Objektregistrierung,
Bereiche, externe Migrationsherkünfte und typisierte Beziehungen ist auf
Grundlage des endgültigen Registermodells umgesetzt.

Der nächste betriebliche Meilenstein ist die Verwaltung der Entwicklung von
Pages PM selbst: aktuelle Sprints, Vorgänge und die unmittelbar benötigten
Dokumentvorlagen werden als Fachtabellen umgesetzt und mit realen
Projektdaten verwendet.

Darauf folgt ein kleiner Python-Renderer, der eine deterministische
Markdown-Ausgabe für GitHub Pages erzeugt.

PostgREST, eine Weboberfläche und eine allgemeine Schreib-API sind nicht Teil
des MVP.

## Motivation

Pages PM bildet Projektverwaltungsdaten in geprüften PostgreSQL-Fachtabellen
ab. Jede fachliche Objektart besitzt eine eigene Fachtabelle mit
ausdrücklichen Spalten, Constraints und fachlichen Regeln. Gemeinsame
Beziehungen, Bereiche und externe Herkünfte verwenden ein automatisch
gepflegtes Objektregister. Historische Inhalte werden nur bei Bedarf
normalisiert; PostgreSQL bleibt die maßgebliche Datenquelle.

## Begriffe

Drei unterschiedliche Vorgänge müssen unterschieden werden:

```
SQL-Migration
    verändert das wiederverwendbare Datenbankschema und seine Regeln
    (migrations/)

Projektkonfiguration
    registriert die konkreten Sprachen, Objektarten und Beziehungsarten
    der Pages-PM-Installation (project/)

Inhaltsmigration beziehungsweise Import
    normalisiert eine externe Archiveinheit zu einem internen Objekt
    (pm.object_origins)
```

## Aktueller Umfang

| Migration | Zweck |
|---|---|
| `001_bootstrap.sql` | Rollen (`schema_owner`, `migrator`, `editor`, `reader`), Schemas, Migrationsverzeichnis |
| `002_languages.sql` | Sprachkonfiguration + zentrale Sprachkarten-Prüfung |
| `003_object_registry.sql` | Objektarten (`pm.object_types`), technisches Register (`pm.object_registry`), Registrierungsfunktionen |
| `004_areas.sql` | Verwaltete Klassifikationsbereiche, Mehrfachzuordnung |
| `005_object_origins.sql` | Zuordnung mehrerer externer Archiveinheiten zu einem normalisierten Objekt |
| `006_relation_types.sql` | Definition von Beziehungsarten + zulässige Endpunktkombinationen |
| `007_object_relations.sql` | Geprüfte typisierte Beziehungen zwischen Objekten (Kardinalität, Zyklen, Beschreibungen) |

`project/` ergänzt die konkrete Pages-PM-Installation um Sprachen,
Objektarten und Beziehungsarten (siehe Abschnitt „Begriffe“).

Noch nicht umgesetzt: Fachtabellen (Sprint, Vorgang und zunächst benötigte
Dokumentvorlagen), die gemeinsame `pm.objects`-Lesesicht sowie der
Python-Renderer. Eine allgemeine Schreib-API, PostgREST und eine
Benutzeroberfläche sind erst für einen späteren Ausbau vorgesehen.

## Architektur

```
PostgreSQL
├── Fachtabellen sind die maßgeblichen Objekte (noch nicht umgesetzt)
│   ├── pm.sprints
│   ├── pm.issues
│   ├── pm.kep_lites
│   └── weitere Vorlagen
├── pm.object_registry
│   └── automatisch gepflegte gemeinsame UUID- und Typregistrierung
├── gemeinsame Regeln
│   ├── Sprachen
│   ├── Bereiche
│   ├── Migrationsherkünfte
│   └── typisierte Beziehungen
└── pm.objects (noch nicht umgesetzt)
    └── gemeinsame Lesesicht über die Fachtabellen

Bearbeitung
├── editor verwendet unmittelbares, rollenbegrenztes SQL
├── mehrteilige Aufträge laufen in einer Transaktion
└── Constraints, Fremdschlüssel und Trigger erzwingen Integrität

Veröffentlichung (noch nicht umgesetzt)
└── Python-Renderer liest als reader und erzeugt Markdown für GitHub Pages
```

Die erste Umsetzung verwendet PostgreSQL als maßgebliche Datenquelle. Ein
späterer, repository-gestützter Modus könnte kanonische Textdaten als
dauerhafte Quelle verwenden und PostgreSQL als Prüf- und Abfrage-Projektion.

Migrationen werden im derzeitigen Betriebsmodell nicht automatisch
angewendet. Sie sind versionierte SQL-Dateien, die von `migrator` nach
Durchsicht angewendet werden. Die Wegwerf-Testdatenbank wendet sie über
`scripts/test-sql.sh` automatisiert an.

## Tests ausführen

Setzt Docker voraus.

```sh
./scripts/test-sql.sh
```

Baut einen Wegwerf-Container mit PostgreSQL 18 + pgTAP, wendet alle
Migrationen der Reihe nach an, führt die pgTAP-Testsuite aus und räumt
danach vollständig auf.

## Repository-Struktur

```
migrations/       versionierte SQL-Migrationen (001_bootstrap.sql, 002_..., ...)
project/          Pages-PM-spezifische Projektkonfiguration (Sprachen, Objektarten, Beziehungsarten)
tests/sql/        pgTAP-Tests, gruppiert nach betroffener Migration/Teilsystem
docker/           reines Test-Abbild Postgres+pgTAP
scripts/          test-sql.sh (automatisierter Testlauf)
compose.yaml      lokale Entwicklungsdatenbank
compose.test.yaml Wegwerf-Testdatenbank
```

## Roadmap

1. erster betriebsfähiger Fachkern aus Sprint, Vorgang und einer
   Dokumentvorlage samt `pm.objects`-Lesesicht
2. kleiner SQL-Einstiegswrapper (`scripts/write-sql.sh`): Verbindung als
   `editor`, `ON_ERROR_STOP` und transaktionale Ausführung eines SQL-Skripts
3. gegenwärtige Projektarbeit direkt in Pages PM
4. bedarfsgesteuerte Migration historischer Inhalte
5. minimaler Python-Renderer für GitHub Pages
6. Rollen-, Rechte- und Nebenläufigkeitstests mit pytest und psycopg
7. Härtung anhand der realen Nutzung

## Lizenz

Copyright 2026 Dani Y. (ysdani.com)

Lizenziert unter der Apache License 2.0. Siehe `LICENSE`.
