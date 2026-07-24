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

### Beispiel

Angenommen, Pages PM verwaltet diesen Vorgang:

```text
Vorgang 42
Titel: Renderer für GitHub Pages bauen
Sprint: 3
Bereich: publishing
frühere Quelle: Jira PAGES-42
```

Die vollständigen Vorgangsdaten liegen in `pm.issues`. Beim Einfügen entsteht
automatisch eine Registerzeile:

```text
UUID:       018f…42
Objektart:  issue
```

`pm.object_registry` enthält also nicht den Titel oder den Zustand des
Vorgangs, sondern nur seine gemeinsame Kennung und seine Objektart.

Die Sprintzuordnung steht unmittelbar in `pm.issues.sprint_id`. Der Bereich
`publishing` wird über `pm.object_areas` zugeordnet — Vorgang 42 könnte
zugleich zu `build` gehören, aber nicht zweimal zu `publishing`. Die frühere
Jira-Einheit `PAGES-42` wird in `pm.object_origins` als Herkunft erfasst und
darf nicht zugleich einem anderen internen Objekt zugeordnet werden.

Unabhängig von Vorgang 42 kann `pm.object_relations` beispielsweise diese
Beziehung speichern:

```text
ADR 5 --derived_from--> KEP-Lite 2
```

Die umgekehrte Kante `KEP-Lite 2 --derived_from--> ADR 5` würde abgelehnt,
weil sie zusammen mit der ersten Kante einen Zyklus erzeugen würde.

Sprint, Vorgang, ADR und KEP-Lite existieren im gegenwärtigen Stand noch
nicht (siehe „Aktueller Umfang“); das Beispiel beschreibt das vorgesehene
Zusammenspiel.

## Begriffe

Drei unterschiedliche Vorgänge müssen unterschieden werden:

### SQL-Migration

Verändert das wiederverwendbare Datenbankschema und seine Regeln
(`migrations/`).

**Beispiel:** `009_sprints.sql` führt `pm.sprints` ein. Danach kann Sprint 3
für den 1.–14. August angelegt und aktiviert werden. Ein zweiter gleichzeitig
aktiver Sprint wird von PostgreSQL abgelehnt.

### Projektkonfiguration

Registriert die konkreten Sprachen und Beziehungsarten der
Pages-PM-Installation (`project/`). Objektarten entstehen dagegen atomar in
der Schema-Migration ihrer jeweiligen Fachtabelle.

**Beispiel:** `project/001_languages.sql` legt `de` und `en` als
Pflichtsprachen fest. Ein Titel mit nur `{"de": "Sprint 3"}` wird deshalb
abgelehnt; ein Titel mit `{"de": "Sprint 3", "en": "Sprint 3"}` wird
angenommen.

### Inhaltsmigration beziehungsweise Import

Normalisiert eine externe Archiveinheit zu einem internen Objekt
(`pm.object_origins`).

**Beispiel:** Der frühere Jira-Vorgang `PAGES-42` und die ergänzende
Archivdatei `notes/renderer.md` werden demselben Pages-PM-Vorgang als zwei
getrennte Herkunftszeilen zugeordnet. `PAGES-42` darf danach keinem zweiten
internen Objekt zugeordnet werden.

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
| `008_common_field_functions.sql` | Gemeinsame Hilfsfunktionen für kommende Fachtabellen, z. B. Mindestlängen für Pflichttexte und automatische `updated_at`-Zeitstempel |

`project/` ergänzt die konkrete Pages-PM-Installation um Sprachen und
Beziehungsarten (siehe Abschnitt „Begriffe“). Objektarten entstehen atomar
in der Schema-Migration ihrer jeweiligen Fachtabelle.

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

Beispielsweise darf `editor` Vorgang 42 anlegen und seinen Titel ändern. Der
dabei nötige Eintrag in `pm.object_registry` entsteht automatisch durch den
Registrierungs-Trigger der Fachtabelle. Einen Registereintrag oder eine neue
Objektart darf `editor` dagegen nicht unmittelbar anlegen.

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

Die Tests legen unter anderem zwei künstliche Fachobjekte an, registrieren
sie automatisch im Objektregister, ordnen einem davon einen Bereich und eine
externe Herkunft zu und verbinden beide durch eine typisierte Beziehung.
Solange Herkunft oder Beziehung bestehen, lehnt PostgreSQL die Löschung ab.

## Repository-Struktur

```
migrations/       versionierte SQL-Migrationen (001_bootstrap.sql, 002_..., ...)
project/          Pages-PM-spezifische Projektkonfiguration (Sprachen, Beziehungsarten)
tests/sql/        pgTAP-Tests, gruppiert nach betroffener Migration/Teilsystem
docker/           reines Test-Abbild Postgres+pgTAP
scripts/          test-sql.sh (automatisierter Testlauf)
compose.yaml      lokale Entwicklungsdatenbank
compose.test.yaml Wegwerf-Testdatenbank
```

## Roadmap

Die ausgewählten Facharten (Sprint, Vorgang, KEP-Lite, ADR,
System-Spezifikation, Ablauf-Spezifikation, Richtlinie, Runbook, Postmortem,
Drift-Report, Feature-Matrix, Testmatrix und Jira-Arbeitsdokumentation) sind
kein beliebiger späterer Ausbau, sondern der festgelegte fachliche
Ausdrucksumfang von Pages PM. Jede Art übernimmt eine eigene Aufgabe im
Arbeitsablauf; ihre Umsetzung gehört verbindlich zu Phase B, auch wenn der
Zeitpunkt ihrer wirklichen Verwendung vom Bedarf abhängt.

### Erster betriebsfähiger Kern

1. Sprint, Vorgang und eine erste Dokumentvorlage umsetzen.
2. `pm.objects` als gemeinsame Lesesicht einführen.
3. Einen ersten fachlichen End-to-End-Test ergänzen, der Registrierung,
   Bereiche, Herkunft, Beziehungen, Rechte und Löschregeln beweist;
   ausgewählte geprüfte Ausschnitte ersetzen später die vorläufigen
   Beispiele in dieser README.
4. Den SQL-Einstiegswrapper (`scripts/write-sql.sh`) bereitstellen:
   Verbindung als `editor`, `ON_ERROR_STOP` und transaktionale Ausführung
   eines SQL-Skripts.
5. Die weitere Entwicklung von Pages PM im System selbst verwalten:
   den aktuellen Sprint und die weiteren Phase-B-Migrationen als wirkliche
   Vorgänge erfassen sowie benötigte historische Inhalte bedarfsgesteuert
   übernehmen.

### Vollständiger Ausdrucksumfang

6. Die übrigen festgelegten Facharten umsetzen.
7. Den End-to-End-Test fortlaufend um die wirklichen Arbeitsabläufe der neuen
   Facharten erweitern, sobald die dafür beteiligten Arten umgesetzt sind
   (z. B. Postmortem → Maßnahme → Vorgang oder KEP-Lite → daraus
   abgeleitetes ADR).
8. Phase B fachlich abnehmen: Alle Facharten sind registriert, über
   `pm.objects` lesbar und in ihrem vorgesehenen Arbeitsablauf geprüft.

### Veröffentlichung und Härtung

9. Einen minimalen Python-Renderer für GitHub Pages umsetzen.
10. Rollen, Rechte und Nebenläufigkeit mit pytest und psycopg prüfen.
11. Das System anhand der realen Nutzung härten.

## Lizenz

Copyright 2026 Dani Y. (ysdani.com)

Lizenziert unter der Apache License 2.0. Siehe `LICENSE`.
