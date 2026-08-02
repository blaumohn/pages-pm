<p align="right">Deutsch | <a href="README.en.md">English</a></p>

---

# Pages PM

**Pages PM ist eine kleine, selbst betreibbare Projektverwaltung, in der
Vorgänge, Entscheidungen und geltende Dokumente als ein gemeinsamer, von
PostgreSQL geprüfter Bestand geführt werden – für Menschen, Kommandozeilen
und KI-Agenten.**

```text
Nicht Pages PM

Jira-Vorgang:  „Renderer umsetzen“
Wiki-Seite:    „Fallback-Entscheidung“
Repository:    „Abschlussregeln“

Drei Orte, drei Zustände, Verbindungen nur im Text.

Mit Pages PM

Vorgang #9e2b --implements--> Entscheidung #8c21
Richtlinie #4d1a gilt für seinen Abschluss
depends_on #4c19 wird vor „in Arbeit“ geprüft
```

> **Stand:** Die gemeinsame PostgreSQL-Grundlage, die Vorgangstabelle mit ihren
> Integritätsregeln und der bisherige kontrollierte Zustandswechsel sind
> umgesetzt und getestet. Betriebsbereit ist der Vorgang damit noch nicht: Die
> Spezifikation hat die Vorgangsübergänge inzwischen neu gefasst, und die
> gemeinsame Lesesicht fehlt. Als Nächstes folgen Migration 015 und die
> Angleichung der Übergangs- und Lebenslauftests, danach `pm.objects`. Der Weg
> zum ersten Go-live steht [weiter unten](#8-weg-zum-ersten-go-live). Die
> folgenden Beispiele zeigen das vorgesehene Zusammenspiel, nicht den
> Ist-Zustand.

## 1. Was ich gesucht habe – und was Pages PM daraus macht

### Projektarbeit liegt in getrennten Systemen

**Problem:** Der Vorgang steht im Tracker, die Entscheidung im Wiki und die
Abschlussregel im Repository. Um zu verstehen, warum ein Vorgang
abgeschlossen werden darf, muss das Team mehrere Orte öffnen und die
Verbindung selbst herstellen.

**Pages PM:** Vorgänge, Entscheidungen und geltende Dokumente stehen in einem
gemeinsamen Bestand und werden durch typisierte Beziehungen verbunden — eine
falsche Verbindung ist ein Fehler, keine Meinung.

```text
#9e2b --implements--> #8c21
Richtlinie #4d1a gilt für den Abschluss von #9e2b
```

[Warum Pages PM diese Bestände verbindet](product_spec.md#02-warum) ·
[Typisierte Beziehungen](product_spec.md#p-008--typisierte-beziehungen-muss)

### Kleine Werkzeuge sind zu schwach, große zu aufwendig

**Problem:** Kleine Tracker lassen Untervorgänge, Abschlusskriterien und
Abhängigkeiten oft weg. Umfangreichere Systeme können diese Struktur
abbilden, verlangen dafür aber mehr Einrichtung und Betrieb.

**Pages PM:** Es übernimmt nur die Struktur, die für kleine Projekte wirklich
geprüft werden muss: Vorgänge, eingebettete Schritte, Untervorgänge,
Abhängigkeiten und bedarfsgesteuert ergänzte Dokumentvorlagen.

```text
Untervorgang
→ eigener Zustand und eigene Verantwortung

Schritt
→ Bestandteil eines Vorgangs, keine eigene Kennung

depends_on
→ ein Vorgang wartet auf den Abschluss eines anderen, geprüft
```

[Auflösungsgrenze](product_spec.md#p-014--auflösungsgrenze-muss-nicht-prüfbar) ·
[Vorgangsmodell](product_spec.md#76-vorgang)

### Laufende Nummern behaupten eine Ordnung, die nicht existiert

**Problem:** Kennungen wie `PAGES-41`, `PAGES-42`, `PAGES-43` sehen wie eine
fachliche Reihe aus. Tatsächlich können Vorgänge importiert, geteilt oder
verschiedenen Unterprojekten zugeordnet werden.

**Pages PM:** Eine interne UUID trägt die dauerhafte Identität. Eine kurze
Kennung wie `#a7k2` dient Gesprächen, Commits und äußeren Verweisen. Der
Titel darf sich ändern und wird nie zur Auflösung verwendet.

[Kennungen und Adressierung](product_spec.md#74-kennungen-adressierung-und-rahmen)

### Ein vollständiger Altimport verzögert den Start

**Problem:** Alle alten Jira-Vorgänge, Wiki-Seiten und Dateien vor dem
Go-live zu vereinheitlichen, kostet viel Arbeit, obwohl viele Inhalte
vielleicht nie wieder gebraucht werden.

**Pages PM:** Ein alter Inhalt wird erst übernommen, wenn er für die heutige
Arbeit benötigt wird. Seine Herkunft bleibt dabei erhalten.

```text
JIRA-42 wird heute gebraucht
→ jetzt übernehmen
→ Herkunft jira / JIRA-42 festhalten

alte ADR wird später relevant
→ erst dann übernehmen
```

[Externe Herkunft](product_spec.md#p-006--externe-herkunft-muss-bei-übernahmen) ·
[Import und Entwicklungsverlauf](product_spec.md#f--import-und-entwicklungsverlauf)

### Menschen, Skripte und Agenten dürfen keine verschiedenen Regeln haben

**Problem:** Werden Regeln nur in einer Oberfläche oder Programmiersprache
geprüft, muss jeder weitere Schreibweg dieselbe Validierung erneut umsetzen.
Ein Importskript oder Agent kann sonst andere Daten erzeugen als die
Benutzeroberfläche.

**Pages PM:** PostgreSQL prüft den gemeinsamen Bestand unabhängig vom
Schreibweg. Ein Mensch, ein SQL-Skript, ein KI-Agent und eine spätere
Weboberfläche treffen auf dieselben Constraints, Fremdschlüssel und
Transaktionsregeln.

```text
bereits umgesetzt:
fehlende Pflichtzuordnung (z. B. Vorgang ohne Projekt)
→ abgewiesen

unzulässige Beziehung (z. B. depends_on auf falsche Objektart)
→ abgewiesen

mehrteiliger Auftrag mit einem Fehler
→ vollständig zurückgerollt

Wechsel nach „in Arbeit“ bei offener Abhängigkeit
→ abgewiesen, solange kein Übergehungsgrund angegeben wird
```

[Gemeinsame Produktregeln](product_spec.md#4-gemeinsame-produktregeln) ·
[Projektzugehörigkeit](product_spec.md#p-002--projektzugehörigkeit-muss)

### Historische Inhalte sollen nicht nur lesbar, sondern veränderbar werden

**Problem:** Ein Git-Archiv oder ein altes Wiki kann durchsucht werden,
bildet aber noch keinen zusammenhängenden, geprüften Arbeitsbestand.

**Pages PM:** Benötigte Inhalte werden in das heutige Modell übernommen,
miteinander verbunden und anschließend nach denselben Regeln wie neue
Inhalte fortgeschrieben.

[Import und Entwicklungsverlauf](product_spec.md#f--import-und-entwicklungsverlauf)

Der vollständige Ablauf mit echten Kurzkennungen und Zeitpunkten steht in der
[Produktspezifikation, §0.5](product_spec.md#05-ein-fall-von-anfang-bis-ende).
ADR und Richtlinie sind als Fachtabellen noch nicht umgesetzt; der Vorgang ist
einschließlich seines kontrollierten Zustandswechsels vorhanden. Die Beispiele
oben zeigen das vorgesehene Zusammenspiel, gegen das jede kommende Migration
geprüft wird.

## 2. Was Pages PM bewusst nicht ist

- Keine vollständige Scrum- oder Kanban-Vorschrift.
- Kein Spiegel von Gesprächen, Git oder Fremdsystemen — nur steuerungs- und
  nachweisrelevante Aussagen werden gespeichert.
- Kein Vorrat an Dokumentvorlagen auf Verdacht; eine neue Fachart braucht
  einen gezeigten Zweck (P-012).
- Keine Darstellungsvorgaben im Fachmodell. Überschriften, Feldreihenfolge
  und Permalinks gehören zum Renderer, nicht zu den Fachvorlagen (§3.2).
- Keine Cloud-SaaS mit Sitzplatzpreisen und Web-Oberfläche. Der erste Betrieb
  ist lokales PostgreSQL plus Kommandozeile.

(Ausführlich: §3.2 der Spezifikation.)

## 3. Warum nicht einfach Jira, Confluence oder Plane?

| | Ohne Pages PM | Mit Pages PM |
|---|---|---|
| **Agenten** | Tracker-API: Netz, Token, Rate-Limit je Abfrage. | Lokales SQL, ein Agent liest den ganzen Bestand in einer Abfrage. |
| **Kosten** | Preis je Sitz, auch für gelegentliches Nachsehen. | Postgres im Container. |
| **Dokumentation** | Tracker führt Vorgänge, Wiki führt Text — beide driften auseinander. | Richtlinie, ADR und Spezifikation sind eigene Fachgegenstände, geprüft verbunden (§8). |

Neun bestehende Werkzeuge wurden am 27. Juli 2026 geprüft (Anhang D der
Spezifikation). **Wer nur Sprints und Vorgänge braucht, nimmt Plane.** Pages
PM lohnt sich ab dem Vorlagensystem — wenn geltende Dokumente neben der
Arbeit im selben, geprüften Bestand stehen sollen ([§0.2](product_spec.md#02-warum)).

## 4. Gegenwärtiger Stand im Einzelnen

Umgesetzt und getestet sind derzeit:

- Sprachen und Objektregistrierung;
- Projekte, Bereiche und genau eine Projektzugehörigkeit je gewöhnlichem
  Fachobjekt;
- Kurzkennungen und externe Herkünfte;
- typisierte Beziehungen einschließlich `depends_on`, mit dem Endpunkt
  Vorgang → Vorgang;
- Zustände für Projekte und Bereiche;
- die gemeinsame Grundlage für den Zustandsverlauf;
- die Vorgangstabelle mit ihren Regeln über die einzelne Zeile, der
  zyklenfreien Hierarchie und der Zugehörigkeit von Eltern- und Kindvorgang
  zu demselben Projekt;
- der kontrollierte Zustandswechsel des Vorgangs (zulässige Übergänge,
  Abhängigkeitsschranke mit begründeter Übergehung, Epos-Abschluss nur bei
  mindestens einem Kind sowie Abschlusssperre bei offenen Kindvorgängen oder
  unerfüllten Abschlusskriterien), atomar verbunden mit dem Zustandsverlauf.

Noch nicht umgesetzt: die inzwischen neu gefasste Übergangsordnung aus §7.1.2
und §7.6 der Spezifikation, die gemeinsame `pm.objects`-Lesesicht, die
Fachtabellen für die weiteren geplanten Facharten sowie der Python-Renderer für
GitHub Pages. Eine
verantwortliche Identität führt der Vorgang für den ersten Go-live bewusst
noch nicht (§10.2 der Spezifikation). Sprint gehört bewusst nicht zum ersten
Go-live (§12.4) — es wird erst umgesetzt, sobald ein konkreter Projektablauf
es benötigt.

PostgREST, eine Weboberfläche und eine allgemeine Schreib-API sind nicht Teil
des MVP.

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
| `009_projects.sql` | Projekthierarchie (`pm.projects`), Projektzugehörigkeit je Fachobjekt (`pm.object_projects`) und ihre Pflicht nach P-002 (`requires_project_assignment`, verzögerte Constraint-Trigger) |
| `010_short_ids.sql` | Kurzkennungen (§7.4): im Normalbetrieb nicht wiedervergebbares Verzeichnis, automatische Vergabe bei der Registrierung und exakte Auflösung |
| `011_project_area_state.sql` | Zustand für Projekt und Bereich sowie Umfangsangabe für Projekte (§7.4); sperrt neue Zuordnungen zu abgeschlossenen Projekten |
| `012_state_history.sql` | Gemeinsame, nur ergänzbare Grundlage für den Zustandsverlauf nach P-010 über alle registrierten Fachobjekte |
| `013_issues.sql` | Vorgang (§7.6) als erste technisch umgesetzte Fachart im maßgeblichen Arbeitsbaum: `pm.issues`, Pflichtschwellen ab *bereit*, Schema der Abschlusskriterien, zyklenfreie Hierarchie mit zulässigen Eltern-/Kindarten, Zugehörigkeit von Eltern- und Kindvorgang zu demselben Projekt sowie `depends_on`-Endpunkt Vorgang → Vorgang. `editor` darf den Zustand nicht unmittelbar ändern. |

`project/` ergänzt die konkrete Pages-PM-Installation um Sprachen,
Beziehungsarten (`derived_from`, `implements`, `references`, `depends_on`)
und die anfängliche Projektstruktur. Objektarten entstehen dagegen atomar in
der Schema-Migration ihrer jeweiligen Fachtabelle.

## 5. In fünf Minuten starten

Es gibt noch keinen produktiven Betrieb mit echten Pages-PM-Daten — er
beginnt erst mit der gemeinsamen `pm.objects`-Lesesicht, dem
SQL-Einstiegswrapper und einem vollständigen End-to-End-Nachweis
([Abschnitt 8](#8-weg-zum-ersten-go-live)). Was heute in fünf Minuten läuft, ist
der vollständige Migrations- und Testlauf gegen eine Wegwerfdatenbank. Setzt
Docker voraus.

```sh
./scripts/test-sql.sh
```

Baut einen Wegwerf-Container mit PostgreSQL 18 + pgTAP, wendet alle
Migrationen der Reihe nach an, führt die pgTAP-Testsuite aus und räumt danach
vollständig auf.

Die Tests legen unter anderem künstliche Fachobjekte an, registrieren sie
automatisch im Objektregister, ordnen ihnen ein Projekt, einen Bereich und
eine externe Herkunft zu und verbinden sie durch typisierte Beziehungen.
Herkünfte und Beziehungen sperren die Löschung, bis sie ausdrücklich entfernt
wurden. Für projektpflichtige Objektarten verlangt PostgreSQL spätestens bei
der verzögerten Prüfung eine gültige Projektzuordnung.

## 6. Technisches Modell

```
PostgreSQL
├── Fachtabellen sind die maßgeblichen Objekte
│   ├── pm.issues (Arbeitsstand; kontrollierter Zustandswechsel umgesetzt)
│   └── weitere Facharten werden bei konkretem Bedarf umgesetzt
├── pm.object_registry
│   └── automatisch gepflegte gemeinsame UUID- und Typregistrierung
├── gemeinsame Grundlagen
│   ├── Sprachen
│   ├── Projekte und Projektzugehörigkeit (genau eine, erzwungen)
│   ├── Bereiche
│   ├── Kurzkennungen
│   ├── Migrationsherkünfte
│   ├── typisierte Beziehungen (inkl. depends_on)
│   ├── Zustände für Projekte und Bereiche
│   └── Grundlage für den Zustandsverlauf
└── pm.objects (noch nicht umgesetzt)
    └── gemeinsame Lesesicht über die Fachtabellen

Bearbeitung
├── editor verwendet unmittelbares, rollenbegrenztes SQL
├── mehrteilige Aufträge laufen in einer Transaktion
└── Constraints, Fremdschlüssel und Trigger erzwingen Integrität

Veröffentlichung (noch nicht umgesetzt)
└── Python-Renderer liest als reader und erzeugt Markdown für GitHub Pages
```

`editor` darf einen Vorgang anlegen und seinen Titel ändern; der dabei nötige
Eintrag in `pm.object_registry` entsteht automatisch durch den
Registrierungs-Trigger der Fachtabelle. Einen Registereintrag oder eine neue
Objektart darf `editor` dagegen nicht unmittelbar anlegen. Für
projektpflichtige Objektarten erzwingen die verzögerten Constraint-Trigger
aus `009_projects.sql`, dass spätestens bei der Prüfung eine gültige
Projektzuordnung besteht.

Die erste Umsetzung verwendet PostgreSQL als maßgebliche Datenquelle. Ein
späterer, repository-gestützter Modus könnte kanonische Textdaten als
dauerhafte Quelle verwenden und PostgreSQL als Prüf- und Abfrage-Projektion.

Migrationen werden im derzeitigen Betriebsmodell nicht automatisch
angewendet. Sie sind versionierte SQL-Dateien, die von `migrator` nach
Durchsicht angewendet werden. Die Wegwerf-Testdatenbank wendet sie über
`scripts/test-sql.sh` automatisiert an.

## 7. Repository-Aufbau

```
product_spec.md   maßgebliche fachliche Produktspezifikation
migrations/       versionierte SQL-Migrationen (001_bootstrap.sql, 002_..., ...)
project/          Pages-PM-spezifische Projektkonfiguration (Sprachen, Beziehungsarten, Projektstruktur)
tests/sql/        pgTAP-Tests, gruppiert nach betroffener Migration/Teilsystem
docker/           reines Test-Abbild Postgres+pgTAP
scripts/          test-sql.sh (automatisierter Testlauf)
compose.yaml      lokale Entwicklungsdatenbank
compose.test.yaml Wegwerf-Testdatenbank
```

## 8. Weg zum ersten Go-live

Die [Produktspezifikation](product_spec.md) begründet und bestimmt das
Fachmodell; diese README erklärt nur das Produkt und seinen Stand. Gezielte
Einstiege:

| Frage | Abschnitt |
|---|---|
| Warum gibt es Pages PM? | [§0.2](product_spec.md#02-warum) |
| Ein Fall von Anfang bis Ende | [§0.5](product_spec.md#05-ein-fall-von-anfang-bis-ende) |
| Warum typisierte Beziehungen? | [P-008](product_spec.md#p-008--typisierte-beziehungen-muss) |
| Warum nicht alles als eigenes Objekt? | [P-014](product_spec.md#p-014--auflösungsgrenze-muss-nicht-prüfbar) |
| Wie ein Vorgang aussieht | [§7.6](product_spec.md#76-vorgang) |
| Wie Beziehungen und `depends_on` wirken | [§8](product_spec.md#8-beziehungen) |

**Grundlage** (Sprachen, Register, Bereiche, Herkunft, Beziehungen inkl.
`depends_on`, Projektzugehörigkeit, Kurzkennungen, Zustände für Projekt und
Bereich, Grundlage für den Zustandsverlauf), die **Vorgangstabelle** (§7.6) mit
ihren Regeln über die einzelne Zeile und die Hierarchie sowie der
**kontrollierte Zustandswechsel** (`pm.transition_issue()`: zulässige
Übergänge, Auslösung der bestehenden Pflichtschwellen, Abhängigkeitsschranke
mit begründeter Übergehung, Epos-Abschluss nur bei mindestens einem Kind,
Abschlusssperre bei offenen Kindvorgängen oder unerfüllten
Abschlusskriterien sowie Verlaufseintrag in derselben Transaktion) sind
umgesetzt. Es folgen, in dieser Reihenfolge:

1. Migration 015 umsetzen und die Vorgangsübergänge an die neu gefasste
   Übergangsordnung aus §7.1.2 und §7.6 der Spezifikation angleichen.
2. Übergangs- und Lebenslauftests an die neue Matrix angleichen.
3. `pm.objects` als gemeinsame Lesesicht (P-011) ergänzen — sie entsteht
   bewusst erst nach der Vorgangstabelle, weil sie vorher kaum Inhalt hätte.
4. Den SQL-Einstiegswrapper (`scripts/write-sql.sh`) bereitstellen:
   Verbindung als `editor`, `ON_ERROR_STOP`, transaktionale Ausführung eines
   SQL-Skripts — der erste echte Vorgang soll nicht mehr per Hand in `psql`
   entstehen.
5. Den ersten echten Pages-PM-Vorgang anlegen und die für den
   End-to-End-Nachweis benötigten weiteren Vorgänge erfassen.
6. Einen vollständigen End-to-End-Ablauf durchführen (§11 der Spezifikation);
   ausgewählte geprüfte Ausschnitte ersetzen später die vorläufigen Beispiele
   in dieser README.
7. Die weitere Entwicklung von Pages PM im System selbst verwalten: die
   nächsten Schema- und Fachumsetzungen als wirkliche Vorgänge erfassen sowie
   benötigte historische Inhalte bedarfsgesteuert übernehmen.
8. Weitere Facharten ergänzen, sobald ein konkreter Projektablauf sie
   benötigt — kein Vorratsbau aller angenommenen Facharten.

Nach dem ersten Go-live gehören zum festgelegten weiteren Ausbau: die
fortlaufende Erweiterung des End-to-End-Ablaufs um die wirklichen
Arbeitsabläufe der jeweils ergänzten Facharten, ein minimaler Python-Renderer
für GitHub Pages sowie eine geprüfte Rollen-, Rechte- und
Nebenläufigkeitsschicht mit pytest und psycopg.

## Lizenz

Copyright 2026 Dani Y. (ysdani.com)

Lizenziert unter der Apache License 2.0. Siehe `LICENSE`.
