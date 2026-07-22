<p align="right">Deutsch | <a href="README.en.md">English</a></p>

---

# Pages PM

Ein getestetes PostgreSQL-Fundament für eine repository-orientierte
Projektverwaltung.

## Status

Früher Entwicklungsstand. Das getestete relationale Fundament ist
umgesetzt; Fachtabellen (Sprints, Vorgänge, ADRs, ...) und
Anwendungsschnittstellen sind noch nicht fertig.

## Motivation

Projektverwaltungsdaten (Vorgänge, Sprints, Entscheidungsdokumente,
Runbooks, ...) werden als striktes relationales Fachmodell in PostgreSQL
dargestellt. Constraints, Trigger und Rollen erzwingen Integrität, statt
sich auf handgeschriebenen Validierungscode in einer Anwendungsschicht zu
verlassen. Eine spätere Projektionsschicht kann die geprüften Daten als
git-versionierten Text darstellen, zum Beispiel für GitHub Pages.

## Aktueller Umfang

| Migration | Zweck |
|---|---|
| `001_bootstrap.sql` | Rollen (`schema_owner`, `migrator`, `build`, `pages_renderer`, `backup`), Schemas, Migrationsverzeichnis |
| `002_languages.sql` | Sprachkonfiguration + zentrale Sprachkarten-Prüfung |
| `003_objects.sql` | Gemeinsame Objektidentität (`pm.objects`), Objektarten |
| `004_areas.sql` | Verwaltete Klassifikationsbereiche, Mehrfachzuordnung |
| `005_object_origins.sql` | Externe Migrationsherkunft |
| `006_relation_types.sql` | Definition von Beziehungsarten + zulässige Endpunktkombinationen |
| `007_object_relations.sql` | Geprüfte typisierte Beziehungen zwischen Objekten (Kardinalität, Zyklen, Beschreibungen) |

Noch nicht umgesetzt: Fachtabellen (Sprint, Vorgang, Dokumentvorlagen),
eine Schreib-API, eine Anwendungs-/PostgREST-Schicht, die Git-/Text-
Projektion, produktionsreife Rollen- und Nebenläufigkeitstests, eine
Benutzeroberfläche.

## Architektur

```
PostgreSQL (aktuell maßgebliche Datenquelle)
├── Rollen: schema_owner (NOLOGIN), migrator, build, pages_renderer, backup
├── Schemas, Constraints und Trigger erzwingen die fachliche Integrität
└── geplante Publikations-Views liefern eine reine Lese-Projektion

Anwendungsschicht (dünn, noch nicht gebaut)
├── Renderer — wählt veröffentlichbare Daten aus und erzeugt
│              statische Markdown-/HTML-Seiten für GitHub Pages
├── CLI/API — zunächst eingeschränkte DML-Rechte über die Rolle build
│             (Tabelle für Tabelle einzeln vergeben, keine Pauschalrechte);
│             später kontrollierte Schreibzugriffe über Datenbankfunktionen
└── Repository-Integration — verknüpft Vorgänge mit Commits, Dateien,
                             Symbolen und weiteren Implementierungsartefakten
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
tests/sql/        pgTAP-Tests, gruppiert nach betroffener Migration/Teilsystem
docker/           reines Test-Abbild Postgres+pgTAP
scripts/          test-sql.sh (automatisierter Testlauf)
compose.yaml      lokale Entwicklungsdatenbank
compose.test.yaml Wegwerf-Testdatenbank
```

## Roadmap

- Sprints, Vorgänge und weitere vorlagenbasierte Dokumenttabellen
- Rollen-/Rechte- und Nebenläufigkeitstests (pytest + psycopg)
- eine dünne Schreib-API über kontrollierte Datenbankfunktionen
- Git-/Text-Projektion für GitHub Pages

## Lizenz

Copyright 2026 Dani Y. (ysdani.com)

Lizenziert unter der Apache License 2.0. Siehe `LICENSE`.
