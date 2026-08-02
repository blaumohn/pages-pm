# Pages PM – Produktspezifikation

Diese Spezifikation ist selbst eine **System-Spezifikation** nach §7.15 und
trägt deshalb die Angaben, die sie dort verlangt (§7.3).

| Angabe | Wert |
|---|---|
| **Kurzkennung** | `SPEC-PM` |
| **Fachart** | System-Spezifikation |
| **Titel** | Pages PM – Produktspezifikation |
| **Projekt** | Pages PM |
| **Zustand** | *gültig* |
| **Pflege** | Dani (Mensch) |
| **Ist-Stichtag** | Arbeitsbaum von `../pages-pm` am 2. August 2026 (`fabac88`) |
| **Zielgruppe** | kleine Teams, eine bis fünf aktiv mitarbeitende Personen |

---

## 0. Vorhang

### 0.1 Was Pages PM ist

Pages PM führt die Steuerungs- und Nachweisdaten kleiner Softwareprojekte in
einer PostgreSQL-Datenbank und veröffentlicht sie als statisches Markdown.

Es führt **nicht** den Inhalt der Arbeit – kein Code, keine Gespräche, keine
Kopie fremder Systeme –, sondern die Aussagen, mit denen man Arbeit steuert und
belegt: was entschieden wurde, was daraus folgt, was davon geprüft ist.

### 0.2 Warum

| | Ohne Pages PM | Mit Pages PM |
|---|---|---|
| **Agenten** | Ein Agent liest einen Vorgang über die Tracker-API: Netz, Token, Rate-Limit, Latenz je Abfrage. | Lokales SQL. Ein Agent liest den ganzen Bestand in einer Abfrage. |
| **Sichtbarkeit** | Ein öffentlicher Blick auf den Projektstand verlangt Konten in einer Cloud. | Markdown auf GitHub Pages, ohne Konto. **Ziel, nicht Ist** – der Renderer ist noch nicht gebaut (§10.3). |
| **Kosten** | Preis je Sitz, auch für die Person, die einmal im Monat hineinsieht. | Postgres im Container. |
| **Struktur** | Kleine Werkzeuge lassen Untervorgänge und Abhängigkeiten weg; große kosten das Obige. | Drei Hierarchiestufen (§7.6), Abhängigkeiten (§8), Erfüllungsstand je Kriterium. |
| **Dokumentation** | Der Tracker führt Vorgänge, das Wiki führt Text – ohne Zustand, ohne Ablösung, ohne Verantwortung. Beide Seiten driften auseinander. | Richtlinie, ADR, Spezifikation und Runbook sind **eigene Fachgegenstände mit eigenen Zuständen**, verbunden über geprüfte Beziehungen (§8). |

Neun Werkzeuge wurden am 27. Juli 2026 geprüft (Anhang D). **Wer nur Sprints
und Vorgänge braucht, nimmt Plane.** Pages PM lohnt ab dem Vorlagensystem –
wenn geltende Dokumente neben der Arbeit im selben Bestand stehen sollen.

### 0.3 Drei Abläufe

**Steuerung an der Arbeit.**

```text
ohne   Commit „fix: dead link“
       → Tracker öffnen, Ticket suchen, verlinken. Drei Handgriffe
         für zwei Minuten Arbeit – also unterbleibt es.

mit    Commit-Trailer   Pages-PM: #d5aa
       → fertig. Ein Beitrag am Sammelvorgang, eine Verwaltungshandlung.

       Pages-PM: DEPLOY-03    Konformitätsarbeit an einer Regel
       Pages-PM: #8c21        setzt eine Entscheidung um

Warum eine Kurzkennung und nicht der Titel:
  fallback-kette-renderer     ändert sich
  #9e2b                       nie (§7.4, Regel 5)
```

**Ein Dokument ohne Vorgang.**

```text
Richtlinie „Abschluss von Vorgängen“
  Zustand    gültig seit 08-01     Pflege  Dani
  Regeln     DONE-01 · DONE-02
  derived_from → ADR #17ad

Kein Vorgang beteiligt. Trotzdem: Zustand, Pflegeverantwortung,
Ablösung mit Grund, geprüfte Endpunkte.

Im Wiki daneben wäre es Freitext ohne Zustand – und ein Beitrag
könnte DONE-02 nicht nennen.
```

**Was der Sprint wirklich misst.**

```text
Plan       {#9e2b, #4c19}
erledigt   {#9e2b}
→ übliche Auswertung: „eine von zwei“

Ist-Umfang aus dem Zustandsverlauf:
           {#9e2b, #4c19, #7b0d, #88ce, #a103}
→ ein Drittel des Zeitraums ging an ungeplante Arbeit

Niemand hat das eingetragen. Es folgt aus dem Verlauf (§7.5, Regel 6).
```

### 0.4 Die Facharten in je einer Zeile

**Rahmen** – keine Fachgegenstände, keine Endpunkte einer Kante:

| Rahmen | Beantwortet die Frage | §7 |
|---|---|---|
| **Projekt** | Zu welchem abgegrenzten Zusammenhang gehört das? | 7.4 |
| **Bereich** | Was für eine Art Arbeit ist das? | 7.4 |

**Zwölf Facharten:**

| Fachart | Beantwortet die Frage | §7 |
|---|---|---|
| **Sprint** | Was war in diesem Zeitraum vorgenommen, was ist wirklich gelaufen? | 7.5 |
| **Vorgang** | Was ist zu tun, und woran ist es fertig? | 7.6 |
| **KEP-Lite** | Was wurde wogegen entschieden, bevor gebaut wurde? | 7.7 |
| **ADR** | Welche technische Entscheidung gilt dauerhaft, und warum? | 7.8 |
| **Richtlinie** | Welche Regel gilt fortlaufend, und wie heißt sie? | 7.9 |
| **Runbook** | Wie stellt man das unter Druck wieder her? | 7.10 |
| **Postmortem** | Was haben wir aus der Störung gelernt? | 7.11 |
| **Drift-Bericht** | Was weicht vom Soll ab, und wiegt es zusammen schwer? | 7.12 |
| **Feature-Matrix** | Wie stehen mehrere Möglichkeiten an denselben Merkmalen? | 7.13 |
| **Testmatrix** | Welche Kombination hat noch niemand geprüft? | 7.14 |
| **System-Spezifikation** | Was ist dieses System, und was ist es nicht? | 7.15 |
| **Ablauf-Spezifikation** | Wie läuft das über Beteiligte hinweg – auch im Fehlerfall? | 7.16 |

Der Reifegrad jeder Art steht **ausschließlich in §6**. Geprüfte, aber nicht
angenommene Arten stehen mit ihrer Begründung in **Anhang C**.

### 0.5 Ein Fall von Anfang bis Ende

Ein Team bemerkt, dass Vorschau, Ausgabe und Oberfläche fehlende Übersetzungen
verschieden behandeln.

```text
#a1f4    Aufgabe     „Fallback-Verhalten der drei Anzeigeorte feststellen“
                     → Ergebnis: Feature-Matrix
KEP-Lite #8c21       Problem · Vorschlag · 2 verworfene Alternativen
                     · 2 Annahmekriterien   → angenommen 08-03
ADR      #17ad       derived_from → #8c21   → angenommen 08-05

#9e2b    Funktion    implements → #8c21
#4c19    Funktion    implements → #8c21     depends_on → #9e2b

#9e2b    K1 = erfüllt · K2 = erfüllt                  08-12
#4c19    K1 = erfüllt · K2 = offen

KEP-Lite #8c21  → umgesetzt   08-13
```

Die Kriterien `K1` und `K2` sind **Feldinhalt** des Vorgangs, keine eigenen
Gegenstände (P-014).

**Was daran die ganze Spezifikation trägt:** Zwischen dem 3. und dem 13. August
war die Entscheidung angenommen und nicht umgesetzt. Wer Entscheidung, Umsetzung
und Prüfung in ein Zustandsfeld legt, verliert diese zehn Tage – und liest
„entschieden“ als „erledigt“.

---

## 1. Zweck und Geltungsbereich

Pages PM setzt bewährte Projektmanagementpraxis für kleine, agile oder hybride
Softwareprojekte in ein zusammenhängendes Produktmodell um.

Diese Spezifikation legt fest, **welche fachlichen Gegenstände es gibt, woraus
sie bestehen, in welchen Zuständen sie sein können und wie sie zusammenhängen.**
Sie enthält keine Tabellen-, Spalten-, Trigger-, Migrations-, Rechte-, SQL-,
Renderer- oder API-Entwürfe. Solche Festlegungen gehören in die technische
Umsetzungsschicht und leiten sich aus dieser Spezifikation ab, nicht umgekehrt.

Die Fachvorlagen in §7 sind der fachliche Maßstab für jede Umsetzungsschicht:
Ein Feld, das dort nicht vorkommt, hat keinen fachlichen Auftrag; eine Regel, die
dort steht, muss die Umsetzung erfüllen.

**Wie diese Spezifikation geschrieben ist** – Beschreibungsform, Quellenklassen,
Zuständigkeit von Quellen, Wortlautvorbehalt, Herkunft von Bruchfällen und die
Bedeutung von *Muss*, *Soll*, *Kann* – steht in **Anhang A**.

Eine Änderung dieser Spezifikation muss den betroffenen Ablauf, die
Kontextquelle, die Festlegung, den Auswahlgrund und ein konkretes
Vorher/Nachher-Beispiel nennen.

---

## 2. Reifegrad

**Normativität** (*Muss*, *Soll*, *Kann*; Anhang A.5) sagt, wie verbindlich eine
Regel ist. **Reifegrad** sagt, wie weit ihre Umsetzung ist. Beide sind
unabhängig.

| Begriff | Bedeutung | Fall daneben |
|---|---|---|
| **Kandidat** | Eigenständiger Nutzen noch nicht gezeigt. | Eine fertige Vorlage in §7 macht daraus keinen Kandidaten weniger. |
| **empfohlen** | Nutzen argumentiert, nicht bestätigt. | „Wir brauchen das bestimmt bald“ ist keine Bestätigung, sondern die Argumentation selbst. |
| **geplant** | Fachlich entschieden, technisch nicht benutzbar. | Eine begonnene Migration macht daraus nicht *Arbeitsstand*. |
| **Arbeitsstand** | Begonnen, nicht vollständig nachgewiesen. | Eine Tabelle, in die nie geschrieben wurde, ist Arbeitsstand. |
| **aktuell** | Fachlich benutzbar. | Ein grüner Testlauf über eine Tabelle ist kein Nachweis eines Ablaufs. |

**Der Unterschied zwischen den mittleren Stufen, am Fall:**

```text
geplant       Sprint     Vorlage §7.5 fertig, keine Migration
Arbeitsstand  Vorgang    Tabelle vorhanden, kontrollierter Zustandswechsel fehlt

nicht wie weit, sondern wo:
geplant = fertig im Text · Arbeitsstand = angefangen im Code
```

**Der Reifegrad *aktuell* verlangt einen benannten Ablauf.** Nicht „die Tabelle
existiert“, sondern „dieser Ablauf ist durchgelaufen“, und §10 nennt ihn.

```text
aktuell   „project/001_languages.sql ist angewandt. {de,en} sind Pflicht.
           Ein Titel mit nur {de} wird abgewiesen.“     → benutzt

nicht     „pm.languages existiert und hat zwei Zeilen.“ → gebaut
```

Ein berechneter Belegort setzte einen Nachweisbegriff voraus, der feiner
auflöst als jeder Pages-PM-Gegenstand; er ist deshalb kein Ziel dieser
Spezifikation (P-014). §10 wird von Hand geführt und gilt zum Stichtag im Kopf.

**Zusatzmerkmal `(Praxis belegt)`:** Die Fachart wird außerhalb von Pages PM
bereits verwendet. Das Merkmal ersetzt den Reifegrad nicht.

**Eine Fachvorlage in §7 ist keine Annahme der Fachart.** Die Vorlage sagt, wie
die Art aussähe; §6 sagt, ob sie eingeführt ist.

---

## 3. Produktprofil

### 3.1 Ziele

| Ziel | Kontextquelle und was sie sagt | Festlegung und Auswahlgrund |
|---|---|---|
| **Z1 – Arbeit auffindbar machen.** | Findability-Literatur (Morville); facettierte Suche in Trackern. Auffindbarkeit ist eine Eigenschaft des Bestands. | Alle Arbeitsgegenstände sind typisierte Objekte mit unveränderlicher Kennung. Nur so ist der Bestand filterbar. |
| **Z2 – Arbeit steuerbar machen.** | Zustandsmodelle in Trackern; Scrum Guide, Definition of Done. Steuerung entsteht durch wenige benannte Zustände. | Jeder Vorgang trägt einen expliziten Zustand und eine Abschlussbedingung. |
| **Z3 – Entscheidung, Umsetzung und Prüfung unterscheiden.** | Kubernetes-KEP-Prozess; ADR-Praxis. Genehmigung, Durchführung und Überprüfung sind getrennte Schritte. | Entscheidung, ausführende Arbeit und Prüfung sind getrennte Aussagen. |
| **Z4 – Zugehörigkeit, Gliederung und Verantwortung sichtbar machen.** | NASA WBS Handbook; RACI-Matrix. | Projekt, Hierarchie, Bereich und Verantwortung sind vier getrennte Aussagen. |
| **Z5 – Externe Herkunft und interne Ableitung unterscheiden.** | Archivisches Provenienzprinzip; W3C PROV-DM. | Importherkunft und `derived_from` bleiben getrennt. |
| **Z6 – Änderungen, Abweichungen und Lernen nachvollziehbar halten.** | Fowler, „Event Sourcing“; Google SRE. | Vorheriger Stand, Änderung, Grund und Ergebnis bleiben lesbar. |
| **Z7 – Mehrsprachige Aussagen eindeutig kennzeichnen.** | RFC 5646, Abschnitt 2; Unicode CLDR. | Fachaussagen verwenden BCP-47-Kennungen; Fallback ist eine gesonderte Regel. |
| **Z8 – Nur erforderliche Formalität verlangen.** | Fowler, „Yagni“. | Zusätzliche Fachobjekte entstehen nur bei eigenem Zweck oder Prüfbedarf. |

**Was die Ziele im Einzelfall heißen:**

```text
Z1  „zeig mir alle i18n-Arbeit im Zustand bereit“
      find(area = i18n, zustand = bereit) → {#4c19, #7b0d}
Z2  „ist #9e2b fertig?“
      alle Abschlusskriterien tragen den Erfüllungsstand erfüllt
Z3  „ist das schon umgesetzt?“
      decision(#8c21) = angenommen · done(#9e2b) = false   → nein
Z4  „woraus besteht #3f70, und wer beurteilte #9e2b?“
      Kinder von #3f70 = {#9e2b, #4c19} · Prüfung im Verlauf = Dani
Z5  „was in diesem Bestand stammt nicht von uns?“
      origin ≠ leer → 14 Gegenstände
Z6  „warum wurde #4c19 umgehängt?“
      Zustandsverlauf: Projektwechsel 08-13, Grund „gehört zu pcs-php“
Z7  „in welcher Sprache steht dieser Satz?“
      Titel = {de: „…“, en: „…“}
Z8  „warum gibt es keine Fachart Risikoregister?“
      P-012: kein wirklicher Ablauf, kein gezeigtes Vorher/Nachher
```

### 3.2 Nicht-Ziele

| Nicht-Ziel | Kontextquelle und was sie sagt | Folge |
|---|---|---|
| Scrum vollständig vorschreiben. | Scrum Guide 2020 bezeichnet sich als „purposely incomplete“. | Scrum-Praktiken dürfen gezielt genutzt werden, ohne Scrum-Rollen zu verlangen. |
| Iterationen erzwingen. | Kanban-Praxis: kontinuierlicher Fluss funktioniert ohne feste Iterationen. | Ein Projekt muss keine Sprints führen. Wo einer läuft, ist er vollständig (§7.5). |
| Alle Arbeit dem Sprintziel unterordnen. | Scrum Guide 2020: das Sprintziel ist die eine Zusage des Sprints. | Zugehörigkeit und Zielbeitrag sind zwei Angaben. |
| Gespräche, Git oder Fremdsysteme kopieren. | Integrationspraxis: doppelt gepflegter Inhalt divergiert. | Pages PM speichert nur steuerungs- und nachweisrelevante Aussagen. |
| Jede denkbare Dokumentart vorsorglich anbieten. | Fowler, „Yagni“. | Neue Facharten benötigen einen gezeigten Zweck (P-012). |
| Darstellung festlegen. | Trennung von Inhalt und Darstellung. | Überschriften, Verzeichnisse, Permalinks und Feldreihenfolge stehen in keiner Vorlage. |

**Woran man ein Nicht-Ziel im Einzelfall erkennt:**

```text
Scrum       Ein Projekt ohne Product Owner ist zulässig.
Iterationen Ein Projekt ohne jeden Sprint ist zulässig.
Sprintziel  #9a03 trägt nichts zum Sprintziel bei und gehört trotzdem
            zum Ist-Umfang (§7.5, Regel 9).
Kopieren    Beitrag [2] hält   github-pr:214 · 2026-08-07 · „fix: dead link“
            – nicht den Änderungssatz, nicht die Beschreibung des PR.
Vorrat      „Risikoregister“ wird nicht angelegt, solange niemand einen
            Ablauf zeigen kann, der es braucht.
Darstellung „Titel steht über der Beschreibung“ ist keine Festlegung
            dieser Spezifikation.
```

---

## 4. Gemeinsame Produktregeln

Zur Form: Jede Regel beginnt mit dem Schaden, den es ohne sie gibt, und schließt
mit dem kleinsten gültigen Fall. Die Marke hinter „Ohne diese Regel“ sagt, woher
der Bruchfall stammt – `belegt`, `erlebt`, `konstruiert` oder `offen`
(Anhang A.3). Die Daten in den Beispielen sind erfunden, auch bei belegten
Bruchfällen; erfunden ist dann die Kleidung, nicht der Schaden.

### P-001 – Dauerhafte Identität (Muss)

**Ohne diese Regel** *(belegt: Berners-Lee, „Cool URIs don't change“)*

```text
ADR #17ad  verweist auf   vorgaenge/entwurf/renderer-fallback
Der Vorgang wird bereit.
                          vorgaenge/bereit/renderer-fallback
Der Verweis zeigt ins Leere. Niemand merkt es, bis jemand ihn braucht.
```

**Aufgabe:** Ein verwalteter Gegenstand muss über seinen Verlauf hinweg
eindeutig wiedererkennbar bleiben.

**Kontextquelle:** Berners-Lee, „Cool URIs don't change“ (W3C); Vergabepraxis für
Vorgangsschlüssel in Jira und GitHub.
*Was sie sagt:* Die Kosten einer geänderten Kennung fallen bei allen an, die
darauf verweisen. Tracker ziehen daraus eine feste Trennung: Schlüssel
unveränderlich, Titel und Zustand frei änderbar.

**Optionen**

```text
(a)  Titel als Kennung
     „Renderer bauen“  →  „Markdown-Renderer bauen“
     bricht bei jeder Umbenennung

(b1) Pfad als Kennung
     vorgaenge/i18n/renderer-fallback
     bricht beim Bereichs- oder Zustandswechsel

(b2) Position als Kennung
     „Vorgang [2] im anfänglichen Umfang von Sprint #6f30“
     bricht, sobald vorne einer eingefügt wird

(c)  unveränderliche Kennung neben veränderlichem Titel
     hält alle drei Fälle aus
```

**Festlegung:** (c). Jeder eigenständige Fachgegenstand erhält eine
unveränderliche Identität. Titel, Zustand und Inhalt dürfen sich ändern.
Zusätzlich trägt jeder Gegenstand eine kurze, ebenfalls unveränderliche
Kurzkennung für die Adressierung von außen (§7.4).

**Auswahlgrund:** Nur (c) übersteht alle drei Änderungen; P-007 und P-008 setzen
dauerhaft gültige Verweise voraus.

**Kosten:** Kennungen sind nicht sprechend; jede Anzeige braucht den Titel dazu.

**Beispiel**

```text
Kennung   019826f1-…-5e6f          unveränderlich
Titel     „Renderer bauen“  →  „Markdown-Renderer bauen“
ADR #17ad → 019826f1-…      bleibt gültig
```

**Gegenbeispiel:** Zwei verschiedene Vorgänge mit derselben Identität. Dann
verweist die Kennung nicht mehr, sondern rät.

**Abgrenzung zu dieser Spezifikation:** In einem Dokument ist die Nummer das
Kennzeichen, nicht ein Ersatzschlüssel – dort *ist* die Position die Aussage
(Anhang A.6). Option (b2) gilt für Fachgegenstände, nicht für Gliederungen.

### P-002 – Projektzugehörigkeit (Muss)

**Ohne diese Regel** *(belegt: NASA WBS Handbook – eine Gliederung erlaubt die vollständige Aufsummierung nur, wenn kein Element zwei Gliederungselementen zugeordnet ist)*

```text
#7c40  gehört zu Kashasaga  und  zu pipeline-config-spec-php
Auswertung Kashasaga:            12 Vorgänge
Auswertung pipeline-config-spec:  9 Vorgänge
Summe über beide Projekte:       21 – von denen es nur 20 gibt.
```

**Aufgabe:** Projektarbeit muss in ihrem Projektzusammenhang zuordenbar sein.

**Kontextquelle:** NASA WBS Handbook (NASA/SP-20210023927), Abschnitte 2.2 und
3.3.5.
*Was sie sagt:* Vollständige Aufsummierung ist nur möglich, wenn kein Element
zwei Gliederungselementen zugeordnet ist. Umgekehrt gilt: Arbeitsumfang, der
nicht in der Gliederung steht, gehört nicht zum Projekt.

**Optionen**

```text
(a)  mehrere gleichrangige Projektzugehörigkeiten
     #7c40 ∈ {Kashasaga, pcs-php}      bricht bei jeder Summe

(b)  genau eine unmittelbare Zugehörigkeit, Projekte hierarchisch
     #7c40 ∈ Kashasaga, parent(Kashasaga) = Dach
     hält die Summe; Mehrfachbezug läuft über Bereiche (P-003)

(c)  keine Zugehörigkeit, nur Bereiche
     areas(#7c40) = {ui, publishing}
     bricht bei „was gehört zu diesem Projekt?“
```

**Festlegung:** (b). Jeder betriebliche Fachgegenstand gehört genau einem
unmittelbaren Projekt. Projekte dürfen hierarchisch gegliedert sein.

**Auswahlgrund:** (a) macht jede Vollständigkeitsaussage mehrdeutig; (c)
verliert den Steuerungsrahmen.

**Kosten:** Arbeit, die zwei Projekten wirklich gemeinsam gehört, braucht eine
Entscheidung statt einer Doppelnennung.

**Eigenentscheidung ohne Quelle:** Die 100-%-Regel erklärt nicht, warum die
Zugehörigkeit unveränderlich sein müsste. Sie ist es nicht: Umhängen ist erlaubt
und wird nach P-010 fortgeschrieben.

**Beispiel**

```text
project(KEP-Lite #1b60) = Pages PM
parent(Pages PM)        = Kashasaga
```

**Gegenbeispiel:** Ein KEP-Lite, das unmittelbar zu zwei Projekten gehört.
`depends_on` darf dagegen projektübergreifend sein (§8.2).

### P-003 – Fachliche Gliederung (Soll)

**Ohne diese Regel** *(belegt: NASA WBS Handbook, Abschnitt 3.5.2 „Non-Product Elements“ – Entwurf, Fertigung, Phase A sind Funktionen und Zeitabschnitte, keine Gliederungselemente)*

```text
Der belegte Fall – eine Facette wandert in die Gliederung:

  Projekt X
    ├─ Konstruktion        ← eine Funktion, kein Bestandteil
    ├─ Fertigung           ← eine Funktion
    └─ Test & Abnahme      ← eine Funktion
  Frage: „woraus besteht Projekt X?“ → nicht mehr beantwortbar

Derselbe Fall in Pages PM:

  Bereich  publishing
  Bereich  publishing/renderer     ← sieht aus wie eine Facette
                                     ist aber eine zweite Gliederung
  Eine Kante trägt zwei Bedeutungen; auswerten lässt sie sich für keine.
```

**Aufgabe:** Arbeit soll in eine steuerbare fachliche Struktur gegliedert werden
können.

**Kontextquelle:** Rosenfeld/Morville, *Information Architecture*; NASA WBS
Handbook 3.5.2 und 4.2.
*Was sie sagt:* Facetten sind mehrfach vergebbar und orthogonal, Hierarchien
exklusiv und zerlegend. Beides zu vermischen ist ein bekannter
Konstruktionsfehler.

**Optionen**

```text
(a)  nur Hierarchie     parent(V2) = V1
     bricht bei „zeige alle i18n-Arbeit“
(b)  nur Facetten       areas(V1) = {i18n, publishing}
     bricht bei „woraus besteht dieses Epos?“
(c)  beides, getrennt geführt
     hält beide Fragen auseinander
```

**Festlegung:** (c). Bereiche klassifizieren Gegenstände fachlich;
Eltern-Kind-Beziehungen gliedern Arbeit. Beides bleibt vom Projekt getrennt.

**Auswahlgrund:** Zerlegung und Klassifikation beantworten verschiedene Fragen;
wird eine gestrichen, wandert ihre Bedeutung in dieselbe Kante.

**Bereiche sind verwaltet, nicht frei (Muss).** Ein Bereich wird ausdrücklich
angelegt; er entsteht nicht dadurch, dass jemand ihn nennt. *Auswahlgrund:* Eine
Facette, die im Vorbeigehen entsteht, erzeugt Synonyme – `i18n`, `I18N`,
`mehrsprachigkeit` – und ist danach nicht mehr filterbar, also das Gegenteil von
Z1. *Kosten:* Wer einen neuen Bereich braucht, muss ihn anlegen lassen.

**Kosten:** Zwei Strukturen sind zu pflegen.

**Beispiel**

```text
areas(V1) = {publishing, i18n}
parent(V2) = V1
```

**Gegenbeispiel:** Ein Bereich, der ein Projekt oder ein Elternvorgang sein soll.

### P-004 – Verantwortung (Soll; der Zirkel ist ein Muss)

**Ohne diese Regel** *(konstruiert; offen – Archiv-PM, §12.3)*

```text
Bearbeitung(#9e2b) = Agent-1
Prüfung(#9e2b)     = Agent-1
Kriterium K2       = erfüllt

Ein Agent fragt nicht nach, er füllt plausibel.
Der Eintrag sagt nichts über das Kriterium – nur über Agent-1.
```

**Aufgabe:** Verantwortung für erzeugte Gegenstände und ausgeführte Tätigkeiten
soll erkennbar sein.

**Kontextquelle:** RACI-Matrix als Standardwerkzeug der Projektpraxis.
*Was sie sagt:* Ausführung, Rechenschaft, Konsultation und Information sind
getrennte Rollen an derselben Aufgabe.

**Optionen**

```text
(a)  ein Feld „zuständig“
     bricht bei „wer schuldet hier eine Prüfung?“ – niemand, laut Feld
(b)  die vier RACI-Rollen
     bricht am Schnitt: RACI trennt nach Beteiligungsgrad,
     Z3 trennt nach Ablaufschritt
(c)  vier Funktionen entlang der Pages-PM-Abläufe
     deckt den Schnitt aus Z3
```

**Festlegung:** (c). Vier Verantwortungen:

| Funktion | Bedeutung | Wo Pflicht |
|---|---|---|
| **Bearbeitung** | führt die Arbeit aus | Vorgang ab Zustand *in Arbeit* |
| **Entscheidung** | trägt Annahme oder Ablehnung | KEP-Lite, ADR, Richtlinie beim Zustandswechsel |
| **Prüfung** | beurteilt die Abschlusskriterien | Vorgang ab Zustand *in Prüfung* |
| **Pflege** | hält einen geltenden Gegenstand aktuell | Richtlinie, Runbook, Spezifikationen im Zustand *gültig* |

**Wo die Prüfung getragen wird.** *Bearbeitung*, *Entscheidung* und *Pflege*
sind Angaben am Gegenstand. Die *Prüfung* ist eine Angabe am
**Verlaufseintrag** des Wechsels aus *in Prüfung* – feste Feldzahl, ein
Beteiligter je Eintrag.

```text
Zustandsverlauf #9e2b
  [4] 08-11  in Prüfung → in Arbeit      Prüfung: agent-1
  [5] 08-12  in Prüfung → abgeschlossen  Prüfung: agent-1

Bearbeitung(#9e2b) = agent-1
Prüfung aus [5]    = agent-1     → Zirkel
```

**Menschliche und künstliche Beteiligte.** Eine Verantwortung nennt, ob sie ein
Mensch oder ein Agent trägt. Bei zwei Menschen ist die Trennung eine Soll-Regel
(Vier-Augen-Prinzip); **ein Agent, der seine eigene Arbeit prüft, ist
unzulässig (Muss)** – der Schaden oben.

**Auswahlgrund:** Da Z3 Entscheidung, Umsetzung und Prüfung trennt, müssen die
Verantwortungen denselben Schnitt haben.

**Kosten:** Bei einer Person im Team wirken vier Felder überflüssig. Und
ablesbar ist, *wer* geprüft hat, nicht *was* er geprüft hat.

**Beispiel**

```text
bearbeitet(V1) = Dani (Mensch)
Prüfung im Verlauf von V1 = Dani (Mensch)   zulässig, wird vermerkt
```

**Gegenbeispiel:** Gleiche Person bedeutet nicht gleiche Funktion.

### P-005 – Mehrsprachige Fachaussagen (Muss)

**Ohne diese Regel** *(belegt: RFC 5646 – Tags wie `zh-Hant` unterscheiden, was ohne Kennung ununterscheidbar bliebe)*

```text
Titel  „Fallback-Kette umsetzen“
Welche Sprache? Die Anzeige rät. Der Übersetzer rät.
Die Vollständigkeitsprüfung kann nicht einmal fragen.
```

**Aufgabe:** Die Sprache einer Fachaussage muss eindeutig gekennzeichnet werden
können.

**Kontextquelle:** RFC 5646, Abschnitt 2; Unicode CLDR und Mozilla Fluent.
*Was sie sagt:* Kennzeichnung und Fallback sind zwei Fragen; CLDR-Praxis
behandelt Fallback als Kette von Anzeigeentscheidungen.

**Optionen**

```text
(a)  eine Sprache pro Installation
     bricht, sobald ein Leser eine andere Sprache braucht
(b)  Sprachkarte mit Pflichtsprachen
     titel = {de: "…", en: "…"}     die Lücke ist sofort sichtbar
(c)  beliebige Sprachen ohne Pflicht
     bricht erst bei der Anzeige – Monate später
```

**Festlegung:** (b). Fachtexte sind Sprachkarten mit BCP-47-Kennungen. Die
Pflichtsprachen werden **pro Installation** festgelegt; Anzeige-Fallback ist
eine gesonderte Benutzungsregel. **Kurzwerte** (§7.2) werden nicht übersetzt.

**Geltungsbereich, ausdrücklich:** installationsweit, nicht je Projekt.
Projektweise Sprachen wären eine zweite Konfiguration mit derselben Wirkung; bei
ein bis fünf Personen ist die Installation zugleich das Team. Eine spätere
Aufteilung wäre nach P-012 zu begründen.

**Auswahlgrund:** (c) erzeugt stillschweigend unvollständige Aussagen; (b) macht
die Lücke sofort sichtbar.

**Kosten:** Jede Aussage muss in allen Pflichtsprachen erfasst werden.

**Zwei Stufen, nicht eine.** Eine Sprache ist erst **konfiguriert** und dann
**verpflichtend**:

```text
ohne     fr wird Pflichtsprache
         → 340 vorhandene Fachtexte sind sofort unvollständig

mit      fr konfiguriert, nicht Pflicht  → neue Texte dürfen fr tragen
         Bestand nachziehen              → Lücken sind auffindbar
         fr auf Pflicht setzen           → erst jetzt gilt P-005 für fr
```

**Zwei verschiedene Fehler.** Eine fehlende Pflichtsprache ist eine Lücke; eine
**nicht konfigurierte** Sprache ist ein Fremdkörper. Die Auskunft nennt sie
getrennt (P-013).

**Keine Standardsprache.** Alle Pflichtsprachen sind gleichrangig. Welche
angezeigt wird, ist eine Eigenschaft der Anfrage.

**Eigenentscheidung ohne Quelle:** `{de,en}` ist reine Konfiguration.
**Zweitens:** Zugelassen ist nur eine Teilmenge von BCP 47 – Sprache und optional
Region (`de`, `en`, `de-CH`). Schriftsystem und Variante sind nicht zugelassen.

**Beispiel**

```text
Pflichtsprachen = {de, en}
Titel = {de: "Test", en: "Test"}
```

**Gegenbeispiel** *(konstruiert; offen – Archiv-PM, §12.3)*

```text
Titel = {de: "Fallback-Kette umsetzen", en: "TODO"}
Formal vollständig. Fachlich nicht.
```

Einzige Ausnahme ist der Zustand *Eingang* eines Vorgangs (§7.6).

### P-006 – Externe Herkunft (Muss bei Übernahmen)

**Ohne diese Regel** *(belegt: DACS, Statement of Principles – die Beschreibung muss den Abruf nach Herkunft ermöglichen; physische Trennung genügt ausdrücklich nicht)*

```text
Beschreibung  de: „… (aus Jira übernommen, ca. Juni) …“
Frage: „Was in diesem Bestand stammt nicht von uns?“
Antwort: alles lesen. 400 Gegenstände. Von Hand.
```

**Aufgabe:** Die Herkunft übernommener Information muss so festgehalten werden,
dass ihre Entstehung beurteilt werden kann.

**Kontextquelle:** Provenienzprinzip nach DACS und SAA Dictionary;
Importer-Praxis von Jira und GitHub.
*Was sie sagt:* Entscheidend ist nicht die physische Trennung, sondern dass die
Herkunft in der Beschreibung steht und **der Abruf nach Herkunft möglich ist**.

**Optionen**

```text
(a)  Herkunft im Fließtext          bricht bei jeder Suche
(b)  strukturierte Herkunftsangabe
     origin = {jira, J01-105, comment:4, 2026-06-11}
     „was stammt nicht von uns?“ ist eine Abfrage
(c)  keine Herkunft, nur Kopie      der Bestand ist nicht mehr trennbar
```

**Festlegung:** (b). Eine Herkunft enthält Quellsystem, **Fundstelle** und –
getrennt davon – einen **Ausschnitt**, dazu gegebenenfalls das ursprüngliche
Erstellungsdatum und eine **Anmerkung zur Normalisierung**. Die Herkunft ist
eine **geführte Nebenfolge** an jedem Fachgegenstand (P-014) und keine eigene
Fachart.

Drei Regeln:

1. **Eine externe Einheit gehört höchstens einem internen Gegenstand** –
   installationsweit. Umgekehrt darf ein Gegenstand mehrere Herkünfte tragen.
   *Auswahlgrund:* Sonst vervielfacht Pages PM einen unklar strukturierten
   Archivbestand künstlich.
2. **Fundstelle und Ausschnitt sind zwei Angaben.** Ein fehlender Ausschnitt
   heißt „die ganze Einheit“, nicht „unbekannt“ – es gibt nur zwei klare
   Zustände.
3. **Übernommene Kennungen werden nicht stillschweigend normalisiert.** Ein Wert
   mit Leerraum am Rand wird abgewiesen, nicht getrimmt. *Auswahlgrund:* Sonst
   gehen `" J01-123"` und `"J01-123"` als verschiedene Einheiten durch.

```text
origin(V1)  Quellsystem   jira
            Fundstelle    J01-105
            Ausschnitt    comment:4        ← fehlt = die ganze Einheit
            Ursprung      2026-06-11
            Anmerkung     de: „Als Vorgang eingeordnet; der Prüfplan
                              lag als getrennte Datei vor.“
```

**Auswahlgrund:** Nur die strukturierte Form macht aus einer Lektüre eine Suche.

**Kosten:** Import wird aufwendiger.

**Gegenbeispiel:** `V2 --derived_from--> V1` ist interne Ableitung. Ein Beitrag
am Sammelvorgang (§7.6.1) ist ebenfalls keine Herkunft.

### P-007 – Interne Ableitung (Muss)

**Ohne diese Regel** *(belegt: W3C PROV-DM, Abschnitt 5.2.1 – Ableitung ist eine gerichtete Umformung)*

```text
KEP-Lite #8c21  ist abgeschlossen und unveränderlich (§7.7, Regel 3)
ADR #17ad entsteht daraus
  → #8c21 müsste angefasst werden, um den Verweis einzutragen
Ein abgeschlossenes Dokument, das sich weiter ändert, ist nicht abgeschlossen.
```

**Aufgabe:** Die fachliche Entstehung eines Gegenstands aus einem anderen muss
gerichtet darstellbar sein.

**Kontextquelle:** W3C PROV-DM 5.2.1; ADR-Praxis (Nygard, MADR).
*Was sie sagt:* Abgeleitete Dokumente nennen ihre Grundlage in Richtung
Vergangenheit. Die Grundlage wird nicht rückwirkend geändert.

**Optionen**

```text
(a)  ungerichtete Verbindung   #17ad — #8c21
     bricht bei „was entstand woraus?“
(b)  vom Abgeleiteten zur Grundlage   #17ad --derived_from--> #8c21
     die Grundlage bleibt unberührt
(c)  von der Grundlage zum Abgeleiteten   bricht an P-010
```

**Festlegung:** (b). `derived_from` zeigt vom abgeleiteten Gegenstand auf seine
Grundlage.

**Auswahlgrund:** Nur (b) lässt die Grundlage unverändert.

**Kosten:** „Was ist aus #8c21 entstanden?“ braucht eine Rückwärtssuche.

**Beispiel:** `ADR #17ad --derived_from--> KEP-Lite #8c21`

**Gegenbeispiel:** Die Gegenrichtung behauptet, das KEP-Lite sei aus dem ADR
hervorgegangen.

### P-008 – Typisierte Beziehungen (Muss)

**Ohne diese Regel** *(offen – Archiv-PM, §12.3)*

```text
#9e2b  relates to  KEP-Lite #8c21
#9e2b  relates to  ADR #17ad
#9e2b  relates to  #4c19

Frage: „Welche Vorgänge setzen #8c21 um?“
Antwort: unbekannt. Die Kanten existieren und sagen nichts.
```

**Aufgabe:** Bedeutungsverschiedene Zusammenhänge dürfen nicht in einer
mehrdeutigen Sammelbeziehung verschwinden.

**Kontextquelle:** Verknüpfungstypen in Jira; W3C PROV-DM.
*Was sie sagt:* Die Typen sind gerichtet und tragen je zwei Formulierungen.
Teams, die alles über `relates to` verbinden, verlieren die Auswertbarkeit.

**Optionen**

```text
(a)  eine allgemeine Verbindung        bricht sofort
(b)  freie Benennung je Kante          vier Synonyme, nicht zusammenführbar
(c)  feste Menge typisierter Beziehungen mit erlaubten Endpunkten
     eine falsche Kante ist ein Fehler, keine Meinung
```

**Festlegung:** (c). Jede Beziehung hat eine eindeutige Bedeutung, Richtung und
erlaubte Endpunkte; die Endpunkte stehen in §8.2.

**Auswahlgrund:** Nur (c) macht die Kante prüfbar.

**Kosten:** Jede neue Beziehungsart braucht eine Entscheidung nach P-012.

**Eine Beziehung ist unveränderlich außer ihrer Beschreibung.** Quelle, Ziel und
Art bilden ihre Identität; sie zu ändern wäre fachlich Löschen und Neuanlegen.

**Beispiel:** `#9e2b --implements--> KEP-Lite #8c21`

**Gegenbeispiel:** `#9e2b --references--> KEP-Lite #8c21` beweist keine
Umsetzung.

### P-009 – Entscheidung, Umsetzung und Prüfung trennen (Muss)

**Ohne diese Regel** *(belegt: Kubernetes-KEP-Prozess – eine angenommene Vorlage bleibt offen, bis die Umsetzung erschienen ist)*

```text
Ein Zustandsfeld für alles:

KEP-Lite #8c21   angenommen   (2026-08-03)
… und dann?

#9e2b  in Arbeit      #4c19  bereit

Der Bericht sagt: „angenommen“. Zehn Tage lang.
Gelesen wird: „erledigt“.
```

**Aufgabe:** Eine angenommene Änderung ist nicht allein durch ihre Annahme
umgesetzt oder geprüft.

**Kontextquelle:** Kubernetes-KEP-Prozess mit getrennten Zuständen für Annahme
und Auslieferung.
*Was sie sagt:* Genehmigung, Durchführung und Überprüfung sind eigene Schritte
mit eigenen Ergebnissen.

**Optionen**

```text
(a)  ein Zustandsfeld für alles     „angenommen“ nicht von „fertig“ trennbar
(b)  getrennte Aussagen mit je eigenem Zustand
     decision(#8c21) = angenommen · done(#9e2b) = false
```

**Festlegung:** (b). Entscheidung, ausführende Arbeit und Prüfung sind getrennte
Aussagen. Entscheidung und Vorgang sind eigene Gegenstände; die Prüfung ist der
Zustand *in Prüfung* und der Erfüllungsstand der Kriterien.

Daraus folgt: Ein KEP-Lite erreicht *umgesetzt* erst, wenn mindestens ein
umsetzender Vorgang abgeschlossen ist **und** jedes Annahmekriterium *erfüllt*
trägt.

**Auswahlgrund:** Genau die Verwechslung aus (a) ist der Anlass für Z3.

**Kosten:** Ein einfacher Vorgang erzeugt zwei Objekte statt einem. Ablauf A
bleibt deshalb ohne KEP-Lite.

**Beispiel**

```text
decision(KEP-Lite #8c21) = angenommen   08-03
done(#9e2b)              = true         08-12
#8c21 / K1, K2           = erfüllt      08-13
→ #8c21 umgesetzt                       08-13
```

**Gegenbeispiel:** Aus `angenommen` folgt nicht `verifiziert`.

### P-010 – Änderungen sichtbar fortschreiben (Muss)

**Ohne diese Regel** *(belegt: RFC-Register – ein abgelöster RFC bleibt lesbar und trägt „Obsoleted by“; gelöscht wird nichts)*

```text
Nur der letzte Zustand:

#7c40  in Arbeit

„War #7c40 am 6. August in Arbeit?“        keine Antwort
„Ist es schon einmal durchgefallen?“        keine Antwort
„Warum wurde es umgehängt?“                 keine Antwort
Und damit: „was lief in diesem Sprint?“     keine Antwort (§7.5, Regel 6)
```

**Aufgabe:** Wichtige Änderungen und ihr Status müssen nachvollziehbar bleiben.

**Kontextquelle:** Fowler, „Event Sourcing“; ADR-Praxis mit `superseded`;
RFC-Metadaten.
*Was sie sagt:* Zustandsänderungen werden als Folge unveränderlicher Ereignisse
geführt. Abgelöste Dokumente bleiben lesbar.

**Optionen**

```text
(a)  nur letzter Zustand            bricht wie oben
(b)  technisches Änderungsprotokoll
     08-12 14:03  status: offen → erfüllt  (user: dani)
     hält fest, DASS sich etwas änderte, nicht WARUM
(c)  fachliche Zustandsfolge mit Zeitpunkt und Grund
```

**Festlegung:** (c). Der Zustandsverlauf ist eine **geführte Nebenfolge**
(P-014): abfragbar, aber kein Gegenstand.

```text
Eintrag Pflicht
  Zustandswechsel · Entscheidung · Ablösung · Projektwechsel ·
  Übergehung · Textänderung an angenommenem oder geltendem Text

kein Eintrag
  Tippfehler in einem Entwurf      (noch nicht angenommen)
  Bereich hinzugefügt              (Klassifikation, kein Urteil)
  Notizfeld ergänzt

Die Schwelle ist der Zustand des Gegenstands, nicht die Größe der
Änderung: angenommen oder gültig → Eintrag · Entwurf → keiner.
```

**Auswahlgrund:** Für Z6 ist der Grund der eigentliche Inhalt – und genau er
fehlt in (b).

**Form eines Verlaufseintrags**

| Angabe | Herkunft |
|---|---|
| Zeitpunkt | automatisch |
| Bearbeiter | automatisch |
| Ereignisart | aus der Liste oben |
| Beteiligter je Funktion (P-004) | bei Prüfung Pflicht |
| **Grund** | Pflicht, **mit der Änderung übergeben** |
| **Änderungsart** | Pflicht bei Textänderung an angenommenem Text |

**Der Grund kommt mit der Änderung, nicht danach.** *Kosten:* Wer ändern will,
muss im selben Zug sagen, warum.

**Änderungsart** ist ein Kurzwert ohne Vorgabewert – sie ist ein Urteil:

```text
redaktionell           Tippfehler, Wortwahl, Umbruch  → kein Grund nötig
fachlich               der Inhalt gilt jetzt anders   → Grund Pflicht
Geltungsbereich        → abgewiesen: „Geltungsbereich ändern heißt ablösen“
```

**Wozu die Änderungsart gebraucht wird:** Nur mit ihr lässt sich rechnen, ob ein
abhängiger Gegenstand nachzuprüfen ist – „letzte Prüfung liegt vor der jüngsten
**fachlichen** Änderung der Grundlage“.

**Kosten:** Der Datenbestand wächst; Anzeigen müssen zwischen aktuellem Zustand
und Verlauf unterscheiden.

**Beispiel**

```text
Zustandsverlauf #7c40                                  Änderungsart
  [1] 08-03  Eingang → bereit         dani  fachlich   „Kriterium ergänzt“
  [2] 08-06  bereit → in Arbeit       dani  —          „Übergehung #2e91“
  [3] 08-11  in Arbeit → in Prüfung   dani  —
  [4] 08-11  in Prüfung → in Arbeit   dani  —          „durchgefallen“
  [5] 08-12  in Prüfung → abgeschl.   dani  —

„War #7c40 am 08-06 in Arbeit?“  → Zeile [2]     ✓
„Einmal durchgefallen?“          → Zeile [4]     ✓
„Welches Kriterium?“             → steht nicht da (§12.4)

[1] bis [5] sind Platznummern in der Nebenfolge, keine Gegenstände.
Eine Kante zeigt auf #7c40, nie auf [4].
```

**Gegenbeispiel:** [5] an die Stelle von [4] zu schreiben erfüllt die Regel
nicht.

### P-011 – Gemeinsames Auffinden (Muss)

**Ohne diese Regel** *(offen – Archiv-PM, §12.3)*

```text
Ansicht „KEP-Lites“   → #8c21
Ansicht „Vorgänge“    → #9e2b, #4c19

Frage: „Was gehört zur Entscheidung #8c21?“
Antwort: zwei Ansichten öffnen und im Kopf zusammenlegen.
```

**Aufgabe:** Projektinformation muss als zusammenhängender Bestand auffindbar
sein.

**Kontextquelle:** Findability-Literatur (Morville); projektübergreifende
Filtersuche in Trackern.
*Was sie sagt:* Auffindbarkeit ist eine Eigenschaft des Bestands.

**Optionen**

```text
(a)  je Fachart eine eigene Ansicht    bricht wie oben
(b)  Volltextsuche über alles
     suche("fallback") → 61 Treffer, darunter jede Notiz
(c)  gemeinsame Suche mit Facettenfiltern
     find(area = i18n, projekt = Pages PM) → {#8c21, #9e2b}
```

**Festlegung:** (c). Alle Facharten tragen das gemeinsame Mindestraster aus §7.3.

**Auswahlgrund:** (a) verhindert genau die Fragen, für die Pages PM gebaut wird.

**Kosten:** Alle Facharten müssen das Mindestraster tragen.

**Beispiel:** `find(area = publishing) = {KEP-Lite #8c21, #4c19}`

**Gegenbeispiel:** Eine Ergebnisliste ohne Fachart verwischt die Bedeutung.

### P-012 – Begründung vor neuer Fachart (Muss, NICHT PRÜFBAR)

**Ohne diese Regel** *(belegt: Fowler, „Yagni“ – der Vergleich ist „Kosten jetzt gegen Nutzen vielleicht“)*

```text
Fachart „Risikoregister“ wird eingeführt, weil sie sinnvoll wirkt.

Monat 1  drei Einträge
Monat 6  niemand öffnet sie; sie steht in jeder Suche,
         in jeder Vorlage, in jeder Migration.
Kosten: sofort und dauerhaft. Nutzen: nie eingetreten.
```

**Aufgabe:** Zusätzliche Struktur soll nur eingeführt werden, wenn sie Steuerung,
Qualität oder Nachvollziehbarkeit wirklich verbessert.

**Kontextquelle:** Fowler, „Yagni“.

**Optionen**

```text
(a)  neue Fachart bei erkennbarem Bedarf
     bricht an der Prüfbarkeit: jeder Bedarf ist erkennbar,
     wenn man ihn erkennen will
(b)  neue Fachart erst bei gezeigtem Ablauf oder Vorher/Nachher-Nutzen
     „am 20. Juli hat eine ungetestete Kombination die Ausgabe zerlegt“
```

**Festlegung:** (b). Eine neue Fachart braucht einen wirklichen Ablauf mit
eigenem Zweck oder einen gezeigten Vorher/Nachher-Nutzen. Dieselbe Prüfung gilt
für jede zusätzliche **Pflichtangabe** und jede zusätzliche **Beziehungsart**.

**Auswahlgrund:** „Erkennbarer Bedarf“ ist nicht prüfbar.

**Kosten:** Nützliche Facharten entstehen später als möglich.

**Beispiel**

```text
Testmatrix: bei {de,en} × {preview,prod} bleibt eine Zelle leer.
Diese eine Zelle ist der gezeigte Nutzen.
```

**Gegenbeispiel:** Technische Speicherbarkeit allein begründet keine Fachart.

### P-013 – Schwellenauskunft (Muss)

**Ohne diese Regel** *(belegt: RFC 7807 – eine Fehlerangabe benennt das Problem, statt nur zu melden, dass eines vorliegt)*

```text
Wechsel nach „bereit“?  → abgelehnt.

Was fehlt? Ausprobieren. Feld für Feld.
Ein Agent rät und füllt plausibel – siehe P-004.
```

**Aufgabe:** Wer einen Gegenstand weiterbringen will, muss erfahren können, was
dafür fehlt.

**Kontextquelle:** RFC 7807; Schemaprüfung mit benannten Verstößen.
*Was sie sagt:* Ein Fehler wird dort sichtbar gemacht, wo er entsteht, und
benennt die verletzte Bedingung.

**Optionen**

```text
(a)  Abweisung mit Fehlermeldung   „Feld leer“ / „Bedingung 4 verletzt“
(b)  Abweisung plus Auskunft über die nächste Schwelle
     „für bereit fehlt ein Abschlusskriterium“
```

**Festlegung:** (b). Zu jedem Gegenstand ist abrufbar, welche Angaben für einen
angestrebten Zustand fehlen. Eine Abweisung nennt die **Schwelle**, nicht die
Spalte.

**Auswahlgrund:** Mit den Schwellen aus §7.1.1 ist die Auskunft ohnehin
vorhanden.

**Kosten:** Jede Schwelle braucht einen verständlichen Namen.

**Beispiel**

```text
was fehlt für „bereit“?
  fehlt  Vorgangsart · Dringlichkeit · mindestens ein Abschlusskriterium
  fehlt  Titel in en
  ok     Beschreibung (de, en)

was fehlt für „in Arbeit“?
  ok     im Vorhaben von Sprint #6f30
  fehlt  #2e91 ist nicht abgeschlossen (depends_on)
         → Übergehung mit Grund ist möglich (§7.6, Regel 12)
```

**Gegenbeispiel:** Die Auskunft erkennt **Fehlen**, nicht **Leere**. Ein
Kriterium „Die Funktion arbeitet korrekt“ ist formal gültig und trotzdem keines.

### P-014 – Auflösungsgrenze (Muss, NICHT PRÜFBAR)

**Ohne diese Regel** *(erlebt: Entwurfsarbeit an §7.7 und §8.2, Juli 2026)*

```text
N3  verifies →  #9e2b / Kriterium [2]

Eine Kante auf einen Feldinhalt. Damit wäre jeder Eintrag jeder
Punktfolge ein Gegenstand: jedes Abschlusskriterium, jeder
Runbook-Schritt, jeder Testfall, jede Richtlinienregel.
Aus 12 Facharten würden Hunderte Gegenstände mit Kennung,
Zustand und Verantwortung – für einen Bestand, den ein bis fünf
Personen führen sollen.
```

**Aufgabe:** Es muss festliegen, wie tief der Objektgraph reicht – und was
darunter noch berechenbar bleibt.

**Kontextquelle:** Keine zuständige Quelle (Anhang A.4). Eigenentscheidung.

**Optionen**

```text
(a)  jeder Listeneintrag ist ein Gegenstand      bricht am Aufwand
(b)  zwei Stufen: Gegenstand und undurchsichtiges Feld
     bricht an §7.5, Regel 6: der Ist-Umfang wird aus dem
     Zustandsverlauf berechnet – in einem JSON-Feld nicht möglich
(c)  drei Stufen: Gegenstand, geführte Nebenfolge, dynamisches Feld
(d)  Einzelfall je Fachart entscheiden
     bricht an der Vorhersagbarkeit
```

**Festlegung:** (c).

```text
Objektgraph          Gegenstände und Kanten
                     Kennung · Zustand · Verantwortung · Endpunkt
                     → §7.3, §8.2

geführte Nebenfolge  gehört genau einem Gegenstand, ist abfragbar,
                     ist aber kein Gegenstand: keine Kennung im
                     Graphen, kein eigener Zustand, kein Endpunkt
                     → Zustandsverlauf · Herkunft · Beiträge ·
                       Bereichs- und Projektzuordnung

dynamisches Feld     JSON mit Schema, für Pages PM undurchsichtig
                     → Abschlusskriterien · Runbook-Schritte ·
                       Testmatrix · Feature-Matrix · Richtlinienregeln
```

**Der Maßstab, an dem entschieden wird:**

```text
Rechnet Pages PM darüber?

  ja    Ist-Umfang aus dem Verlauf (§7.5, R6)
        „was stammt nicht von uns?“ (Z5)
        „welche Arbeit ging an DEPLOY-03?“ (§7.6.1, R9)
        → geführte Nebenfolge

  nein  „trägt K2 den Stand erfüllt?“ – nur am Gegenstand gelesen
        „welche Zelle der Matrix ist leer?“ – beim Rendern sichtbar
        → dynamisches Feld
```

**Das Schema gehört zur Fachart, nicht zum Gegenstand.** Alle Vorgänge teilen
dasselbe Schema für ihre Abschlusskriterien.

```text
Fachart Vorgang   Schema: Abschlusskriterien = [{schluessel, text, stand}]
#9e2b             Wert:   [{K1, „…“, erfüllt}, {K2, „…“, offen}]
#4c19             Wert:   [{K1, „…“, offen}]
                  zwei Werte, ein Schema
```

**Form:** JSON Schema. Der Schematext steht in der Fachvorlage in §7 – nicht
zusätzlich in der Umsetzung, sonst wäre dieselbe Vorlage zweimal beschrieben
(§3.2). Eine Fachart trägt **höchstens ein** dynamisches Feld; zwei wären zwei
Strukturen mit einer Vorlage und nach P-012 zu prüfen.

**Die Auflösungsgrenze ist zugleich eine Zuständigkeitsgrenze.** Pages PM führt
Nachweise – und zwar genau in seiner eigenen Auflösung. Darunter ist es nicht
zuständig.

```text
Pages PM führt        #9e2b abgeschlossen 08-12, Prüfung: Dani
                      → ein Nachweis, in Objektauflösung

Pages PM führt nicht  welcher Testfall lief, welches Review es freigab,
                      welcher Commit es enthielt
                      → das führt die Schnittstelle

Brücke                Beitrag  git:9f2c1ab · #d5aa
                      nennt beide Seiten, kopiert keine (§3.2)
```

**Auswahlgrund:** (c) hält die Zahl der Gegenstände an der Zahl der Fachvorlagen
fest und lässt trotzdem berechnen, was berechnet werden muss.

**Kosten:** Eine dritte Kategorie, die erklärt werden muss – und die Versuchung,
alles hineinzulegen. Dagegen steht der Maßstab oben. Ein Feldeintrag ist nicht
Ziel einer Kante.

**Beispiel**

```text
Vorgang #9e2b
  feste Felder        Zustand = in Arbeit · Dringlichkeit = hoch
  Nebenfolge          Zustandsverlauf, Herkunft
  dynamisches Feld    Abschlusskriterien
                        K1 „… nie der Schlüssel.“         erfüllt
                        K2 „… Platzhalter aus ADR #17ad.“ offen
```

**Gegenbeispiel:** Ein Feldeintrag, der eigene Verantwortung, einen eigenen
Zustand oder eigene Beziehungen braucht, ist keiner mehr – dann ist die Fachart
nach P-012 zu prüfen.

---

## 5. Kernabläufe

### A – Kleine direkte Änderung

**Ohne diesen Ablauf** *(offen – Archiv-PM, §12.3; der Scrum Guide ist beispielfrei)*

```text
Variante 1 – jede Kleinigkeit bekommt ein KEP-Lite:
  „Startseite zeigt falschen Projektnamen“
  Verwaltung: 15 Minuten. Arbeit: 3 Minuten.

Variante 2 – gar keine Bedingung:
  #x „erledigt“   – laut wem? woran?
```

**Aufgabe:** Eine begrenzte Änderung ohne Alternativenentscheidung soll ohne
Zusatzformalität durchlaufen.

**Kontextquelle:** Scrum Guide 2020, Definition of Done; Tracker-Praxis.
*Was sie sagt:* Ohne vorab benannte Abschlussbedingung ist „fertig“ eine
Einzelmeinung.

**Festlegung:** Zwei Ausprägungen, unterschieden durch eine Frage – **muss
jemand ein bestimmtes Ergebnis prüfen?**

| | A1 – eigener Vorgang | A2 – Nebenbei-Beitrag |
|---|---|---|
| Anlass | ein benanntes Ergebnis wird zugesagt | Kleinarbeit im Vorbeigehen |
| Träger | ein Vorgang mit Abschlusskriterien | ein Beitrag an einem Sammelvorgang (§7.6.1) |
| Verwaltungshandlung | Vorgang anlegen, Kriterium, Erfüllungsstand | genau eine: der Beitrag nennt eine Kurzkennung |
| Nachweis | Erfüllungsstand je Kriterium | keiner; der Beitrag ist der Beleg |
| Sichtbarkeit im Sprint | als Vorgang | als Beitrag im Zeitraum |

**Auswahlgrund:** A1 vermeidet Variante 2, A2 vermeidet Variante 1. Wo die
Verwaltung teurer wäre als die Arbeit, wird nicht sorgfältiger erfasst, sondern
gar nicht.

**Beispiel**

```text
A1:  Anlass → Vorgang → Umsetzung → Prüfung → Abschluss
A2:  Anlass → Beitrag mit Kurzkennung → fertig
```

**Gegenbeispiel:** Dauerhaft wirksame Alternativenentscheidungen wechseln in
Ablauf B. A2 endet dort, wo ein Ergebnis zugesagt wird.

### B – Entscheidungsbedürftige Änderung

**Ohne diesen Ablauf** *(belegt: PEP 1 verlangt „Rejected Ideas“ als Pflichtteil)*

```text
Entscheidung: „Wir nehmen eine gemeinsame Fallback-Kette.“
Ein halbes Jahr später: „Warum nicht pro Anzeigeort?“
Antwort: weiß niemand mehr. Die Abwägung wird noch einmal geführt –
mit demselben Ergebnis oder, schlimmer, mit einem anderen.
```

**Aufgabe:** Eine Änderung mit Alternativen muss kontrolliert entschieden,
umgesetzt und geprüft werden.

**Kontextquelle:** Kubernetes Enhancement Proposals; Python PEP; Rust RFC.
*Was sie sagt:* Diese Verfahren verlangen vor der Umsetzung Problem, Motivation,
Vorschlag, verworfene Alternativen und Abnahmekriterien. Die Annahme ist
ausdrücklich nicht der Abschluss.

**Festlegung:** Untersuchungsvorgang, KEP-Lite, begründete Entscheidung,
Umsetzungs-Vorgänge und erfüllte Kriterien bilden eine Kette.

**Auswahlgrund:** Der KEP-Prozess kommt ohne Gremium aus und erzwingt trotzdem
Alternativen. „Lite“ bezeichnet die Kürzung: kein mehrstufiges Review, keine
Sponsorenrolle, keine Freigabestufen.

**Beispiel:** `Problem → KEP-Lite → Entscheidung → Vorgang → Kriterien erfüllt`
Ausgeführt in §9.2.

**Gegenbeispiel:** Ein KEP-Lite ohne Entscheidung ist keine Umsetzungserlaubnis.
Ein KEP-Lite mit erfundener Gegenoption ist eine Scheinalternative (Anhang A.1).

### C – Hierarchische Arbeit

**Ohne diesen Ablauf** *(belegt: NASA WBS Handbook 3.5.4 „Incorrect Element Hierarchy“ – der Verstärker ist kein Unterelement des Senders; Abschnitt 4.3 legt Ablauflogik in den Terminplan, nicht in die Gliederung)*

```text
Der belegte Fall – Gleichrangiges wird untergeordnet:

  falsch                     richtig
  Teilsystem A               Teilsystem A
    └─ Sender                  ├─ Sender
        └─ Verstärker          └─ Verstärker

Dasselbe in Pages PM – Reihenfolge in der Hierarchie ausgedrückt:

Epos #3f70
  ├─ [1] #9e2b   ├─ [2] #4c19   └─ [3] #8a11

#4c19 und #8a11 dürfen gleichzeitig laufen – das sagt die Nummerierung nicht.
Zwei Leute warten aufeinander, ohne Grund.
```

**Aufgabe:** Umfangreiche Arbeit muss zerlegbar sein.

**Kontextquelle:** NASA WBS Handbook 2.2, 3.5.4 und 4.3; Epic-, Story- und
Subtask-Praxis.
*Was sie sagt:* Die Zerlegung deckt die Elternarbeit vollständig ab und ist
produktorientiert. Reihenfolge ist eine getrennte Aussage.

**Festlegung:** Vorgänge können Eltern- und Kindvorgänge besitzen. Reihenfolge
wird **nicht** über die Hierarchie geführt, sondern über `depends_on` (§8.1).

**Auswahlgrund:** Wird Reihenfolge in die Hierarchie gelegt, lässt sich
paralleles Arbeiten an Geschwistern nicht mehr ausdrücken.

**Kosten:** Zwei Strukturen über denselben Objekten.

**Beispiel**

```text
Gliederung             Reihenfolge
  #3f70                  #9e2b
  ├─ #9e2b                 ├─ #4c19
  ├─ #4c19                 └─ #8a11      (dürfen parallel)
  └─ #8a11
```

**Gegenbeispiel:** Aus der Hierarchie folgt keine zeitliche Reihenfolge. Eine
von Hand gepflegte Schrittliste wäre eine zweite, abweichbare Wahrheit.

### D – Sprint planen und fortschreiben

**Ohne diesen Ablauf** *(offen – Archiv-PM, §12.3; der Scrum Guide sagt zur Vollständigkeit des Ist-Umfangs nichts)*

```text
Sprint enthält nur ausgewählte Arbeit:

Plan  {#9e2b, #4c19}       Ist laut Sprint  {#9e2b, #4c19}
Erledigt: #9e2b            → „eine von zwei, gute Planung“

Tatsächlich liefen daneben #7b0d, #88ce, #a103, #c73e, #d5aa.
Der Bericht schmeichelt dem Plan – systematisch, jedes Mal.
```

**Aufgabe:** Ein Sprint braucht ein Ziel, einen anpassbaren Plan und eine
vollständige Aussage darüber, was im Zeitraum tatsächlich gearbeitet wurde.

**Kontextquelle:** Scrum Guide 2020: das Sprint Backlog ist ein Plan der
Entwickler und wird laufend angepasst.
*Was sie sagt:* Der Plan ist veränderlich; das Sprintziel nicht. Zur
Vollständigkeit des Ist-Umfangs sagt der Guide nichts – insoweit
Eigenentscheidung.

**Optionen für den Ist-Umfang**

```text
(a)  nur die ausgewählte Arbeit          Ist = Plan, bricht wie oben
(b)  jede im Zeitraum bearbeitete Arbeit der Sprintprojekte
     abgeleitet aus dem Zustandsverlauf, nicht abwählbar
(c)  wie (b), zusätzlich von Hand gepflegt
     bricht an der zweiten Wahrheit
```

**Festlegung:** (b). Sieben Aussagen bleiben unterscheidbar:

| Aussage | Wie sie entsteht | Am Fall |
|---|---|---|
| **Sichtung** | benannter Schritt vor der Planung | 08-03: Eingang durchgesehen, #88ce verworfen |
| **Sprintziel** | ausdrücklich, genau eines | „JSON-Ausgang in der show-Sicht“ |
| **Anfänglicher Umfang** | beim Wechsel in *aktiv* festgeschrieben | `[#7c40, #2e91]` |
| **Vorhaben** | alle Vorgänge mit Sprintauswahl; änderbar, und es wirkt | `{#7c40, #2e91, #9a03}` |
| **Ist-Umfang** | abgeleitet aus dem Zustandsverlauf | `{#7c40, #2e91, #9a03}` |
| **Sprintrolle** | ausdrücklich nur bei Abweichung vom Regelfall | #9a03 = dazwischengekommen |
| **Übernahme** | abgeleitet: geplant, nicht aufgelöst, später erneut geplant | `{#7c40}` |

**Träger des Sprints ist eine Menge von Projekten,** nicht genau eines.

**Auswahlgrund:** Bei (a) misst der Sprint nur seinen eigenen Plan. Bei ein bis
fünf Personen ist die Durchsatzzahl statistisch bedeutungslos, der Anteil
ungeplanter Arbeit dagegen unmittelbar handlungsleitend.

**Kosten:** Vollständigkeit gilt nur für **erfasste** Arbeit. Was nie ein Vorgang
wird, misst auch dieser Sprint nicht.

**Sichtung (Soll).** Vor der Planung wird der Eingang durchgesehen; jeder
Eintrag erhält eines von drei Ergebnissen: *bereit*, *verworfen* mit Grund, oder
er bleibt mit einer Notiz liegen. *Auswahlgrund gegen eine harte Bedingung:* Ein
Gebot, das den Sprintstart blockiert, trifft die Teams mit dem längsten Eingang
und wird dann umgangen.

**Beispiel:** ausgeführt in §9.4.

**Gegenbeispiel:** Den ursprünglichen Plan nachträglich umzuschreiben macht die
Änderung unsichtbar.

### E – Fehler, Abweichung und Störung

**Ohne diesen Ablauf** *(belegt: Google SRE, Incident Response – die Wiederherstellung hat Vorrang vor der Ursachensuche)*

```text
Variante 1 – alles ist ein Fehler:
  Ausgabe 40 Minuten unlesbar → Vorgang „Fehler“, erledigt, fertig.
  Gelernt wurde nichts. Es passiert wieder.

Variante 2 – alles bekommt ein Postmortem:
  Ein roter Test → Zeitleiste, Ursachenbild, Maßnahmen.
  Nach drei Wochen schreibt niemand mehr eines.
```

**Aufgabe:** Probleme sollen kontrolliert behandelt und ausgewertet werden.

**Kontextquelle:** Google SRE, Incident Response und Postmortem-Kultur.
*Was sie sagt:* Bei einer Störung hat die Wiederherstellung Vorrang. Die
Auswertung erfolgt danach, ohne Schuldzuweisung. Nicht jeder Fehler verlangt
eine Auswertung.

**Festlegung:** Drei Schweregrade mit drei Trägern:

| Fall | Träger | Merkmal |
|---|---|---|
| begrenzter Fehler | Vorgang der Art *Fehler* | keine Betriebswirkung |
| Soll-Ist-Abweichung | Vorgang oder – ab zwei zusammengehörenden Befunden – Drift-Bericht | erwarteter und beobachteter Zustand benannt |
| Störung | Vorgang plus Postmortem | Betriebswirkung; zuerst sicherer Zustand |

**Auswahlgrund:** Drei Schweregrade statt eines, weil sonst eine der beiden
Varianten eintritt.

**Auslöser für ein Postmortem (Erwartung, §12.2):** ab einer Betriebswirkung,
die außerhalb des Teams bemerkt wurde. *Begründung:* Genau dann ist der Schaden
größer als der Aufwand der Auswertung, und die Frage „hat es jemand gemerkt?“
ist ohne Ermessen beantwortbar. Der Wert wird nach den ersten drei Störungen
überprüft.

**Beispiel:** ausgeführt in §9.5.

**Gegenbeispiel:** Ein einzelner roter Test ohne Betriebswirkung verlangt kein
Postmortem.

### F – Import und Entwicklungsverlauf

**Ohne diesen Ablauf** *(belegt: W3C PROV-DM – Entität, Agent, Aktivität, Verwendung, Erzeugung, Ableitung und Zuordnung sind getrennte Arten)*

```text
Eine Kante für alles:

Feature-Matrix — #9e2b — KEP-Lite #8c21 — ADR #17ad

Frage: „Was stammt nicht von uns?“   → nicht beantwortbar
Frage: „Was setzt #8c21 um?“         → nicht beantwortbar
Vier Aussagen, eine Kante, null Antworten.
```

**Aufgabe:** Herkunft, Ableitung, Tätigkeit und Verantwortung müssen als
unterscheidbare Beziehungen lesbar sein.

**Kontextquelle:** W3C PROV-DM; Importer-Praxis.
*Was sie sagt:* Wer etwas benutzt hat, wer es erzeugt hat, woraus es entstand und
wer dafür einsteht sind vier verschiedene Aussagen.

**Festlegung:** Fremdquellen, interne Entscheidungen, Vorgänge und Änderungen
werden über genaue Herkunft (P-006) und typisierte Beziehungen (P-008)
verbunden.

**Auswahlgrund:** PROV-DM liefert das Begriffsraster, an dem Pages PM prüft, ob
eine benötigte Aussage fehlt.

**Beispiel:** ausgeführt in §9.6.

**Gegenbeispiel:** Eine Übersicht darf kein zweiter, unabhängig gepflegter
Inhaltsspeicher werden.

---

## 6. Fachgegenstände im Überblick

**§6 ist die einzige Stelle, an der der Reifegrad steht.** Eine vorhandene
Vorlage in §7 ersetzt die Annahme nicht (§2).

**Rahmen** – keine Fachgegenstände (P-014, §7.3): *Projekt* und *Bereich*,
beide im Reifegrad **Arbeitsstand**, Vorlage in §7.4.

### 6.1 Angenommene Facharten

| Fachgegenstand | Zweck | Kontextquelle und was sie sagt | Vorlage | Reifegrad |
|---|---|---|---|---|
| **Sprint** | Ziel und anpassbaren Plan für einen Zeitraum führen. | Scrum Guide 2020: das Sprint Backlog ist ein Plan der Entwickler. | §7.5 | geplant *(Praxis belegt)* |
| **Vorgang** | Ausführbare Arbeit oder einen steuerbaren Befund führen. | Work-Item-Praxis; Scrum Guide zur Definition of Done. | §7.6 | Arbeitsstand *(Praxis belegt)* |
| **KEP-Lite** | Eine Änderung vor ihrer Umsetzung kontrolliert entscheiden. | Kubernetes KEP / Python PEP / Rust RFC. | §7.7 | geplant *(Praxis belegt)* |
| **ADR** | Eine dauerhaft wichtige technische Entscheidung festhalten. | Nygard; MADR. | §7.8 | geplant |
| **Richtlinie** | Wiederholt geltende Regeln auffindbar halten. | Praxis versionierter Policy-Dokumente; BCP 14. | §7.9 | geplant *(Praxis belegt)* |
| **Runbook** | Wiederherstellungsschritte unter Druck ausführbar halten. | Google SRE zu Playbooks; AWS Systems Manager. | §7.10 | geplant |
| **Postmortem** | Aus folgenreichen Störungen lernen. | Google SRE, Postmortem-Kultur. | §7.11 | geplant |
| **Drift-Bericht** | Mehrere Soll-Ist-Abweichungen gemeinsam bewerten. | Drift-Erkennung in IaC-Werkzeugen: die Sammelansicht ist die Leistung. | §7.12 | geplant *(Beleg ausstehend, §12.3)* |
| **Feature-Matrix** | Varianten über mehrere Merkmale vergleichen. | Vergleichstabellen in Produktentscheidungen. | §7.13 | geplant *(Beleg ausstehend, §12.3)* |
| **Testmatrix** | Kombinationen vollständig sichtbar machen. | Kombinatorische Testpraxis (NIST). | §7.14 | geplant |
| **System-Spezifikation** | Gemeinsames fachliches System-Soll festhalten. | arc42, Bausteinsicht und Querschnittliche Konzepte. | §7.15 | geplant *(Praxis belegt)* |
| **Ablauf-Spezifikation** | Normal-, Fehler- und Ausnahmeabläufe festlegen. | arc42, Laufzeitsicht. | §7.16 | geplant |

**Zwei Facharten tragen einen ausstehenden Beleg.** Beide Prüffragen liegen bei
der archivierten PM (§12.3). Bleibt eine Antwort leer, fällt die Art auf
*empfohlen* zurück.

| Art | Prüffrage nach P-012 |
|---|---|
| Feature-Matrix (§7.13) | Lebt die Tabelle nachweislich unabhängig vom KEP-Lite weiter? |
| Drift-Bericht (§7.12) | Gibt es einen Fall, in dem ein einzelner Abweichungsvorgang nachweislich nicht genügt hat? |

**Warum §9.2 die Feature-Matrix nicht belegt.** Der dortige
Untersuchungsvorgang `#a1f4` ist erfundene Anschauung, kein Vorgang, den es
gegeben hat:

```text
untauglich   „#a1f4 erzeugte die Matrix am 07-28, sie überdauerte
              die Entscheidung“
             → aus §9.2 zitiert, also aus einem Beispiel dieser
               Spezifikation. Ein Ringschluss.

A.3          „Mock-Daten sind Darstellung, keine Herkunft.“
```

Ein Beispiel darf einen Mechanismus zeigen. Es darf nie belegen, dass ein
Ablauf wirklich vorgekommen ist.

**Zur System-Spezifikation:** Ihre Prüffrage lautete *Gibt es zwei Komponenten,
die dieselbe Regel doppelt beschreiben?*

```text
verifies      Angabe in §7.7  UND  Beziehungsart in §8.1
supersedes    Angabe in §7.9  UND  Beziehungsart in §8.1
→ zweimal dieselbe Aussage; behoben in Fassung 6
```

Zusätzlich ist diese Spezifikation selbst eine System-Spezifikation.

### 6.2 Geprüfte, nicht angenommene Facharten

| Fachart | Zweck | Prüffrage nach P-012 | Vorlage |
|---|---|---|---|
| **Prüfnachweis** | Erfüllung eines bestimmten Kriteriums nachweisen. | Welche Schnittstelle erzeugt einen Nachweis, ohne zu rauschen und ohne zweiten Bestand? | Anhang C.1 |
| **Arbeitsdokumentation** | Ziel, Stand, Prüfplan und Abschluss eines Arbeitszusammenhangs festhalten. | Gibt es einen Arbeitszusammenhang über mehrere Systeme, dessen Stand kein Repository kennt? | Anhang C.2 |

Eine nicht angenommene Fachart wird erst aufgenommen, wenn ihre Prüffrage in
einem wirklichen Ablauf mit Ja beantwortet ist. Ähnlichkeit zu einer Quelle
genügt nicht.

---

## 7. Fachvorlagen

### 7.1 Vorlagenform

Jede Vorlage beschreibt eine Fachart nach demselben Muster: **Zweck**;
**Kontextquelle / Was sie sagt**; **Auswahlgrund und Kosten** dort, wo sich die
Vorlage erkennbar entscheidet; **Pflichtangaben** mit der Spalte *Pflicht ab*;
**optionale Angaben**; **Zustände und Übergänge**; **fachliche Prüfregeln**;
**Verantwortung**; **Beispiel**; **Gegenbeispiel**.

Eine Vorlage nennt **keine** Feldreihenfolge, keine Überschriften, keine
Dateinamen und keine Speicherform – das ist Darstellung (§3.2).

**Was *Pflicht ab* heißt, am Fall:**

```text
Pflicht ab Anlage   ohne sie kann der Gegenstand nicht angelegt werden
Pflicht ab bereit   #88ce darf ohne Dringlichkeit im Eingang liegen,
                    aber nicht nach bereit wechseln
– (optional)        der Blockadegrund existiert außerhalb von blockiert
                    fachlich nicht
```

#### 7.1.1 Pflicht gehört zum Zustand

**Ohne diese Regel** *(belegt: Kubernetes-KEP-Prozess mit stufenabhängigen Pflichtabschnitten)*

```text
Alle Pflichtangaben schon beim Anlegen:

„Startseite zeigt falschen Namen“ notieren
  → Art? Dringlichkeit? Abschlusskriterium? Titel in en?
Vier Fragen für eine Zeile im Vorbeigehen.
Ergebnis: Es wird nicht notiert. Es wird vergessen.
```

**Aufgabe:** Ein Gegenstand muss früh erfassbar sein, ohne dass die Anforderungen
an ihn dauerhaft sinken.

**Festlegung:** Jede Pflichtangabe nennt die **Schwelle**, ab der sie verlangt
ist. Es gelten sechs Regeln:

1. **Das Schema ist fest.** Welche Angaben es gibt, hängt nie vom Zustand ab.

   ```text
   Eingang   Dringlichkeit existiert, ist leer, ist filterbar
             find(dringlichkeit = leer) → die ungesichteten Einträge
   falsch    Dringlichkeit existiert im Eingang nicht
   ```
2. **Jede Angabe nennt eine Schwelle.** Sonst ist sie optional – und wird
   ausdrücklich so bezeichnet.
3. **Optional heißt: es gibt einen Fall, in dem die Angabe fachlich nicht
   existiert** – nicht, dass man sie weglassen darf.
4. **Kein Vorgabewert für eine Angabe, die ein Urteil ausdrückt.**

   ```text
   zulässig    Angelegt am = 2026-08-03   (Spur, keine Aussage)
   unzulässig  Dringlichkeit = mittel     (Urteil, das niemand gefällt hat)
   ```
5. **Der Zustand wird weder vorbelegt noch abgeleitet.** Vollständigkeit
   *erlaubt* einen Zustand, sie *bewirkt* ihn nicht.
6. **Rückwege löschen nichts.** Die Schwelle ist eine Untergrenze.

**Kosten:** Die Gültigkeit ist nicht mehr am einzelnen Feld ablesbar.

**Gegenbeispiel:** Eine Schwelle senkt nie eine Muss-Regel aus §4 auf Dauer ab.

**Zu Regel 6:** Die Schwelle ist erreicht, sobald sie **einmal** erreicht war.
Sie ist damit nicht am gegenwärtigen Zustand ablesbar: Ein Vorgang, der von
*bereit* nach *in Klärung* zurückgeht (§7.1.2), bleibt an die einmal erreichte
Untergrenze gebunden. Fällt ein Gegenstand vor der Schwelle heraus – etwa ein
unmittelbar aus dem *Eingang* verworfener Vorgang –, hat er sie nie erreicht.

#### 7.1.2 Übergänge nur bei fachlichem Grund einschränken

**Ohne diese Regel** *(belegt: Open Guide to Kanban v2025.7 – der Arbeitsfluss
wird definiert und aufgrund empirischer Erkenntnisse weiterentwickelt; Jira und
OpenProject – Übergänge sind gerichtete, je Richtung konfigurierbare Kanten)*

*Was die Quellen tragen:* dass der Arbeitsfluss definiert und aufgrund
empirischer Erkenntnisse weiterentwickelt wird und dass verbreitete Werkzeuge
gerichtete Übergänge je Richtung ausdrücken
können – damit auch Rückwege –, nicht, dass eine bestimmte Kante erlaubt sein
muss. Die normative Begründung kommt aus dem
Pages-PM-Betriebsfall selbst:

```text
Ein Vorgang gilt als bereit.
Eine Grundfrage wird wieder offen.
Der Rückweg nach in Klärung fehlt.

→ er bleibt fälschlich bereit,
  oder er heißt blockiert, obwohl nichts hakt,
  oder es entsteht ein zweiter Vorgang für dieselbe Arbeit.

Drei Wege, und alle drei sagen etwas Unwahres.
```

**Aufgabe:** Die Übergangstabelle soll fachlich Unmögliches verhindern, nicht
gewöhnliche Richtungswechsel. Pages PM schreibt weder Scrum noch Kanban
vollständig vor (§3.2); ein erzwungen linearer Lebenslauf wäre eine solche
Vorschrift durch die Hintertür.

**Festlegung:**

1. **Ein Zustand ist eine Tatsachenbehauptung, keine Wegmarke.** Die
   Übergangstabelle muss zulassen, dass der gegenwärtige fachliche Sachverhalt
   wahrheitsgemäß ausgedrückt wird.
2. **Die Beweislast liegt beim Verbot eines fachlich möglichen Rück- oder
   Seitenwegs.** Ist der Zielzustand für denselben Gegenstand sachlich
   erreichbar, wird die Kante nur bei benanntem Schaden verboten – und der
   Grund steht in der Vorlage. Die Regel verlangt **keinen** vollständigen
   Graphen: Ein Sprung, dessen Zielzustand für den Gegenstand gar nicht wahr
   sein kann, bleibt ausgeschlossen, ohne dass es dafür eines Schadens bedarf.

   ```text
   zulassen    bereit → in Klärung
               Rückweg, Zielzustand ist wahr, kein Schaden benannt
   ausschließen
               Eingang → in Prüfung
               nichts wurde bearbeitet, es gibt nichts zu prüfen
   ```
3. **Endgültigkeit ist eine eigene Entscheidung.** Sie folgt nicht daraus, dass
   ein Zustand spät im üblichen Ablauf steht, und sie wird je Zustand einzeln
   begründet.
4. **Schwelle und Zustand sind zwei Aussagen.** Ein Rückweg senkt keine einmal
   erreichte Pflichtschwelle (§7.1.1, Regel 6); umgekehrt bindet eine erreichte
   Schwelle den Gegenstand nicht an den Zustand, in dem er sie erreicht hat.

**Kosten:** Der Verlauf wird länger und weniger vorhersagbar. Aus dem
gegenwärtigen Zustand ist nicht mehr ablesbar, was ein Gegenstand schon hinter
sich hat; wer das wissen will, liest den Verlauf (P-010) – wofür er geführt
wird.

**Gegenbeispiel:** „Du warst schon eingeplant, deshalb darfst du nicht mehr
ungeklärt sein“ ist keine fachliche Regel, sondern eine Prozessfessel.

**Reichweite am Stichtag:** Die Regel ist für den Vorgang (§7.6) vollständig
angewandt. §7.5 (Zeitkasten mit eigenem, begrenztem Lebenslauf) und §7.7
(Entscheidungsdokument) tragen ihre Einschränkungen aus dem Gegenstand selbst;
sie sind daran noch nicht einzeln nachgeprüft.

### 7.2 Angabenarten

| Art | Bedeutung | Regel |
|---|---|---|
| **Fachtext** | mehrsprachige inhaltliche Aussage | Sprachkarte nach P-005 |
| **Kurzwert** | Wert aus einer hier benannten Liste | einsprachig, unübersetzt, nicht frei erweiterbar |
| **Zeitpunkt** | Zeitpunkt oder Datum | fachlich benannt; Bearbeitungsspuren sind keine Fachangabe |
| **Verweis** | zeigt auf genau einen Fachgegenstand | über die unveränderliche Kennung (P-001) |
| **Merkmalsmenge** | ungeordnete Menge von Schlüsseln | Reihenfolge bedeutungslos |
| **Nebenfolge** | geführte, abfragbare Folge (P-014) | Einträge tragen eine Platznummer, keine Kennung |
| **Punktfolge** | Inhalt eines dynamischen Feldes | gegen das Schema der Fachart geprüft, nicht abfragbar |
| **Fremdtext** | übernommener Text in genau einer Sprache | trägt eine BCP-47-Kennung, wird nicht übersetzt |
| **Person** | eine Verantwortung nach P-004 | Funktion und Person getrennt genannt |

**Nebenfolge gegen Punktfolge, am Fall:**

```text
Nebenfolge   Zustandsverlauf #7c40
             „welche Vorgänge waren im August in Arbeit?“
             → eine Abfrage über alle Gegenstände

Punktfolge   Abschlusskriterien #9e2b
             „trägt K2 den Stand erfüllt?“
             → am Gegenstand gelesen, nicht gesucht
```

**Abgrenzungsbeispiele:**

```text
Kurzwert    „angenommen“ mit Übersetzung {de: „angenommen“, en: „accepted“}
            ist kein Kurzwert mehr, sondern Inhalt – und nicht mehr summierbar.

Fremdtext   Ein selbst geschriebener Kommentar in nur einer Sprache
            ist kein Fremdtext, sondern eine unvollständige Sprachkarte.

Punktfolge  Drei Sätze Fließtext mit „erstens, zweitens, drittens“
            ist keine Punktfolge – die Einträge sind nicht einzeln benannt.

Zeitpunkt   „Geändert am“ ist eine Bearbeitungsspur, keine Fachangabe;
            „Gültig ab“ ist eine.
```

**Warum manche Namen nicht übersetzt werden dürfen.**

```text
falsch   Sprache „de“ heißt {de: „Deutsch“, en: „German“, fr: „Allemand“}
         → wer liest die Liste, bevor er eine Sprache gewählt hat?
richtig  Sprache „de“ heißt „Deutsch“ – Eigenbezeichnung, einsprachig
```

Dieselbe Falle bei der Beschriftung von Kurzwerten: Sie wird außerhalb der
Fachdaten gepflegt.

**Auswahlgrund für den Fremdtext:** Übernommener Text ist keine Pages-PM-Aussage.
**Kosten:** Eine Anzeige enthält Texte, die in der gewählten Sprache nicht
vorliegen; der Fallback greift hier nicht.

### 7.3 Gemeinsames Mindestraster

Jeder **Fachgegenstand** trägt diese Angaben. Sie sind die Grundlage der
gemeinsamen Suche (P-011) und werden in den Vorlagen nicht wiederholt.

| Angabe | Art | Pflicht ab | Regel |
|---|---|---|---|
| Kennung | Verweisziel | Anlage | unveränderlich (P-001) |
| Kurzkennung | Kurzwert | Anlage | unveränderlich, installationsweit eindeutig (§7.4) |
| Fachart | Kurzwert | Anlage | einer der Namen aus §6 |
| Titel | Fachtext | Anlage | benennt den Gegenstand, nicht seinen Inhalt |
| Zustand | Kurzwert | Anlage | aus der Liste der Vorlage; kein Vorgabewert |
| Projekt | Verweis | Anlage | genau eines, unmittelbar (P-002) |
| Bereiche | Merkmalsmenge | – (optional) | mehrfach zulässig (P-003) |
| Verantwortung | Person je Funktion | nach Vorlage | vier Funktionen (P-004) |
| Herkunft | Nebenfolge | nur bei Übernahme | Quellsystem, Fundstelle, Ausschnitt, Ursprungsdatum (P-006) |
| Angelegt am / Geändert am | Zeitpunkt | Anlage | Bearbeitungsspur, keine fachliche Aussage |
| Zustandsverlauf | Nebenfolge | Anlage | für die Ereignisse aus P-010 |

**Ausnahme:** *Projekt* und *Bereich* sind **Rahmen** (P-014). Sie tragen das
Mindestraster nicht: keine Kennung im Objektgraphen, kein Zustandsverlauf, kein
Endpunkt einer Kante. Der *Sprint* ist ein Fachgegenstand, trägt aber statt
einer Projektzugehörigkeit eine **Projektmenge** (§7.5).

### 7.4 Kennungen, Adressierung und Rahmen

**Ohne diese Regel** *(belegt: Berners-Lee; siehe P-001)*

```text
Ein Beitrag im Fremdsystem nennt:  „siehe Fallback-Kette Renderer“
Der Titel ändert sich.
Der Beitrag zeigt auf nichts.
```

**Aufgabe:** Ein Gegenstand muss dauerhaft eindeutig verweisbar sein und
zugleich außerhalb von Pages PM genannt werden können.

**Optionen**

```text
(a)  laufende Nummer je Fachart
     bricht bei Übernahme aus einem Archiv: das übernommene Objekt
     bekommt eine Nummer, die seine Entstehung falsch einordnet
(b)  nur die Kennung
     019826f1-7c3a-7def-8000-1a2b3c4d5e6f – unaussprechbar
(c)  Kennung plus kurze, getrennt geführte Kurzkennung
```

**Festlegung:** (c). Innere Identität und äußere Adressierung werden getrennt
geführt:

| Angabe | Eigenschaft | Wozu |
|---|---|---|
| **Kennung** | unveränderlich, undurchsichtig, nur intern verwendet | innere Beziehungen nach §8 |
| **Kurzkennung** | unveränderlich, kurz, installationsweit eindeutig | äußere Auflösung; Beiträge, Gespräch, Commit-Trailer |
| **Anzeigename** | veränderlich, enthält die Kurzkennung | Lesbarkeit |

**Auswahlgrund:** Laufende Nummern behaupten eine Reihenfolge, die es nicht
gibt. Eine einzige Kennung für inneren und äußeren Zugriff vermischt zwei
Aufgaben: Innerhalb von Pages PM werden Gegenstände über die technische
Kennung verbunden; von außen werden sie ausschließlich über die Kurzkennung
angesprochen. Getrennt geführt, kann die äußere Adressierung später erweitert
werden, ohne innere Beziehungen oder bestehende Kurzkennungen zu ändern.

**Kosten:** Beim Anlegen muss zusätzlich eine kurze Kennung erzeugt und auf
Eindeutigkeit geprüft werden. Sie ist nicht sprechend und nicht aus der
inneren Kennung ablesbar.

**Regeln**

1. Kurzkennungen bestehen zunächst aus vier alphanumerischen Zeichen.
2. Ist der erzeugte Wert bereits vergeben, wird die Erzeugung wiederholt, bis
   ein freier Wert vorliegt. Bestehende Kurzkennungen ändern sich dadurch
   **nie**.
3. **Eine einmal verwendete Kurzkennung wird nie einem anderen Gegenstand
   zugewiesen** – auch nicht nach Löschung des ursprünglichen Gegenstands.
   Alte Verweise dürfen danach ins Leere zeigen.
4. Sie wird **ausschließlich exakt** verglichen. Eine Präfix- oder
   Suffixsuche ist keine Auflösung.
5. Sie ist installationsweit eindeutig, nicht je Fachart.
6. Äußere Auflösung nimmt ausschließlich Kurzkennungen an; die innere Kennung
   ist keine äußere Adresse.
7. Der Anzeigename darf sich jederzeit ändern; **aufgelöst wird ausschließlich
   über die Kurzkennung.**
8. Eine spätere Erweiterung der äußeren Kennungsform ändert keine bestehende
   Kurzkennung und keine innere Beziehung.
9. **(Soll)** Ein Gegenstand mit einer bestehenden Herkunftsangabe wird nicht
   ohne Weiteres gelöscht; die Herkunft ist zuerst zu entfernen.
   *Auswahlgrund:* eine Bremse gegen Versehen – die Eindeutigkeit externer
   Einheiten hält P-006, Regel 1, nicht der Löschschutz.
10. **(Muss)** Ein Gegenstand an einer bestehenden Beziehung wird nicht
    gelöscht – weder als Quelle noch als Ziel.

    ```text
    #4c19 depends_on #9e2b
    DELETE #9e2b, Kante fällt mit
      → #4c19 verliert „wartet auf“, ohne dass jemand es merkt
      → sein Zustand hat sich geändert, ohne Verlaufseintrag (P-010)
    ```

**Kosten von Regel 9 und 10:** Ein Versehen zu löschen kostet zwei Schritte.

**Gegenbeispiel:** Bereichs- und Projektzuordnungen blockieren **nicht** – sie
verschwinden mit dem Gegenstand. Es sind Zuordnungen zu einem Rahmen; ohne
Gegenstand sagen sie nichts.

**Beispiel**

```text
Kennung        019826f1-7c3a-7def-8000-1a2b3c4d5e6f
Kurzkennung    a7k2
Anzeigename    fallback-kette-renderer-a7k2   → löst auf
später         neuer-titel-a7k2               → löst weiterhin auf
Titel allein   fallback-kette-renderer        → löst nicht auf
Kennung allein 019826f1-…                     → löst nicht auf (Regel 6)
```

**Abgrenzung zur technischen Umsetzungsschicht (§1):** Zeichenmenge,
Erzeugungsverfahren, Speicherform und Nebenläufigkeit legt diese
Spezifikation nicht fest. Verlangt ist das beobachtbare Verhalten der Regeln
dieses Abschnitts.

#### Rahmen: Projekt

| Angabe | Art | Pflicht ab |
|---|---|---|
| Schlüssel | Kurzwert | Anlage |
| Titel, Zweck | Fachtext | Anlage / – (optional) |
| Elternprojekt | Verweis auf Projekt | – (optional) |
| Umfangsangabe | Kurzwert: *gewichtet*, *nicht gewichtet* | Anlage |
| Zustand | Kurzwert: *aktiv*, *ruhend*, *abgeschlossen* | Anlage |

**Prüfregeln:** Die Projekthierarchie ist zyklenfrei. Ein Projekt im Zustand
*abgeschlossen* nimmt keine neuen Fachgegenstände auf. Ein Projekt mit
Unterprojekten oder zugeordneten Gegenständen wird nicht gelöscht.

**Pflichtsprachen sind keine Projektangabe** – sie gelten installationsweit
(P-005).

**Zur Umfangsangabe:**

```text
gewichtet         #7c40 groß · #2e91 klein · #9a03 klein
                  Sprint #6f30: „ein großer, zwei kleine“

nicht gewichtet   #7c40 · #2e91 · #9a03
                  Sprint #6f30: „drei Stück“

gemischt          #7c40 groß · #2e91 – · #9a03 –
                  Summe:   „ein Großes“   verschweigt zwei
                  Zählung: „drei Stück“   verschweigt, dass eines groß ist
                  → deshalb am Projekt, nicht am Vorgang
```

*Kosten:* Ein Projekt muss sich festlegen, bevor es Erfahrung damit hat; der
Wechsel gilt erst ab dem nächsten Sprint. *Gegenbeispiel:* Bei ein bis fünf
Personen ist Abzählen oft so treffsicher wie Schätzen.

#### Rahmen: Bereich

| Angabe | Art | Pflicht ab |
|---|---|---|
| Schlüssel | Kurzwert | Anlage |
| Titel | Fachtext | Anlage |
| Zweck | Fachtext | – (optional) |
| Zustand | Kurzwert: *aktiv*, *überholt* | Anlage |

**Prüfregeln:** Bereiche gelten installationsweit; ein Schlüssel ist
unveränderlich; Bereiche haben keine Hierarchie; ein Bereich mit bestehenden
Zuordnungen wird nicht gelöscht.

**Gegenbeispiel:** Wer einen Bereich in Ober- und Unterbereich teilen will, baut
eine zweite Gliederung und widerspricht P-003.

**Beispiel für beide**

```text
Projekt   Pages PM
  Titel            de: „Pages PM“        en: „Pages PM“
  Zweck            de: „Projektarbeit kleiner Teams führbar machen“
  Elternprojekt    Kashasaga
  Umfangsangabe    nicht gewichtet
  Zustand          aktiv

Bereich   i18n
  Titel            de: „Mehrsprachigkeit“  en: „Multilingualism“
  Zustand          aktiv
```

---

### 7.5 Sprint

**Zweck:** Ziel und anpassbaren Plan für einen begrenzten Zeitraum führen und
den Zeitraum vollständig auswerten.

**Kontextquelle:** Scrum Guide 2020, Sprint Backlog.
*Was sie sagt:* Das Sprint Backlog verbindet Sprintziel, ausgewählte Einträge
und den Plan zur Umsetzung. Es wird fortlaufend angepasst; das Sprintziel bleibt.

**Auswahlgrund für die Projektmenge statt eines Projekts:**

```text
Ein Projekt je Sprint:
  Sprint A (Kashasaga)   #7c40  blockiert
  Sprint B (pcs-php)     #2e91  in Arbeit
  Zwei Auswertungen. Keine zeigt, dass hier eine Arbeit lief.

Projektmenge:
  Sprint #6f30  {Kashasaga, pcs-php}
  Ist {#7c40, #2e91},  #7c40 depends_on #2e91
  Eine Auswertung. Die Abhängigkeit liegt sichtbar im Sprint.
```

**Kosten:** „Was geschah in Projekt X im August?“ ist keine Leistung des Sprints
mehr; sie bleibt als Filter über Projekt und Zeitraum beantwortbar (P-011).

**Auswahlgrund für die Trennung von Plan und Ist:** Sonst ist nach dem Sprint
nicht mehr zu unterscheiden, ob der Plan falsch war oder die Umsetzung (Z6).
**Kosten:** Beim Wechsel in *aktiv* entsteht ein zusätzlicher, unveränderlicher
Stand.

#### Pflichtangaben

| Angabe | Art | Pflicht ab | Regel |
|---|---|---|---|
| Projekte | Merkmalsmenge von Verweisen | Anlage | mindestens eines |
| Sprintziel | Fachtext | Anlage | benennt das Ergebnis, nicht die Vorgangsliste |
| Beginn / Ende | Datum | Anlage | Ende nicht vor Beginn |
| Zustand | Kurzwert | Anlage | kein Vorgabewert |
| Anfänglicher Umfang | Nebenfolge von Verweisen | aktiv | beim Wechsel festgeschrieben |
| Vorhaben | abgeleitete Menge | abgeleitet | alle Vorgänge mit Sprintauswahl |
| Ist-Umfang | abgeleitete Menge | abgeleitet | vollständig, nicht von Hand gepflegt |

#### Optionale Angaben

| Angabe | Art | Bedingung |
|---|---|---|
| Review-Notiz, Retrospektiv-Notiz | Fachtext | frühestens im Zustand *abgeschlossen* |
| Abbruchgrund | Fachtext | Pflicht in *abgebrochen*, sonst unzulässig |
| Abschlusszeitpunkt | Zeitpunkt | Pflicht in *abgeschlossen* und *abgebrochen* |

#### Zustände und Übergänge

| Zustand | Bedeutung |
|---|---|
| *geplant* | Ziel und Zeitraum stehen, der Sprint läuft nicht |
| *aktiv* | der Sprint läuft |
| *abgeschlossen* | der Zeitraum ist beendet und ausgewertet |
| *abgebrochen* | vorzeitig beendet |

```text
geplant → aktiv → abgeschlossen
geplant → abgebrochen        aktiv → abgebrochen
```

Kein Rückweg: Ein abgeschlossener Sprint wird nicht wieder aktiv.

#### Fachliche Prüfregeln

1. **Ein Projekt liegt zur selben Zeit in höchstens einem aktiven Sprint.**

   ```text
   zulässig    #6f30 {Kashasaga, pcs-php}   ·  #b204 {Renderer}
   unzulässig  #6f30 {Kashasaga, pcs-php}   ·  #b204 {pcs-php, Renderer}
   ```
2. Der Wechsel in *aktiv* schreibt den anfänglichen Umfang fest.
3. Der Wechsel in *abgeschlossen* verlangt für jeden Vorgang des anfänglichen
   Umfangs eine von drei Auflösungen – abgeschlossen, verworfen oder als
   **Übernahme** einem Nachfolgesprint zugeordnet.
4. Vorgänge, die nach dem Wechsel in *aktiv* ins Vorhaben kommen, tragen die
   Sprintrolle *nachgezogen* oder *dazwischengekommen*.
5. Das Sprintziel wird im Zustand *aktiv* nicht geändert; eine dennoch nötige
   Änderung beendet den Sprint.
6. **Vollständigkeit.** Zum Ist-Umfang gehört jeder Vorgang **eines der
   Sprintprojekte**, der im Zeitraum in einem Arbeitszustand war – *in Klärung*,
   *in Arbeit*, *blockiert*, *in Prüfung* – oder in ihm *abgeschlossen* oder
   *verworfen* wurde. Die Zugehörigkeit folgt aus dem Zustandsverlauf (P-010).

   **Ausnahme Sammelvorgang:** Er zählt nur, wenn im Zeitraum mindestens ein
   Beitrag eingegangen ist. Gezählt wird der Beitrag, nicht der Vorgang.

   ```text
   Sprint 08-03…08-14
     #d5aa  in Arbeit seit Mai, Beiträge [1] 08-05, [2] 08-07  → im Ist-Umfang
     #e11f  in Arbeit seit Mai, keine Beiträge im Zeitraum     → nicht
   ```
7. **Auswertung.** Ein abgeschlossener Sprint macht mindestens sieben Größen
   ablesbar: anfänglicher Umfang, Vorhaben, Ist, Nachgezogenes,
   Dazwischengekommenes, Übernahme und den Anteil über Sammelvorgänge. Bei
   Projekten mit Umfangsangabe *gewichtet* als Summe, sonst als Stückzahl.
8. **Übernahme** ist abgeleitet.

   ```text
   Übernahme       #7c40  in Arbeit,  Sprintauswahl → #b204
   keine Übernahme #7c40  in Arbeit,  Sprintauswahl → leer
                   → offen geblieben, aber nicht weitergeplant
   ```
9. **Zielbeitrag ist keine Zugehörigkeit.** Ob ein Vorgang das Sprintziel trägt,
   sagt allein die Sprintrolle.
10. **Eingangsalter.** Die Auswertung nennt je Sprintprojekt das Alter des
    ältesten ungesichteten Eintrags. Sie beantwortet als einzige Größe die
    Frage, ob das Erfassen noch trägt oder eine Deponie geworden ist.
11. **Übergehungen** nach §7.6, Regel 12 erscheinen als Zahl – ein Befund für
    die Retrospektive, keine Prüfregel.

#### Verantwortung

Pflege: Pflicht im Zustand *aktiv*. Entscheidung: Pflicht für Abbruch.

#### Beispiel

```text
Sprint #6f30
  Projekte             {Kashasaga, pipeline-config-spec-php}
  Sprintziel           de: „JSON-Ausgang der Pipeline-Config in der show-Sicht“
  Beginn / Ende        2026-08-03 / 2026-08-14
  Zustand              aktiv   (seit 2026-08-03)
  Anfänglicher Umfang  [1] #7c40   [2] #2e91
  Vorhaben             {#7c40, #2e91, #9a03}          (abgeleitet)
  Ist-Umfang           {#7c40, #2e91, #9a03}          (abgeleitet)
  Pflege               Dani
```

**Gegenbeispiel:** Ein Sprint ist kein Projekt und kein Arbeitsvorrat – ein
Vorgang, der im Zeitraum nur erfasst, aber nie bearbeitet wurde, gehört nicht
zum Ist-Umfang.

### 7.6 Vorgang

**Zweck:** Ausführbare Arbeit oder einen steuerbaren Befund führen.

**Kontextquelle:** Work-Item-Praxis; Scrum Guide 2020 zur Definition of Done.
*Was sie sagt:* Ohne vorab benannte Abschlussbedingung ist „fertig“ eine
Einzelmeinung.

**Auswahlgrund für Abschlusskriterien am Vorgang:** Die allgemeine
Abschlussdefinition gehört in eine Richtlinie (§7.9) und gilt für alle Vorgänge;
die Abschlusskriterien sind der fallbezogene Teil. **Kosten:** Zwei Stellen sind
zu lesen.

**Auswahlgrund für Zustand und Sprintauswahl als getrennte Angaben:** Der Zustand
*eingeplant* verlangt keinen Sprint.

#### Pflichtangaben

| Angabe | Art | Pflicht ab | Regel |
|---|---|---|---|
| Titel | Fachtext | Eingang | im Eingang genügt **eine** Sprache |
| Beschreibung | Fachtext | Eingang | Anlass und gewünschtes Ergebnis |
| Zustand | Kurzwert | Eingang | kein Vorgabewert |
| Vorgangsart | Kurzwert: *Epos*, *Funktion*, *Fehler*, *Aufgabe*, *Pflege*, *Sammelvorgang* | bereit | unveränderlich nach Wechsel in *in Arbeit* |
| Dringlichkeit | Kurzwert: *niedrig*, *mittel*, *hoch*, *kritisch* | bereit | kein Vorgabewert |
| Umfang | Kurzwert: *klein*, *mittel*, *groß* | bereit | nur bei Projekten mit Umfangsangabe *gewichtet* |
| Abschlusskriterien | Punktfolge im dynamischen Feld | bereit | bei *Funktion* und *Fehler*: mindestens eines |

**Schema des dynamischen Feldes** (P-014):

```text
Abschlusskriterien = [ { schluessel: Kurzwert,
                         text:       Fachtext,
                         stand:      offen | erfüllt } ]
```

**Sprachen im Eingang.** Abweichend von P-005 genügt im Zustand *Eingang* eine
Sprache. *Auswahlgrund:*

```text
Beide Sprachen schon beim Notieren verlangt:
  Titel = {de: „Startseite zeigt falschen Namen“,
           en: „Startseite zeigt falschen Namen“}
Eine Sprachkarte, die vollständig aussieht und keine ist.
Die Lücke im Eingang ist dagegen auffindbar.
```

#### Optionale Angaben

| Angabe | Art | Bedingung |
|---|---|---|
| Elternvorgang | Verweis | zulässige Kombinationen siehe Regel 2 |
| Sprintauswahl | Verweis auf Sprint | die **Planung**; die Ist-Zugehörigkeit ist davon unabhängig |
| Sprintrolle | Kurzwert: *Ziel*, *Unterstützung*, *Verwaltung*, *nachgezogen*, *dazwischengekommen* | nur mit Sprintauswahl |
| Umsetzungsplan, Notizen | Fachtext | |
| Blockadegrund | Fachtext | Pflicht in *blockiert*, sonst unzulässig |
| Übergehungen | Nebenfolge aus Zeitpunkt, übergangener Bedingung, Grund | nur bei Übergehung nach Regel 12 |
| Beiträge | Nebenfolge aus externer Kennung, Zeitpunkt, Kurzbeschreibung (Fremdtext) | nur bei Art *Sammelvorgang* und *Pflege* |
| Beginn / Beendigungszeitpunkt | Zeitpunkt | Beendigungszeitpunkt: Pflicht in *abgeschlossen* und *verworfen*, sonst unzulässig (Regel 18) |

#### Zustände und Übergänge

| Zustand | Bedeutung |
|---|---|
| *Eingang* | erfasst, noch nicht beurteilt |
| *in Klärung* | wird beurteilt: Was ist gemeint? Lohnt es? Wie groß? |
| *bereit* | beurteilt, könnte begonnen werden |
| *eingeplant* | für die nähere Arbeit vorgesehen |
| *in Arbeit* | wird bearbeitet |
| *blockiert* | kann derzeit nicht weitergeführt werden |
| *in Prüfung* | Arbeit beendet, Kriterien werden geprüft |
| *abgeschlossen* | alle Kriterien tragen *erfüllt*; der Abschluss ist festgestellt |
| *verworfen* | ohne festgestellten Abschluss beendet – ein Urteil, das zurückgenommen werden kann |

Die Zustände bilden drei Bereiche. Innerhalb eines Bereichs gilt die
Grundhaltung aus §7.1.2: Es wird nur verboten, was fachlich nicht wahr sein
kann.

```text
Beurteilung   Eingang, in Klärung
Arbeit        bereit, eingeplant, in Arbeit, blockiert, in Prüfung
Ausgang       abgeschlossen, verworfen
```

```text
Eingang     → in Klärung | bereit | verworfen
in Klärung  → Eingang | bereit | verworfen
bereit      → in Klärung | eingeplant | in Arbeit | blockiert | verworfen
eingeplant  → in Klärung | bereit | in Arbeit | blockiert | verworfen
in Arbeit   → in Klärung | bereit | eingeplant | blockiert | in Prüfung |
              verworfen
blockiert   → in Klärung | bereit | eingeplant | in Arbeit | in Prüfung |
              verworfen
in Prüfung  → in Klärung | bereit | eingeplant | in Arbeit | blockiert |
              abgeschlossen | verworfen
verworfen   → in Klärung
abgeschlossen →
```

**Die sechs Regeln, aus denen diese Tabelle folgt:**

1. Zwischen *Eingang* und *in Klärung* gilt beides: Eine begonnene Sichtung
   darf abgebrochen werden, bevor ein belastbares Urteil entstanden ist.
2. Der Eintritt in den Arbeitsbereich führt immer über *bereit*. *bereit* ist
   die Aussage „beurteilt“ und zugleich die Schwelle der Pflichtangaben; ein
   unbeurteilter Vorgang kann weder eingeplant noch bearbeitet noch geprüft
   sein. *in Klärung* darf dabei übersprungen werden, wenn die Beurteilung
   schon im *Eingang* abgeschlossen werden kann; unmittelbar nach *eingeplant*,
   *in Arbeit*, *blockiert* oder *in Prüfung* gelangt ein Vorgang aus der
   Beurteilung nicht.
3. Innerhalb der Arbeit ist jeder Übergang erlaubt – mit einer Ausnahme: *in
   Prüfung* ist nur aus *in Arbeit* oder *blockiert* erreichbar. Geprüft wird
   geleistete Arbeit; ohne sie gibt es nichts zu prüfen.

   ```text
   blockiert → in Prüfung, ausdrücklich gewollt:
     Arbeit ist fertig, die Prüfung kann nicht beginnen
       → blockiert, Grund: Testumgebung nicht verfügbar
     Umgebung wieder da
       → in Prüfung
   *Blockiert* heißt „kann derzeit nicht weitergeführt werden“ –
   das gilt auch für die Prüfung, nicht nur für die Bearbeitung.
   ```
4. Aus der Arbeit führt der Rückweg nach *in Klärung*, nicht nach *Eingang*.
   Neue Erkenntnis macht einen Vorgang wieder klärungsbedürftig, nicht wieder
   unbeurteilt.
5. Nach *abgeschlossen* führt nur *in Prüfung*. Der Abschluss folgt der
   Prüfung, nicht der Arbeit.
6. *verworfen* ist aus jedem Zustand der Beurteilung und der Arbeit
   erreichbar. Für den Ausgang gelten die eigenen Regeln des nächsten
   Abschnitts.

**Die beiden Ausgangszustände sind verschieden endgültig** (§7.1.2, Regel 3).
Der Unterschied liegt nicht darin, ob Arbeit geleistet wurde – ein Vorgang darf
auch aus *in Arbeit* und *in Prüfung* verworfen werden –, sondern darin, ob ein
Abschluss **festgestellt** wurde:

```text
abgeschlossen   der Abschluss wurde festgestellt
                → historisches Ergebnis, kein Rückweg
verworfen       ohne festgestellten Abschluss beendet
                → das Urteil kann zurückgenommen werden,
                  Rückweg nach in Klärung
```

`abgeschlossen` hat keinen Rückweg; eine später erkannte Lücke ist ein neuer
Vorgang mit Verweis auf den alten. Wird dagegen dieselbe verworfene Arbeit
wieder gebraucht, ist es dieselbe Sache und nicht eine neue (Regel 19).

```text
#abcd  „CSV-Ausgabe ergänzen“
08-01  Eingang
08-03  bereit
08-05  verworfen     Grund: Bedarf entfallen
09-12  in Klärung    Grund: neuer Kundenbedarf
09-13  bereit
```

Der Verlauf verliert dabei nichts: Er zeigt anschließend sogar, dass dieselbe
Arbeit einmal bewusst verworfen und später wieder aufgenommen wurde (P-010).

**Warum *in Klärung* ein eigener Zustand ist** *(offen – Archiv-PM, §12.3)*

```text
Ohne den Zustand:
  #88ce  Eingang
  Dani sieht ihn an, 40 Minuten, entscheidet: lohnt nicht.
  Der Sprint zählt diese 40 Minuten nicht (§7.5, Regel 6).
  Und am nächsten Tag fängt jemand anders wieder von vorn an.
```

*Kosten:* ein Zustand mehr, und *in Klärung* kann selbst zur Warteschlange
werden.

#### Fachliche Prüfregeln

1. **Abschluss.** Der Wechsel nach *abgeschlossen* verlangt: jedes
   Abschlusskriterium trägt den Stand *erfüllt*, kein Kindvorgang steht offen,
   und der Beendigungszeitpunkt ist gesetzt (Regel 18). Für *Sammelvorgang*
   gilt §7.6.1.

   ```text
   #9e2b  Abschlusskriterien
     K1  „… nie der Schlüssel.“          erfüllt
     K2  „… Platzhalter aus ADR #17ad.“  erfüllt
   → abgeschlossen zulässig

   Nicht ablesbar: dass K2 am 11.08. einmal durchfiel.
   Ablesbar bleibt der Rückweg in Prüfung → in Arbeit (P-010).
   ```
2. **Hierarchie.**

   | Elternart | zulässige Kindarten |
   |---|---|
   | Epos | Funktion, Fehler, Aufgabe, Pflege |
   | Funktion | Fehler, Aufgabe, Pflege |
   | Fehler, Aufgabe, Pflege | keine |
   | Sammelvorgang | keine; er hat auch kein Elternteil |

3. Die Hierarchie ist zyklenfrei.
4. Eltern- und Kindvorgang gehören demselben Projekt an.

   ```text
   unzulässig  parent(pcs-php/#2e91) = Kashasaga/#3f70
   zulässig    Kashasaga/#7c40 depends_on pcs-php/#2e91
   ```
5. Ein *Epos* wird nicht selbst bearbeitet; sein Abschluss folgt aus den Kindern.

   „Nicht selbst bearbeitet“ schließt die Zustände *in Arbeit* und *in Prüfung*
   nicht aus. Diese Zustände beschreiben den Fortschritt und die Beurteilung des
   durch die Kinder gegliederten Gesamtumfangs. Das Epos folgt der gewöhnlichen
   Übergangstabelle; §9.3 zeigt ein Epos im Zustand *in Arbeit*.

   Ein *Epos* darf nur abgeschlossen werden, wenn es mindestens einen
   Kindvorgang besitzt und alle seine Kinder *abgeschlossen* oder *verworfen*
   sind. Ohne Kinder besteht nichts, aus dessen Abschluss sein eigener folgen
   könnte — ein Epos ohne Zerlegung ist ein Vorgang der falschen Art, kein
   abgeschlossenes Epos.
6. *Blockiert* ohne Blockadegrund ist unzulässig.
7. Eine gesetzte Sprintrolle ohne Sprintauswahl ist unzulässig.
8. Die Sprintauswahl darf wechseln; der Wechsel nimmt den Vorgang **nicht** aus
   dem Ist-Umfang des Sprints, in dem er bearbeitet wurde.
9. **Nachgezogen gegenüber dazwischengekommen.**

   ```text
   nachgezogen        08-11: Ziel gesichert, drei Tage übrig,
                      #9a03 aus den bereiten Vorgängen geholt
   dazwischengekommen 08-09: Kunde meldet Fehler, #c73e sofort bearbeitet
   In einem gemeinsamen Wert wäre beides „ungeplant: 2“.
   ```
10. **Klärung, Untersuchung oder Entscheidung.** Maßstab ist, was am Ende steht.

    ```text
    Urteil      „#88ce lohnt nicht“ nach 10 Minuten Lesen
                → Zustand in Klärung, danach verworfen mit Grund

    Artefakt    Feature-Matrix „Fallback-Verhalten der Anzeigeorte“
                → eigener Vorgang #a1f4, references → #88ce

    Wahl        „eine Kette für alle drei Anzeigeorte oder je eine?“
                → KEP-Lite #8c21; #9e2b wartet, implements → #8c21
    ```

    *Auswahlgrund für den dritten Fall:* Ohne ihn wird die Entscheidung während
    der Arbeit getroffen und nirgends festgehalten – der Schaden aus Ablauf B.
    Der Untersuchungsvorgang allein genügt nicht: Er liefert das Artefakt, nicht
    die Abwägung.
11. **Vorhaben-Schranke.** Der Wechsel nach *in Arbeit* verlangt, dass der
    Vorgang im Vorhaben eines aktiven Sprints liegt. Läuft für keines seiner
    Projekte ein aktiver Sprint, entfällt die Schranke ersatzlos.
12. **Abhängigkeitsschranke, übergehbar.** Der Wechsel nach *in Arbeit*
    verlangt, dass jeder über `depends_on` erreichte unmittelbare Vorgänger
    *abgeschlossen* oder *verworfen* ist. Die Schranke darf mit einem Grund
    übergangen werden; die Übergehung wird als Nebenfolge geführt.

    *Auswahlgrund gegen eine harte Schranke:* Eine Schranke ohne Ausweg wird
    umgangen – durch Löschen der Kante. Dann verliert man die Kante, nicht nur
    die Regel. *Gewinn:* „Wie oft wurde übergangen?“ ist eine Zahl.
13. **Sprintrolle im Regelfall.** Maßgeblich ist der Zeitpunkt der Aufnahme ins
    Vorhaben, nicht das Fehlen einer Angabe.
14. **Abhängigkeit setzt keinen Zustand.** `depends_on` sagt, was vorher fertig
    sein soll; *blockiert* mit Blockadegrund sagt, dass es gerade hakt.

    ```text
    innen   ein Vorgang in Pages PM      → eine Kante
    außen   ein fremdes Release, ein Termin → Blockadegrund als Fachtext
    ```
15. **Beleggrenze.** Der Blattvorgang ist die kleinste Einheit, für die Pages PM
    einen Nachweis führt. *Abgeschlossen* heißt: dieser Schritt ist belegt, mit
    Zeitpunkt und Verantwortung. Feineres wird nicht nachgewiesen, sondern
    geteilt.

    ```text
    zu grob   #9e2b  K1 erfüllt · K2 erfüllt · ein Abschluss
                     → welches K wann? nicht ablesbar

    geteilt   #3f70 Epos
                ├─ #9e2b Aufgabe „Vorschau folgt der Kette“  abgeschl. 08-11
                └─ #9e2e Aufgabe „Platzhalter zentral“       abgeschl. 08-12
    ```
16. **Größenbremse (Soll).** Wächst ein Vorgang über das hinaus, was in einem
    Zug beurteilt werden kann, wird zuerst gefragt **warum** – nicht sofort
    geteilt.

    ```text
    #9e2b ist zu groß. Warum?

      Mehrere Wege, keiner entschieden
         → KEP-Lite (Ablauf B). Der Vorgang wird kleiner, weil er
           nicht mehr entscheiden muss.
      Das Soll ist nirgends beschrieben
         → System-Spezifikation (§7.15); über Beteiligte hinweg
           Ablauf-Spezifikation (§7.16)
      Niemand weiß, wann es fertig geprüft ist
         → Testmatrix (§7.14). Die leere Zelle war der Umfang.
      Es wiederholt sich und wird unter Druck gebraucht
         → Runbook (§7.10)
      Nichts davon – es ist wirklich nur viel Arbeit
         → Geschwistervorgänge
    ```

    **Teilen ist der letzte Schritt, nicht der erste.** Acht Geschwister ohne
    Entscheidungsdokument heißen meist: Die Entscheidung wird während der Arbeit
    implizit getroffen, achtmal, von wechselnden Leuten.

    **Wenn geteilt wird: in die Breite, nicht in die Tiefe** – die drei Ebenen
    aus Regel 2 bleiben.

    ```text
    falsch   #7b0d-a, #7b0d-b unter #7b0d        → vierte Ebene
    richtig  #7b0d und #7b0e als Geschwister     → gleiche Ebene
             #7b0e depends_on #7b0d              → Reihenfolge, wo nötig
    ```

    *Auswahlgrund:* §0.2 sagt zu, dass Entscheidungen und geltende Dokumente
    neben der Arbeit im selben Graphen liegen. Ohne Auslöser bleibt das eine
    Möglichkeit – die Vorlagen existieren, und niemand greift danach. *Kosten:*
    Der Weg zum ersten Commit wird länger. *Restgrenze:* Ein Kriterium, das eine
    Eigenschaft ist („unter 200 ms“), teilt sich nicht; dort bleibt der Vorgang
    die Auflösung.
17. **Nebenbefund.** Ein Fund während der Arbeit an #9e2b, außerhalb seines
    Umfangs:

    ```text
    trivial              → Beitrag am Sammelvorgang (Ablauf A2)
                           git:… · #d5aa

    Verstoß gegen eine   → neuer Eintrag im Eingang
    geltende Richtlinie    implements → Richtlinie „Sprachvollständigkeit“
                           Beschreibung nennt die Regel: I18N-02

    sonst                → neuer Eintrag im Eingang
                           references → #9e2b   „hier gefunden“

    immer                #9e2b wird nicht unterbrochen und nicht erweitert.
    ```

    *Auswahlgrund:* Drei Wege, damit keiner der beiden Fehler entsteht – den Fund
    hineinziehen (dann stimmt das Abschlusskriterium nicht mehr) oder ihn gar
    nicht festhalten. *Kosten:* Der Eingang füllt sich; sichtbar über das
    Eingangsalter (§7.5, Regel 10).
18. **Beendigungszeitpunkt.**

    ```text
    Wechsel nach abgeschlossen oder verworfen
      → auf den Zeitpunkt des Übergangs setzen
    Verlassen von verworfen
      → entfernen
    außerhalb von abgeschlossen und verworfen
      → unzulässig
    ```

    Das Feld nennt die **gegenwärtig wirksame** Beendigung, nicht jede frühere.
    Eine frühere Beendigung bleibt im Zustandsverlauf nachvollziehbar (P-010);
    das Entfernen am Vorgang löscht sie nicht.

    ```text
    08-05  bereit     → verworfen        Beendigung = 08-05
    09-12  verworfen  → in Klärung       Beendigung = leer
    09-20  in Prüfung → abgeschlossen    Beendigung = 09-20

    Der 08-05 ist weiterhin im Verlauf zu lesen, aber nicht mehr
    der Beendigungszeitpunkt des Vorgangs.
    ```
19. **Wiederaufnahme aus *verworfen*.** Der Rückweg nach *in Klärung* gilt
    derselben Sache: Er ist zulässig, wenn dieselbe fachliche Arbeit wieder
    gebraucht wird. Ist die Arbeit neu oder wesentlich verändert, wird ein
    neuer Vorgang angelegt und, wo es hilft, mit `references` auf den
    verworfenen verwiesen.

    ```text
    #abcd „CSV-Ausgabe ergänzen“ verworfen: Bedarf entfallen
      neuer Kunde braucht genau diese Ausgabe
        → dieselbe Arbeit          → #abcd wieder aufnehmen
      CSV soll künftig auch XLSX können
        → wesentlich verändert     → neuer Vorgang, references → #abcd
    ```

    Diese Unterscheidung trifft der Handelnde; sie ist keine aus den Daten
    ableitbare Bedingung. Geprüft wird der zulässige Rückweg, nicht das Urteil
    über die Gleichheit der Sache.

20. **Kein offener Kindvorgang unter einem beendeten Elternvorgang.** Regel 1
    stellt diese Lage beim Abschluss her; die Wiederaufnahme darf sie nicht
    wieder zerstören.

    ```text
    Elternvorgang abgeschlossen
      → das Kind bleibt beendet. Der Elternzustand hat keinen Rückweg,
        die Lage wäre nicht mehr auflösbar.
    Elternvorgang verworfen
      → das Kind wird nicht allein wieder aufgenommen. Spätestens zugleich
        mit ihm kehrt der Elternvorgang nach in Klärung zurück.
    Elternvorgang offen
      → gewöhnliche Wiederaufnahme des Kindes.
    ```

    Eltern- und Kindvorgang dürfen gemeinsam oder nacheinander wiederkehren.
    Nach **jeder einzelnen abgeschlossenen Änderung** muss aber gelten: Ein
    beendeter Elternvorgang hat kein offenes Kind. Bei getrennter
    Wiederaufnahme wechselt deshalb zuerst der Elternvorgang nach *in Klärung*
    und erst danach das Kind.

    ```text
    Ausgang      Epos E  verworfen
                 └─ T    verworfen

    zulässig     E → in Klärung        E  in Klärung
                                       └─ T verworfen
                 danach T → in Klärung E  in Klärung
                                       └─ T in Klärung

    unzulässig   T → in Klärung        E  verworfen
                                       └─ T in Klärung
    ```
21. **Die Pflichtschwelle bleibt nach der Wiederaufnahme erreicht** (§7.1.1,
    Regel 6): Ein Vorgang, der *bereit* war, kehrt mit seinen Pflichtangaben
    zurück; ein
    unmittelbar aus dem *Eingang* verworfener hat die Schwelle nie erreicht und
    kehrt ohne sie zurück.

#### Verantwortung

Bearbeitung: Pflicht ab *in Arbeit*. Prüfung: Pflicht ab *in Prüfung*, geführt
am Verlaufseintrag (P-004).

#### Beispiel

```text
#9e2b
  Projekt          Pages PM          Bereiche  {i18n, publishing}
  Titel            de: „Fallback-Kette im Renderer umsetzen“
                   en: „Implement fallback chain in the renderer“
  Vorgangsart      Funktion          Zustand   in Arbeit (seit 08-04)
  Dringlichkeit    hoch              Sprintauswahl  #6f30, Rolle: Ziel
  Abschlusskriterien
    K1  de: „Fehlt eine Übersetzung, erscheint der Text der nächsten
             Sprache der Kette, nie der Schlüssel.“      offen
    K2  de: „Fehlen alle Sprachen, erscheint der Platzhalter.“  offen
  Bearbeitung      Dani
  Beziehungen      implements → KEP-Lite #8c21
```

**Gegenbeispiel:** Ein Vorgang ist kein Entscheidungsdokument und kein
Kriterium: „erledigt“ ist eine Aussage über Arbeit, „erfüllt“ über ein Kriterium.

#### 7.6.1 Sammelvorgang und Nebenbei-Beiträge

**Ohne diese Regel** *(offen – Archiv-PM, §12.3)*

```text
Jede Nebenbei-Änderung wird ein eigener Vorgang:
  Abstand in der Seitenleiste korrigieren   → Arbeit: 2 Minuten
  Vorgang, Art, Dringlichkeit, Kriterium    → Verwaltung: 8 Minuten

Nach zwei Wochen legt niemand mehr einen an.
Ergebnis ist Nichterfassung – und ein Sprint, der zu wenig misst.
```

**Aufgabe:** Laufende Kleinarbeit soll mit **einer einzigen**
Verwaltungshandlung erfassbar sein und trotzdem im Sprint sichtbar bleiben.

**Kontextquelle:** Git-Trailer-Praxis; GitHub-Praxis mit schließenden
Schlüsselwörtern; Kanban-Praxis mit eigenen Arbeitsklassen.
*Was sie sagt:* Der Bezug zur Steuerung wird dort hergestellt, wo die Arbeit
ohnehin entsteht.

**Optionen**

```text
(a)  jeder Nebenbei-Fall wird ein Vorgang     bricht wie oben
(b)  ein dauerhaft offenes Epos als Behälter
     bricht am Epos: es schließt über seine Kinder ab und behauptet
     mit der Zerlegung Vollständigkeit
(c)  ein Sammelvorgang je Arbeitsklasse, an den Beiträge andocken
```

**Festlegung:** (c).

**Kosten:** Ein Sammelvorgang ist ein Vorgang **ohne Abschlussbedingung** – was
Z2 sonst untersagt. Zweiter Preis: Die Auflösung sinkt.

**Regeln**

1. Ein Sammelvorgang hat keine Abschlusskriterien und kein Enddatum. Er wechselt
   nach *abgeschlossen*, wenn die Arbeitsklasse selbst entfällt.
2. Er trägt mindestens einen Bereich und benennt in seiner Beschreibung, **was
   hineingehört und was nicht**.
3. Ein **Beitrag** besteht aus externer Kennung, Zeitpunkt und einer
   Kurzbeschreibung als Fremdtext. Er ist keine Herkunft.
4. Beiträge werden nicht kopiert.
5. **Zeitraumzuordnung.** Für die Sprintauswertung zählt der Beitrag.
6. **Unzugeordnete Beiträge sind zählbar zu halten.**
7. **Mindesthandlung.** Verlangt ist genau eine Angabe: die **Kurzkennung** eines
   Sammelvorgangs **oder** der Schlüssel einer geltenden Richtlinienregel. Die
   Vorhaben-Schranke gilt für Beiträge **nicht**.
8. **Wächter (Soll).** Übersteigt der Anteil eines Sammelvorgangs im
   Sprintzeitraum **30 %** der Zielarbeit, ist das ein Befund für die
   Retrospektive. *(Erwartung, §12.2: Der Wert ist gesetzt, damit die Regel
   überhaupt greift; ein Drittel des Zeitraums ist die Schwelle, ab der
   Zielarbeit sichtbar verdrängt wird. Zu überprüfen nach drei Sprints.)*
9. **Beitrag an einer Regel.** Nennt ein Beitrag einen Regelschlüssel wie
   `I18N-02`, ist er Konformitätsarbeit: Die Regel ist das Kriterium. Ein Beitrag
   nennt genau eines von beidem, nie beides.
10. **Größenbremse (Soll).** Wächst eine nebenbei begonnene Änderung über ihren
    Anlass hinaus, wird sie **abgebrochen und als Eintrag im Eingang abgelegt**.
    *Kontextquelle:* Fowlers Opportunistic Refactoring.

**Was nicht nebenbei geht**

| Bedingung | Warum |
|---|---|
| Jemand muss ein bestimmtes Ergebnis prüfen. | Das Kriterium braucht einen Träger (P-009). |
| Der Fehler hatte Betriebswirkung. | Ablauf E. |
| Alternativen sind abzuwägen. | Ablauf B. |
| Eine Richtlinie, ADR oder Spezifikation wird geändert. | Eigene Entscheidungs- und Ablösewege. |

**Wie die Nummer an den Beitrag kommt, ist nicht Gegenstand dieser
Spezifikation.** Hält ein Projekt die Vereinbarung fest, wird sie damit
**Inhalt**: ein Runbook oder eine Richtlinie.

**Beispiel**

```text
#d5aa   Sammelvorgang „Laufende UI-Behebungen“
  Bereiche       {ui}
  Beschreibung   de: „Kleine Behebungen an der Oberfläche: Abstände,
                      Beschriftungen, tote Verweise. Nicht hierher:
                      Verhalten, das jemand prüfen muss.“
  Zustand        in Arbeit          Dringlichkeit  niedrig
  Beiträge
    [1] git:9f2c1ab      · 2026-08-05 · en: „fix: sidebar spacing“
    [2] github-pr:214    · 2026-08-07 · en: „fix: dead link in footer“
```

**Gegenbeispiel:** Ein Sammelvorgang, der ein bestimmtes Ergebnis zusagt, ist
keiner mehr.

---

### 7.7 KEP-Lite

**Zweck:** Eine Änderung mit Alternativen vor ihrer Umsetzung kontrolliert
entscheiden.

**Kontextquelle:** Kubernetes Enhancement Proposals; Python PEP („Rejected
Ideas“ ist Pflichtteil); Rust RFC.
*Was sie sagt:* Vor der Umsetzung stehen Problem, Vorschlag, verworfene
Alternativen und Abnahmekriterien fest. Die Annahme ist nicht der Abschluss.

**Auswahlgrund für verworfene Alternativen als Pflichtangabe:** Sie sind der
einzige Teil, den Ablauf A nicht schon leistet – ohne sie ist ein KEP-Lite nur
ein umständlicher Vorgang. **Kosten:** Wer nur eine Möglichkeit sieht, muss den
Fall ehrlich als Ablauf A führen.

#### Pflichtangaben

| Angabe | Art | Pflicht ab | Regel |
|---|---|---|---|
| Problem | Fachtext | Anlage | beschreibt den Anlass ohne Lösung |
| Zustand | Kurzwert | Anlage | kein Vorgabewert |
| Vorschlag | Fachtext | in Prüfung | die gewählte Ausprägung |
| Verworfene Alternativen | Punktfolge | in Prüfung | mindestens ein Eintrag mit Grund |
| Annahmekriterien | Punktfolge | in Prüfung | mindestens eines, einzeln prüfbar |

**Schema des dynamischen Feldes:**

```text
{ alternativen: [ { text: Fachtext, grund: Fachtext } ],
  kriterien:    [ { schluessel: Kurzwert, text: Fachtext,
                    stand: offen | erfüllt } ] }
```

#### Optionale Angaben

| Angabe | Art | Pflicht ab |
|---|---|---|
| Ziel, Einführungsplan | Fachtext | – (optional) |
| Betroffene Bereiche | Merkmalsmenge | – (optional) |
| Entscheidung | Ergebnis (Kurzwert), Begründung, Zeitpunkt, Person | angenommen, abgelehnt, zurückgezogen |
| Abgelöst durch | Verweis auf KEP-Lite | nur nach Ablösung |

#### Zustände und Übergänge

| Zustand | Bedeutung |
|---|---|
| *Entwurf* | wird geschrieben |
| *in Prüfung* | liegt zur Entscheidung vor |
| *angenommen* | entschieden, Umsetzung offen |
| *abgelehnt* | entschieden, keine Umsetzung |
| *zurückgezogen* | vor der Entscheidung beendet |
| *umgesetzt* | umgesetzt und nachgewiesen |

```text
Entwurf     → in Prüfung | zurückgezogen
in Prüfung  → angenommen | abgelehnt | Entwurf | zurückgezogen
angenommen  → umgesetzt | zurückgezogen
```

#### Fachliche Prüfregeln

1. Der Wechsel nach *angenommen* verlangt mindestens eine verworfene
   Alternative, mindestens ein Annahmekriterium und eine Entscheidung mit
   Begründung, Zeitpunkt und Person.
2. Der Wechsel nach *umgesetzt* verlangt: mindestens ein Vorgang mit
   `implements` ist *abgeschlossen*, **und** jedes Annahmekriterium trägt
   *erfüllt* (P-009). Der abgeschlossene Vorgang sagt, dass gearbeitet wurde;
   der Stand, dass das Zugesagte eingetreten ist.
3. Ein angenommenes KEP-Lite wird inhaltlich nicht mehr geändert; eine spätere
   Änderung ist ein neues KEP-Lite, das alte trägt *Abgelöst durch*.
4. *zurückgezogen* nach der Annahme verlangt eine Begründung und lässt bereits
   abgeschlossene Vorgänge unberührt.
5. Eine erfundene Gegenoption erfüllt Regel 1 nicht (Anhang A.1).

**Verantwortung:** Entscheidung ist Pflicht ab *angenommen*, *abgelehnt* und
*zurückgezogen*.

#### Beispiel

```text
KEP-Lite #8c21
  Projekt       Pages PM       Bereiche  {i18n}
  Titel         de: „Einheitlicher Sprach-Fallback“
  Problem       de: „Vorschau, Ausgabe und Oberfläche behandeln fehlende
                     Übersetzungen unterschiedlich.“
  Vorschlag     de: „Eine einzige Fallback-Kette de → en → Platzhalter.“
  Verworfene Alternativen
    [1] de: „Pro Anzeigeort eigene Kette.“
        Grund: de: „Die Uneinheitlichkeit war genau das Problem.“
    [2] de: „Fehlende Übersetzung als Fehler behandeln.“
        Grund: de: „Blockiert die Vorschau während der Übersetzungsarbeit.“
  Annahmekriterien
    K1  de: „Kein Anzeigeort zeigt einen Schlüssel.“        offen
    K2  de: „Der Platzhalter ist an einer Stelle konfiguriert.“  offen
  Zustand       angenommen (2026-08-03)
  Entscheidung  Begründung: de: „Einheitlichkeit wiegt schwerer als
                Feinsteuerung je Anzeigeort.“; Entscheidung: Dani
```

**Gegenbeispiel:** Ein KEP-Lite ist keine Aufgabenliste. Ein KEP-Lite ohne
verworfene Alternative gehört nach Ablauf A.

### 7.8 ADR

**Zweck:** Eine dauerhaft wichtige technische Entscheidung so festhalten, dass
sie später verstanden und geordnet abgelöst werden kann.

**Kontextquelle:** Nygard, „Documenting Architecture Decisions“; MADR.
*Was sie sagt:* Ein ADR ist ein kurzes Dokument je Entscheidung. Abgelöst wird
durch ein neues Dokument, nicht durch Überschreiben.

**Abgrenzung zum KEP-Lite:** Das KEP-Lite führt zur Entscheidung, das ADR hält
sie dauerhaft fest. **Auswahlgrund für zwei Arten:** Ein KEP-Lite enthält
Verfahrensteile, die nach der Umsetzung niemand mehr liest; ein ADR wird über
Jahre gelesen. **Kosten:** Doppelerfassung von Kontext und Entscheidung –
deshalb erzeugt nicht jedes KEP-Lite ein ADR.

| Angabe | Art | Pflicht ab | Regel |
|---|---|---|---|
| Zustand | Kurzwert: *Entwurf*, *angenommen*, *abgelehnt*, *abgelöst* | Anlage | kein Vorgabewert |
| Kontext | Fachtext | angenommen | |
| Entscheidung | Fachtext | angenommen | |
| Konsequenzen | Fachtext | angenommen | auch die nachteiligen |
| Alternativen | Punktfolge | – (optional) | |
| Abgelöst durch | Verweis auf ADR | abgelöst | |
| Entscheidungszeitpunkt | Zeitpunkt | angenommen | |

```text
Entwurf → angenommen | abgelehnt        angenommen → abgelöst
```

**Prüfregeln:** Ein angenommenes ADR wird nicht geändert, sondern abgelöst.
*abgelöst* verlangt genau einen Nachfolger; Ablöseketten sind zyklenfrei. Das
abgelöste ADR bleibt lesbar und trägt den Ablösegrund. Ein ADR aus einem
KEP-Lite trägt `derived_from` (P-007).

**Verantwortung:** Entscheidung ist Pflicht ab *angenommen*.

#### Beispiel

```text
ADR #17ad
  Titel         de: „Fallback-Kette de → en → Platzhalter“
  Kontext       de: „Fachtexte sind Sprachkarten mit Pflichtsprachen {de,en}.“
  Entscheidung  de: „Anzeigen folgen der Kette; der Platzhalter wird
                     zentral konfiguriert.“
  Konsequenzen  de: „Fehlende Übersetzungen fallen beim Lesen nicht mehr auf;
                     die Vollständigkeitsprüfung muss getrennt laufen.“
  Zustand       angenommen (2026-08-05)
  Beziehungen   derived_from → KEP-Lite #8c21
```

**Gegenbeispiel:** Eine fortlaufend geltende Regel („alle Fachtexte tragen de
und en“) ist keine ADR, sondern eine Richtlinie: Die ADR beschreibt einen
Zeitpunkt, die Richtlinie einen Dauerzustand.

### 7.9 Richtlinie

**Zweck:** Wiederholt geltende Regeln auffindbar und einzeln referenzierbar
halten.

**Kontextquelle:** Praxis versionierter Richtliniendokumente; BCP 14.
*Was sie sagt:* Verbindlichkeit wird durch festgelegte Schlüsselwörter
ausgedrückt, nicht durch Tonfall. Regeln, auf die verwiesen wird, brauchen einen
stabilen Bezeichner.

**Auswahlgrund für einzelne Regeln statt eines Textblocks:**

```text
Textblock:
  „Vorgänge gelten als abgeschlossen, wenn alle Kriterien geprüft sind
   und die Prüfung nach Möglichkeit von einer anderen Person erfolgte.“
Verweis darauf im Beitrag: das halbe Zitat. Welche Fassung galt am 3. August?

Einzelregeln:
  DONE-01  Muss   …        DONE-02  Soll   …
Verweis: „verstößt gegen DONE-02“. Auflösbar, abstufbar, prüfbar.
```

**Kosten:** Die Erfassung ist umständlicher, und die Regelschlüssel müssen
vergeben und gepflegt werden.

| Angabe | Art | Pflicht ab | Regel |
|---|---|---|---|
| Zustand | Kurzwert: *Entwurf*, *gültig*, *überholt*, *abgelöst* | Anlage | kein Vorgabewert |
| Zweck | Fachtext | gültig | |
| Geltungsbereich | Fachtext | gültig | wofür sie gilt und wofür nicht |
| Regeln | Punktfolge | gültig | mindestens eine |
| Gültig ab | Datum | gültig | |
| Nicht-Ziele, Beispiele, Änderungsnotiz | Fachtext | – (optional) | |
| Abgelöst durch | Verweis auf Richtlinie | abgelöst | |

**Schema des dynamischen Feldes:**

```text
Regeln = [ { schluessel:    Kurzwert,
             verbindlichkeit: Muss | Muss nicht | Soll | Soll nicht | Kann,
             text:          Fachtext,
             begruendung:   Fachtext (optional) } ]
```

```text
Entwurf → gültig        gültig → überholt | abgelöst
```

**Prüfregeln**

1. Ein Regelschlüssel ist **installationsweit** eindeutig und unveränderlich; er
   wird nach dem Wegfall einer Regel nicht neu vergeben. *Auswahlgrund:* Ein
   Schlüssel, der in einem Commit außerhalb von Pages PM steht (§7.6.1, Regel
   9), muss ohne Angabe seiner Richtlinie auflösen.
2. Der Wechsel nach *gültig* verlangt Gültig-ab und mindestens eine Regel.
3. Eine Änderung an einer geltenden Regel wird als Änderungsnotiz begründet
   (P-010); eine Änderung des Geltungsbereichs verlangt eine Ablösung.
4. *überholt* heißt: gilt nicht mehr, ohne Nachfolger. *abgelöst* verlangt einen
   Nachfolger.

**Verantwortung:** Entscheidung beim Wechsel nach *gültig*; Pflege im Zustand
*gültig*.

#### Beispiel

```text
Richtlinie „Abschluss von Vorgängen“
  Zweck     de: „Einheitlich festlegen, wann ein Vorgang abgeschlossen ist.“
  Geltungsbereich  de: „Alle Vorgänge in Pages PM.“
  Regeln
    DONE-01  Muss   de: „Jedes Abschlusskriterium trägt den Stand erfüllt.“
    DONE-02  Soll   de: „Prüfung und Bearbeitung werden von verschiedenen
                         Personen wahrgenommen.“
                    Begründung: de: „Bei einer Person im Team ist die
                         Abweichung der Regelfall und wird vermerkt.“
  Zustand   gültig, gültig ab 2026-08-01        Pflege  Dani
```

**Gegenbeispiel:** Ein einmaliger Beschluss ist keine Richtlinie, sondern eine
Entscheidung. Eine ausführbare Schrittfolge ist ein Runbook.

### 7.10 Runbook

**Zweck:** Wiederholbare Betriebs- oder Wiederherstellungsschritte so
festhalten, dass sie unter Druck ausführbar sind.

**Kontextquelle:** Google SRE zu Playbooks; AWS Systems Manager Automation.
*Was sie sagt:* Vorbereitete Abläufe verkürzen die Wiederherstellungszeit
messbar. Schritte laufen in fester Reihenfolge.

**Auswahlgrund für die Pflichtangabe „letzte Prüfung“:** Eine Anleitung kann bei
unverändertem Text technisch veralten. **Kosten:** Ein Runbook muss regelmäßig
durchgespielt werden – wiederkehrende Arbeit ohne sichtbares Ergebnis.

| Angabe | Art | Pflicht ab | Regel |
|---|---|---|---|
| Zustand | Kurzwert: *Entwurf*, *gültig*, *überholt* | Anlage | kein Vorgabewert |
| Zweck, Auslöser | Fachtext | gültig | wann dieses Runbook gilt |
| Schritte | Punktfolge | gültig | mindestens einer |
| Abbruchbedingungen | Punktfolge | gültig | mindestens eine |
| Letzte Prüfung | Zeitpunkt | gültig | |
| Voraussetzungen, Fehlerfälle | Punktfolge | – (optional) | |

**Schema:** `Schritte = [ { anweisung: Fachtext, erwartet: Fachtext,
pruefung: Fachtext (optional) } ]`

```text
Entwurf → gültig        gültig → überholt | Entwurf
```

**Prüfregeln**

1. *gültig* verlangt eine letzte Prüfung. Wird die Frist überschritten, ist der
   Zustand fachlich nicht mehr *gültig*.

   **Prüffrist (Erwartung, §12.2): 180 Tage.** *Begründung:* Der wichtigere Fall
   – die Grundlage hat sich fachlich geändert – fällt ohne Frist sofort auf,
   sobald die Änderungsart aus P-010 vorliegt. Eine kurze Frist ohne diese
   Rechnung wird nur umgangen. Der Wert ist deshalb bewusst lang und wird nach
   dem ersten Ablauf überprüft.
2. Ein Schritt ohne erwartetes Ergebnis ist zulässig; ein Runbook, in dem kein
   einziger Schritt eines nennt, nicht.
3. Die Durchführung wird nicht im Runbook vermerkt, sondern als Vorgang.

**Verantwortung:** Pflege ist Pflicht im Zustand *gültig*.

#### Beispiel

```text
Runbook „Vorschauumgebung neu aufbauen“
  Zweck      de: „Die Vorschau nach fehlgeschlagener Ausgabe wiederherstellen.“
  Auslöser   de: „Die Vorschau zeigt eine ältere Fassung als die Ausgabe.“
  Schritte
    [1] Anweisung: de: „Laufende Ausgabe abbrechen.“
        Erwartet:  de: „Keine Ausgabe läuft.“
    [2] Anweisung: de: „Zwischenstand leeren und Ausgabe neu starten.“
        Erwartet:  de: „Die Vorschau zeigt den aktuellen Stand.“
  Abbruchbedingungen
    [1] de: „Zweiter Fehlversuch: abbrechen, Störung als Vorgang erfassen.“
  Zustand    gültig, letzte Prüfung 2026-07-19        Pflege  Dani
```

**Gegenbeispiel:** „Die Vorschau muss dem Stand entsprechen“ ist eine
Richtlinie; „so stellt man das her“ ist das Runbook.

### 7.11 Postmortem

**Zweck:** Aus einer folgenreichen Störung lernen und die Folgearbeit benennen.

**Kontextquelle:** Google SRE, Postmortem-Kultur und Incident Response.
*Was sie sagt:* Die Auswertung erfolgt nach der Wiederherstellung, sachlich und
ohne Schuldzuweisung.

**Auswahlgrund für „Ursachenbild“ statt einer einzelnen Ursache:**

```text
Ein Ursachenfeld:
  Ursache: „Fallback-Kette war nicht konfiguriert.“
Verloren: dass der Vollständigkeitstest nur in der Vorschau lief.
Genau dieser zweite Umstand ist die Maßnahme wert.
```

**Kosten:** Die Auswertung lässt sich nicht zu einer Zeile zusammenfassen.

| Angabe | Art | Pflicht ab | Regel |
|---|---|---|---|
| Zustand | Kurzwert: *Entwurf*, *in Prüfung*, *abgeschlossen* | Anlage | kein Vorgabewert |
| Schweregrad | Kurzwert: *niedrig*, *mittel*, *hoch*, *kritisch* | Anlage | |
| Störungsbeginn | Zeitpunkt | Anlage | |
| Zusammenfassung, Auswirkung, Behebung | Fachtext | in Prüfung | Auswirkung: was Betroffene gemerkt haben |
| Ursachenbild | Punktfolge | in Prüfung | mindestens einer; Umstände, keine Personen |
| Störungsende | Zeitpunkt | in Prüfung | nicht vor dem Beginn |
| Lehren | Fachtext | abgeschlossen | |
| Maßnahmen | Punktfolge aus Maßnahme und Vorgang | abgeschlossen | siehe Prüfregeln |
| Zeitleiste, Auslöser, Erkennung | Punktfolge / Fachtext | – (optional) | |

```text
Entwurf → in Prüfung → abgeschlossen        in Prüfung → Entwurf
```

**Prüfregeln:** *abgeschlossen* verlangt mindestens eine Maßnahme mit
verknüpftem Vorgang oder einen ausdrücklichen Vermerk „keine Maßnahme“ mit
Begründung. Ein Ursachenbild benennt Umstände, keine Personen. Die
Wiederherstellung wird als Vorgang geführt, nicht hier.

#### Beispiel

```text
Postmortem „Ausgabe zeigte 40 Minuten Rohschlüssel“
  Schweregrad    hoch
  Zusammenfassung de: „Nach einem Umbau zeigte die Ausgabe Schlüssel statt Text.“
  Auswirkung     de: „40 Minuten unlesbare öffentliche Seiten.“
  Ursachenbild
    [1] de: „Die Fallback-Kette war in der Ausgabe nicht konfiguriert.“
    [2] de: „Der Vollständigkeitstest lief nur in der Vorschau.“
  Lehren         de: „Ein Test, der nur in einer Umgebung läuft, prüft nichts.“
  Störung        2026-07-18 09:10 – 09:50
  Maßnahmen      [1] de: „Test in beiden Umgebungen ausführen.“ → #7b0d
  Zustand        abgeschlossen
```

**Gegenbeispiel:** Ein Fehler ohne Betriebswirkung verlangt kein Postmortem.

### 7.12 Drift-Bericht

**Zweck:** Mehrere zusammengehörende Soll-Ist-Abweichungen gemeinsam bewerten.

**Kontextquelle:** Drift-Erkennung in Infrastructure-as-Code-Werkzeugen.
*Was sie sagt:* Die Sammelansicht aller Abweichungen ist die eigentliche
Leistung; die einzelne Abweichung ist für sich wenig aussagekräftig.

**Auswahlgrund für die Untergrenze von zwei Befunden:** Ein einzelner Befund ist
ein Vorgang der Art *Fehler*; erst die gemeinsame Bewertung rechtfertigt nach
P-012 eine eigene Fachart. **Kosten:** Wer beim ersten Befund schon ahnt, dass
mehr folgen, muss trotzdem mit einem Vorgang beginnen.

| Angabe | Art | Pflicht ab | Regel |
|---|---|---|---|
| Zustand | Kurzwert: *Entwurf*, *bestätigt*, *behoben*, *hingenommen* | Anlage | kein Vorgabewert |
| Gegenstand | Fachtext | Anlage | was verglichen wurde |
| Soll-Zustand, Ist-Zustand | Fachtext | bestätigt | |
| Befunde | Punktfolge | bestätigt | mindestens zwei |
| Bewertungszeitpunkt, Bewertung | Zeitpunkt / Fachtext | bestätigt | bei *hingenommen* mit Begründung |
| Empfehlungen | Punktfolge aus Empfehlung und Vorgang | – (optional) | |

```text
Entwurf → bestätigt        bestätigt → behoben | hingenommen
```

**Prüfregeln:** *behoben* verlangt, dass jeder Befund durch einen
abgeschlossenen Vorgang aufgelöst oder ausdrücklich als *hingenommen* markiert
ist. Ein Drift-Bericht ersetzt keinen Vorgang.

#### Beispiel

```text
Drift-Bericht „Sprachvollständigkeit Fachtexte“
  Gegenstand   de: „Alle veröffentlichten Fachtexte im Bereich publishing.“
  Soll         de: „Jeder Fachtext liegt in de und en vor.“
  Ist          de: „14 von 61 Texten haben keinen en-Eintrag.“
  Befunde
    [1] hoch    de: „Alle sechs Runbook-Schritte ohne en-Text.“
    [2] mittel  de: „Acht Vorgangstitel ohne en-Text.“
  Zustand      bestätigt   ·   Bewertungszeitpunkt 2026-07-20
```

**Gegenbeispiel:** Ein Bericht mit genau einem Befund ist ein Vorgang der Art
*Fehler*.

### 7.13 Feature-Matrix

**Zweck:** Mehrere Gegenstände anhand derselben Merkmale vergleichen.

**Kontextquelle:** Vergleichstabellen in Produktentscheidungen.
*Was sie sagt:* Der Vergleich trägt nur, wenn alle Gegenstände an denselben
Merkmalen gemessen werden; die leere Zelle ist selbst eine Aussage.

| Angabe | Art | Pflicht ab | Regel |
|---|---|---|---|
| Zustand | Kurzwert: *Entwurf*, *in Arbeit*, *abgeschlossen*, *abgelöst* | Anlage | kein Vorgabewert |
| Zweck | Fachtext | Anlage | welche Frage der Vergleich beantworten soll |
| Matrix | Punktfolge (dynamisches Feld) | in Arbeit | mindestens zwei Spalten und zwei Zeilen |
| Auswertung | Fachtext | abgeschlossen | |

**Schema:** `{ spalten: [{schluessel, titel, wertart}],
zeilen: [{schluessel, titel, gegenstand?}], zellen: [{zeile, spalte, wert,
notiz?}] }`

**Prüfregeln:** Eine Zelle verbindet nur Zeile und Spalte derselben Matrix. Eine
fehlende Zelle bedeutet „nicht bewertet“ – ein Befund, kein Fehler.

#### Beispiel

```text
Feature-Matrix „Fallback-Verhalten der Anzeigeorte“
  Spalten  schluessel „Zeigt Schlüssel“ Ja/Nein · kette „Folgt der Kette“
  Zeilen   vorschau · ausgabe · ui
  Zellen   vorschau/schluessel = nein   vorschau/kette = ja
           ausgabe/schluessel  = ja     ausgabe/kette  = nein
           ui/schluessel       = nein   ui/kette       = (nicht bewertet)
  Zustand  in Arbeit
```

**Gegenbeispiel:** Sind die Zeilen die abgewogenen Möglichkeiten einer einzelnen
Entscheidung, gehören sie als verworfene Alternativen in das KEP-Lite.

### 7.14 Testmatrix

**Zweck:** Kombinationen vollständig sichtbar machen und ihre Ergebnisse je Lauf
festhalten.

**Kontextquelle:** Kombinatorische Testpraxis (NIST-Material).
*Was sie sagt:* Die meisten Fehler entstehen aus dem Zusammentreffen weniger
Merkmale.

**Auswahlgrund für die Trennung von Testfall und Testlauf:**

```text
Zusammengelegt:  FB-03  bestanden
Der Lauf von gestern hat den von vorgestern überschrieben.
„Seit wann fällt das durch?“ ist nicht mehr beantwortbar.
```

**Kosten:** Für ein einzelnes Ergebnis sind zwei Einträge zu führen.

| Angabe | Art | Pflicht ab | Regel |
|---|---|---|---|
| Zustand | Kurzwert: *Entwurf*, *in Arbeit*, *abgeschlossen*, *abgelöst* | Anlage | kein Vorgabewert |
| Ziel | Fachtext | Anlage | |
| Geltungsbereich | Fachtext | in Arbeit | welche Merkmale kombiniert werden |
| Matrix | Punktfolge (dynamisches Feld) | in Arbeit | mindestens ein Testfall |

**Schema:** `{ faelle: [{schluessel, titel, handlungen, erwartet,
voraussetzungen?}], laeufe: [{schluessel, beginn, umgebung, ende?}],
ergebnisse: [{lauf, fall, ergebnis, zeitpunkt, beleg?, notiz?}] }`

**Prüfregeln:** Ein Ergebnis gehört zu einem Fall derselben Matrix und kommt je
Lauf und Fall nur einmal vor. Nicht ausgeführte Kombinationen bleiben sichtbar;
sie werden nicht als bestanden gewertet.

#### Beispiel

```text
Testmatrix „Sprach-Fallback“
  Ziel             de: „Belegen, dass kein Anzeigeort Schlüssel zeigt.“
  Geltungsbereich  de: „{de, en, fehlend} × {Vorschau, Ausgabe}“
  Fälle
    FB-01  de: „en fehlt in der Vorschau“  → erwartet: deutscher Text
    FB-02  de: „en fehlt in der Ausgabe“   → erwartet: deutscher Text
    FB-03  de: „beide fehlen, Ausgabe“     → erwartet: Platzhalter
  Lauf 2026-08-11, Umgebung „Vorschau“
    FB-01 bestanden · FB-02 nicht anwendbar · FB-03 nicht ausgeführt
  Zustand  in Arbeit
```

**Gegenbeispiel:** Eine Liste durchgeführter Prüfungen ohne benannte
Kombinationen ist keine Testmatrix.

### 7.15 System-Spezifikation

**Zweck:** Das gemeinsame fachliche Soll eines Systems festhalten: was es ist,
wie es aufgebaut ist, welche Schnittstellen es hat.

**Kontextquelle:** arc42, Bausteinsicht und Querschnittliche Konzepte.
*Was sie sagt:* Regeln, die für mehrere Bausteine gelten, gehören an eine Stelle.

| Angabe | Art | Pflicht ab | Regel |
|---|---|---|---|
| Zustand | Kurzwert: *Entwurf*, *gültig*, *überholt*, *abgelöst* | Anlage | kein Vorgabewert |
| Definition | Fachtext | gültig | was das System ist und wofür es zuständig ist |
| Nicht-Ziele | Fachtext | gültig | wofür es ausdrücklich nicht zuständig ist |
| Aufbau | Fachtext | gültig | Bestandteile und Abhängigkeiten |
| Zusammenfassung, Begründung, Rollen, Schnittstellen | Fachtext | – (optional) | |
| Abgelöst durch | Verweis | abgelöst | |

**Auswahlgrund für Nicht-Ziele als Pflichtangabe:**

```text
Ohne Nicht-Ziele:
  „Der Renderer erzeugt Markdown.“
  Nächste Frage: „Kann er auch Sprachauswahl?“ – warum nicht.
  Ein Jahr später enthält der Renderer die Fallback-Logik,
  die nach ADR #17ad zentral konfiguriert sein sollte.
```

**Kosten:** Nicht-Ziele altern schneller als der Rest.

**Prüfregeln:** Eine gültige System-Spezifikation trägt eine
Pflegeverantwortung. Eine bereits als Richtlinienregel geführte Regel wird hier
nicht wiederholt, sondern verwiesen.

**Gegenbeispiel:** Wie das System sich zur Laufzeit über Beteiligte hinweg
verhält, gehört in eine Ablauf-Spezifikation.

### 7.16 Ablauf-Spezifikation

**Zweck:** Festlegen, wie ein wichtiger Ablauf über Beteiligte und Systemgrenzen
hinweg funktioniert – im Normalfall, im Fehlerfall und in Ausnahmen.

**Kontextquelle:** arc42, Laufzeitsicht.

| Angabe | Art | Pflicht ab | Regel |
|---|---|---|---|
| Zustand | Kurzwert: *Entwurf*, *gültig*, *überholt*, *abgelöst* | Anlage | kein Vorgabewert |
| Zweck | Fachtext | Anlage | |
| Auslöser | Fachtext | gültig | wodurch der Ablauf beginnt |
| Beteiligte | Punktfolge | gültig | mindestens einer |
| Schritte | Punktfolge | gültig | mindestens einer nennt ein Fehlerverhalten |
| Ein- und Ausgaben, Zusammenfassung | Fachtext | – (optional) | |

**Schema:** `{ beteiligte: [{ system? | extern?, rolle }],
schritte: [{ handelnder, handlung, erwartet, fehlerverhalten? }] }`

**Auswahlgrund für die strukturierte Schrittfolge:** Nur einzeln geführte
Schritte lassen sich in einer Testmatrix benennen; ein zusammenhängender Text
kann nur zitiert werden. **Kosten:** kleine Abläufe wirken überformalisiert.

**Prüfregeln:** Ein Beteiligter ist entweder intern (Verweis auf eine
System-Spezifikation) oder extern (Fachtext), nie beides. Mindestens ein Schritt
nennt ein Fehlerverhalten.

**Gegenbeispiel:** Eine Anleitung zum Ausführen durch eine Person ist ein
Runbook. Die Ablauf-Spezifikation beschreibt, wie es funktioniert, nicht, wie man
es macht.

---

## 8. Beziehungen

### 8.1 Beziehungsarten

Nach **P-014** verbinden Kanten nur Gegenstände – nie Nebenfolgen, nie
Feldinhalte. Und nach dem Kriterium **Angabe oder Beziehung** gilt:

```text
Von der Quelle aus genau eines   →  Angabe in der Vorlage
Von der Quelle aus mehrere       →  Beziehung im Graphen
```

Danach sind frühere Beziehungsarten Angaben geworden oder entfallen:

| frühere Art | jetzt | wo |
|---|---|---|
| `parent_of` | Angabe *Elternvorgang* bzw. *Elternprojekt* | §7.6, §7.4 |
| `supersedes` | Angabe *Abgelöst durch* | §7.8, §7.9, §7.15, §7.16 |
| `verifies` | **entfällt ersatzlos**; der Erfüllungsstand steht am Vorgang | §7.6, Regel 1 |
| `documents` | **entfällt**; ersetzt durch `references` mit Pflichtbeschreibung | unten |

#### Die vier Beziehungsarten

| Beziehung | Ohne sie bricht | Kontextquelle | Beispiel / Gegenbeispiel |
|---|---|---|---|
| `implements` | „Welche Vorgänge setzen diese Entscheidung um?“ | GitHub-Konvention „fixes #123“ | `#9e2b → KEP-Lite #8c21`; `references` ist kein Umsetzungsbeweis. |
| `derived_from` | Die Grundlage müsste bei jeder Ableitung angefasst werden (P-007) | W3C PROV-DM 5.2.1 | `ADR #17ad → KEP-Lite #8c21`; die Gegenrichtung behauptet einen anderen Verlauf. |
| `references` | Schwache Hinweise wandern in die starken | Jira-Praxis: `relates to` sammelt alles Uneingeordnete | `Runbook → Richtlinie`; Beschreibung ist Pflicht. |
| `depends_on` | Reihenfolge müsste in die Hierarchie (Ablauf C) | Jira `blocks` / `is blocked by` | `Kashasaga/#7c40 → pcs-php/#2e91`; setzt keinen Zustand. |

**Warum `documents` entfällt:** Nach dem Wegfall der Arbeitsdokumentation hätte
die Art keine gültige Quellart mehr. Was sie leistete, leistet `references` mit
Pflichtbeschreibung:

```text
vorher   Postmortem --documents--> #c73e
nachher  Postmortem --references--> #c73e
         Beschreibung: de: „wertet diese Störung aus“
```

#### Zyklenprüfung

**Festlegung:** Die Zyklenprüfung läuft **je Beziehungsart**. `derived_from` ist
zyklenfrei; `depends_on` ist zyklenfrei und **global**, also über
Projektgrenzen hinweg. `implements` und `references` sind ungeprüft.

**Kosten, benannt:** Ein Ring über zwei Arten hinweg wird nicht erkannt.

```text
ungeprüft   KEP #8c21 --derived_from--> #a1f4 --depends_on--> #8c21
            Jede Art für sich ist zyklenfrei; zusammen ist es ein Ring.
```

Der Fall ist konstruiert und in keinem wirklichen Ablauf vorgekommen. Tritt er
auf, ist eine übergreifende Ordnung nach P-012 zu entscheiden – nicht vorher.

#### Die zwei Arten mit Deutungsspielraum

**`references` – der schwache Hinweis**

```text
richtig   Runbook „Vorschau neu aufbauen“  --references-->  Richtlinie
          Beschreibung: „nennt die Frist, die dieses Runbook einhält“

falsch    #9e2b  --references-->  KEP-Lite #8c21
          gemeint war: der Vorgang setzt die Entscheidung um
          Folge: „was setzt #8c21 um?“ findet nichts.

Prüfung   Lässt sich die Beschreibung als „setzt um“ oder „entstand aus“
          formulieren, ist references falsch.
```

**`depends_on` – die Reihenfolge**

```text
richtig   #4c19  --depends_on-->  #9e2b
          Setzt keinen Zustand; schränkt nur den Wechsel nach
          „in Arbeit“ ein – übergehbar mit Grund (§7.6, Regel 12).

falsch    #3f70  --depends_on-->  #9e2b   (Epos auf sein eigenes Kind)
          Ein Epos wartet nicht auf seine Kinder, es besteht aus ihnen.

falsch    #7c40  --depends_on-->  „Release 2.1 der Fremdbibliothek“
          Kein Gegenstand → Zustand blockiert, Blockadegrund als Fachtext.

falsch    #4c19  --depends_on-->  #9e2b, weil #9e2b zeitlich vorher lief
          Die Kante behauptet eine Bedingung, keine Beobachtung.
```

**Ohne die Kante `depends_on`** *(erlebt: Kashasaga / `pipeline-config-spec-php`)*

```text
Kashasaga / #7c40   „show-Sicht mit JSON-Ausgang“
pcs-php   / #2e91   „JSON-Serialisierung“

Beide gleichzeitig entwickelt. Dass #7c40 auf #2e91 wartete,
stand nirgends – es wussten nur die, die dabei waren.
```

**Die berechnete Reihenfolge ist eine Halbordnung, keine Reihe.** Zwei Vorgänge
ohne Kante dürfen parallel laufen. Wird der Baum zu groß, ist das ein **Befund**
(§7.6, Regel 16) – kein Anzeigeproblem.

### 8.2 Erlaubte Endpunkte

Eine Kante mit unzulässigen Endpunkten ist ein Fehler, keine ungewöhnliche
Meinung (P-008). Beide Endpunkte sind **Fachgegenstände**; Projekt und Bereich
sind Rahmen (§7.3) und deshalb weder Quelle noch Ziel.

```text
Projektabhängigkeit  Kashasaga/#7c40  depends_on  pcs-php/#2e91
Projekt --depends_on--> Projekt wäre unprüfbar: ein Projekt hat keinen
Abschlusszustand, auf den gewartet werden könnte.
```

#### Je Beziehungsart

| Beziehung | Richtung | Beschreibung Pflicht | Zyklenprüfung | Projektgrenze |
|---|---|---|---|---|
| `implements` | Vorgang → Vorgabe | nein | keine | frei |
| `derived_from` | Abgeleitetes → Grundlage | nein | ja | frei |
| `references` | beliebig | **ja** | keine | frei |
| `depends_on` | Späteres → Früheres | nein | ja, **global** | frei |

#### Je Endpunktkombination

*n je Quelle* / *n je Ziel*: leer heißt unbegrenzt.

| Beziehung | Von | Nach | n je Quelle | n je Ziel |
|---|---|---|---|---|
| `implements` | Vorgang | KEP-Lite, ADR, Richtlinie, System-Spezifikation, Ablauf-Spezifikation, Drift-Bericht, Postmortem | | |
| `derived_from` | ADR | KEP-Lite | 1 | |
| | KEP-Lite | Vorgang, Feature-Matrix, Drift-Bericht, Postmortem | | |
| | System-Spezifikation, Ablauf-Spezifikation, Richtlinie | ADR | | |
| | Runbook, Testmatrix, Drift-Bericht | System-Spezifikation, Ablauf-Spezifikation | | |
| `depends_on` | Vorgang | Vorgang | | |
| `references` | jede Fachart | jede Fachart | | |

**Ablesen:** Eine Zeile mit mehreren Quell- und Zielarten steht für alle
Kombinationen.

**Zu `depends_on` gegenüber der Hierarchie:** Die Angabe *Elternvorgang* bleibt
projektintern – die Gliederung deckt die Arbeit *eines* Projekts vollständig ab
(P-002). `depends_on` ist keine Zerlegung, sondern eine Tatsache über die
Reihenfolge der Welt.

```text
zulässig    Kashasaga/#7c40  depends_on   pcs-php/#2e91
unzulässig  Kashasaga/#3f70  Elternvorgang von pcs-php/#2e91
unzulässig  #7c40 → #2e91 → #9a03 → #7c40   (Zyklus über drei Projekte)
```

`references` darf keine präzisere Beziehung ersetzen.

---

## 9. Lebensläufe

Beispiele, keine Regeln; die Regeln stehen in §4, §5 und §7.

### 9.1 Ablauf A – kleine direkte Änderung

| Zeit | Ereignis | Zustand | Angaben, die dabei entstehen |
|---|---|---|---|
| 09-02 10:05 | erfasst | *Eingang* | Titel, Beschreibung, Projekt, Bereich `publishing` |
| 09-02 10:07 | Kriterium ergänzt | *bereit* | Art *Aufgabe*, Dringlichkeit, K1: „Die Startseite zeigt in de und en den Projektnamen aus der Projektangabe.“ |
| 09-02 10:20 | begonnen | *in Arbeit* | Bearbeitung: Dani. Kein aktiver Sprint → Vorhaben-Schranke entfällt |
| 09-02 10:40 | Arbeit beendet | *in Prüfung* | |
| 09-02 10:45 | geprüft | *abgeschlossen* | K1 auf *erfüllt*; Verlaufseintrag trägt Prüfung: Dani |

**Warum nicht weniger:** Ohne K1 wäre „abgeschlossen“ eine Einzelmeinung (Z2).
**Warum nicht mehr:** Es gab keine Alternative abzuwägen (Z8).

#### Fall A2 – dieselbe Woche, nebenbei

| Zeit | Handlung | Was in Pages PM entsteht |
|---|---|---|
| 09-04 16:12 | Änderung eingereicht; der Commit-Trailer nennt `#d5aa` | Beitrag `[3] git:… · 2026-09-04 · en: „fix: sidebar spacing“` am Sammelvorgang |

Kein Vorgang, kein Zustand, kein Kriterium – eine Zeile.

**Wann es nicht mehr genügt:** Sobald jemand sagt „die Seitenleiste soll auf
allen Breiten stimmen“, ist ein Ergebnis zugesagt – dann gilt A1.

### 9.2 Ablauf B – entscheidungsbedürftige Änderung

| Zeit | Gegenstand | Ereignis |
|---|---|---|
| 07-28 | Vorgang #a1f4, Art *Aufgabe* | Untersuchung „Fallback-Verhalten der drei Anzeigeorte“. Ergebnis: Feature-Matrix (§7.13). |
| 07-30 | KEP-Lite #8c21 | *Entwurf*: Problem, Vorschlag, zwei verworfene Alternativen, zwei Kriterien |
| 08-01 | #8c21 | *in Prüfung* |
| 08-03 | #8c21 | *angenommen*; #a1f4 wird *abgeschlossen* |
| 08-03 | #9e2b, #4c19 | angelegt, `implements → #8c21`, Sprintauswahl #6f30; `#4c19 depends_on #9e2b` |
| 08-04 | #9e2b | *in Arbeit* |
| 08-05 | ADR #17ad | *angenommen*; `derived_from → #8c21` |
| 08-06 … 08-10 | #9e2b | *blockiert* („Platzhaltertext fehlt“, außen) → *in Arbeit* → *in Prüfung* |
| 08-11 | #9e2b | K1 auf *erfüllt*; K2 fällt durch → zurück nach *in Arbeit* |
| 08-12 | #9e2b | K2 auf *erfüllt*; *abgeschlossen* |
| 08-12 | #4c19 | *in Arbeit* – erst jetzt zulässig |
| 08-13 | #8c21 | K1 und K2 auf *erfüllt*; *umgesetzt* |

**Was der Verlauf sichtbar macht:** Zwischen dem 3. und dem 13. August war die
Entscheidung angenommen und nicht umgesetzt (Z3).

**Was er nicht zeigt:** *Welches* Kriterium am 11.08. durchfiel. Ablesbar bleibt
der Rückweg. Wäre das nötig, wäre #9e2b nach §7.6, Regel 15 zu teilen gewesen.

### 9.3 Ablauf C – hierarchische Arbeit und Reihenfolge

```text
Gliederung (Angabe Elternvorgang)
#3f70  Epos      „Sprach-Fallback vereinheitlichen“        in Arbeit
  ├─ #9e2b  Funktion  „Fallback-Kette im Renderer“          abgeschlossen
  ├─ #4c19  Funktion  „Fallback-Kette in der Oberfläche“    in Arbeit
  └─ #7b0d  Aufgabe   „Vollständigkeitstest beidseitig“     bereit

Reihenfolge (depends_on, berechnet)
#9e2b → { #4c19, #7b0d }        #4c19 und #7b0d dürfen parallel laufen
```

Das Epos kann nicht abgeschlossen werden, solange #4c19 oder #7b0d offen sind.

### 9.4 Ablauf D – Sprint planen und fortschreiben

| Zeit | Ereignis | Wirkung |
|---|---|---|
| 08-03 | Sprint #6f30 → *aktiv*, Projekte {Kashasaga, pcs-php} | anfänglicher Umfang `[#7c40, #2e91]` festgeschrieben |
| 08-06 | #7c40 → *in Arbeit* mit Übergehung | `depends_on #2e91` nicht erfüllt; Grund vermerkt |
| 08-09 | #9a03 ins Vorhaben und bearbeitet | Rolle *dazwischengekommen* |
| 08-09 | #88ce erfasst, nicht bearbeitet | gehört **nicht** zum Ist-Umfang |
| 08-12 | #2e91 → *abgeschlossen* | |
| 08-13 | #7c40 für Sprint #b204 ausgewählt | bleibt im Ist-Umfang von #6f30 |
| 08-14 | #6f30 → *abgeschlossen* | Review- und Retrospektiv-Notiz |

Danach ist ablesbar:

```text
Anfänglich     {#7c40, #2e91}      Vorhaben   {#7c40, #2e91, #9a03}
Ist            {#7c40, #2e91, #9a03}
Dazwischen     {#9a03}             Übernahme  {#7c40}
Übergehungen   1
Eingangsalter  Kashasaga 19 Tage · pcs-php 4 Tage
```

**Warum der Ist-Umfang vollständig ist:** Bliebe #9a03 außerhalb, läse sich der
Sprint als „zwei geplant, einer erledigt“ – ein Planungsproblem. Tatsächlich
ging ein Drittel des Zeitraums an ungeplante Arbeit.

### 9.5 Ablauf E – Störung

| Zeit | Ereignis | Träger |
|---|---|---|
| 07-18 09:10 | Ausgabe zeigt Rohschlüssel | Vorgang #c73e, Art *Fehler*, Dringlichkeit *kritisch* |
| 07-18 09:15 | Runbook „Vorschauumgebung neu aufbauen“ ausgeführt | Schritte abgearbeitet |
| 07-18 09:50 | sicherer Zustand hergestellt | #c73e → *in Prüfung* |
| 07-19 | Auswertung begonnen | Postmortem, *Entwurf*, `references → #c73e` |
| 07-21 | Auswertung abgeschlossen | Maßnahme [1] → neuer Vorgang #7b0d |

Die Reihenfolge ist die Aussage: erst der sichere Zustand, dann die
Ursachensuche.

### 9.6 Ablauf F – Import und Ableitung

```text
#9e2b
    Herkunft:      jira:J01-105 · Ausschnitt comment:4 · 2026-06-11
    implements     → KEP-Lite #8c21      (setzt diese Entscheidung um)
#4c19
    depends_on     → #9e2b               (kommt danach)
ADR #17ad
    derived_from   → KEP-Lite #8c21      (entstand aus dieser Entscheidung)
```

Vier verschiedene Aussagen: *woher es kam*, *was es ausführt*, *was vorher
fertig sein muss*, *woraus es entstand*. Zusammengelegt ließe sich „was stammt
nicht von uns?“ nicht mehr als Suche stellen (Z5).

---

## 10. Gegenwärtiger, veränderbarer Produktstand

**§10 wird von Hand geführt und gilt zum Ist-Stichtag im Kopf.** Ein berechneter
Produktstand setzte einen Nachweisbegriff voraus, der feiner auflöst als jeder
Pages-PM-Gegenstand (P-014, Anhang A.6).

**Zwei Marken:**

```text
(Ist-Stand)      im Arbeitsbaum vorhanden und nachweisbar
(Einschätzung)   fachlich möglich auf der bestehenden Struktur, nicht erprobt
```

### 10.1 Arbeitsstand, nachweisbar im Arbeitsbaum *(Ist-Stand)*

| Beobachtbares Verhalten | Bezug | Kleinstes Beispiel | Grenze am Stichtag |
|---|---|---|---|
| Projekte und Hierarchie sind vorhanden. | P-002 | `parent(Pages PM)=Kashasaga` | Hierarchie und Projektzustand umgesetzt und getestet |
| Bereiche erlauben Mehrfachzuordnung. | P-003 | `areas(X)={build,deploy}` | Mehrfachzuordnung und Bereichszustand umgesetzt und getestet |
| Externe Herkunft besitzt Quelle, Fundstelle und Ausschnitt. | P-006 | `origin(X)=jira:J01-1#comment:4` | vollständig umgesetzt |
| Beziehungsarten besitzen Richtung, Endpunktregeln und Zyklenprüfung je Art. | P-008, §8.1 | `derived_from` sowie `depends_on` mit Vorgang → Vorgang sind konfiguriert | `documents` ist zu entfernen; die Zustandswechselschranke von `depends_on` fehlt noch |
| Fachgegenstände erhalten innere Kennung und Fachart. | P-001 | Registrierung über die Fachtabelle | Registrierung mit UUID und Fachart umgesetzt und getestet |
| Jeder registrierte Fachgegenstand erhält eine Kurzkennung. | P-001, §7.4 | `#a7k2` löst den zugeordneten Gegenstand auf oder nach dessen Löschung keinen | automatische Vergabe, eindeutige Zuordnung und dauerhafte Nichtwiedervergabe umgesetzt und getestet |
| Zustandsverlaufseinträge können nur ergänzend fortgeschrieben werden. | P-010 | `pm.state_history` führt Sequenz, Zeitpunkt, Akteur, Ereignisart und Pflichtgrund | Nur ergänzbarer Speicher und geschützter Schreibweg umgesetzt; die atomare Verbindung mit dem fachlichen Zustandswechsel fehlt (§10.2) |

**Der einzige Punkt im Reifegrad *aktuell*:**

| Verhalten | Benannter Ablauf |
|---|---|
| Deutsch und Englisch sind gleichrangige Pflichtsprachen. | Die Projektkonfiguration ist angewandt; ein Titel mit nur `{de}` wird abgewiesen, einer mit einer nicht konfigurierten Sprache ebenfalls. |

### 10.2 Arbeitsstand

Der **Vorgang** (§7.6) ist als erste Fachart begonnen. Vorhanden und getestet
sind die Fachtabelle, ihre Registrierung im Mindestraster (§7.3), die
Projektzugehörigkeit, die zyklenfreie Hierarchie mit zulässigen
Eltern-/Kindarten (Regeln 2 und 3), die Zugehörigkeit von Eltern- und
Kindvorgang zu demselben Projekt (Regel 4), der `depends_on`-Endpunkt
Vorgang → Vorgang sowie die Prüfregeln über die einzelne Zeile:
Pflichtangaben ab *bereit*, das Schema der Abschlusskriterien, die
Sprachausnahme im Eingang, die dauerhafte Unveränderlichkeit der Vorgangsart
und die einmal erreichte Schwelle (§7.1.1, Regel 6 – „Rückwege löschen nichts“).
Hinzu kommt der kontrollierte Zustandswechsel `pm.transition_issue()` mit den
Regeln, die einen Übergang im Zusammenhang mit anderen Vorgängen und dem
Zustandsverlauf prüfen (siehe unten).

**Die übrigen Vorgangsregeln haben einen gemeinsamen Ausführungspunkt:** Sie
prüfen einen Zustandsübergang im Kontext mehrerer Zeilen oder verbinden ihn mit
einer Nebenfolge. Sie liegen geschlossen in `pm.transition_issue()`, damit kein
fachlicher Schreibweg an ihnen vorbeiführt:

```text
zulässige Übergänge  die Übergänge aus §7.6 werden über eine abfragbare
                     Tabelle geprüft
Abschlussprüfung     bei offenen Kindvorgängen oder nicht erfüllten
                     Abschlusskriterien gesperrt
Regel 5              das Epos folgt der gewöhnlichen Übergangstabelle;
                     sein Abschluss verlangt mindestens einen Kindvorgang
Regel 12             Abhängigkeitsschranke mit begründeter Übergehung,
                     als eigener Verlaufseintrag geführt
P-010                Zustand und Zeitpunkte werden geändert und der
                     Verlaufseintrag wird im selben Funktionsaufruf und
                     in derselben Transaktion ergänzt; bei einem Fehler
                     wird alles gemeinsam zurückgerollt
```

`editor` darf den Zustand nicht unmittelbar ändern. Zustandswechsel erfolgen
ausschließlich über `pm.transition_issue()`, für die `editor` das
Ausführungsrecht besitzt. Auch `finished_at` darf `editor` nicht unmittelbar
ändern; der Zeitpunkt wird ausschließlich durch die Übergangsfunktion bei einem
Wechsel nach *abgeschlossen* oder *verworfen* gesetzt.

Der Blockadegrund bleibt dagegen unmittelbar änderbar: Er kann sich während
derselben Blockade sachlich ändern, ohne dass ein Zustandswechsel stattfindet.

**Die Übergangstabelle im Arbeitsbaum entspricht noch der früheren, weitgehend
linearen Fassung**; §7.1.2 und die neu gefassten Übergänge aus §7.6 sind am
Stichtag noch nicht umgesetzt.

**Noch nicht geprüft wird Regel 11 (Vorhaben-Schranke).** Sie setzt den Sprint
voraus, der nicht Teil des ersten Go-live ist.

**Zwei ausdrückliche Begrenzungen des ersten Go-live:**

*Verantwortung (P-004)* wird noch nicht geführt. Fachliche Identitäten für
Menschen und Agenten sind nicht modelliert; ein Vorgang kann deshalb weder die
Bearbeitung ab *in Arbeit* noch die Prüfung ab *in Prüfung* einer
verantwortlichen Identität zuordnen. Das ist eine befristete, hier benannte
Abweichung, keine Aufhebung der Anforderung: Das Identitäts- und
Verantwortungsmodell folgt nach dem ersten vollständigen Vorgangslebenslauf.

*Der Sammelvorgang (§7.6.1)* ist noch nicht benutzbar. Ohne Beiträge,
Mindesthandlung und Richtlinienverweis wäre er formal anlegbar, aber fachlich
unvollständig; die zulässigen Vorgangsarten schließen ihn deshalb noch aus.

**KEP-Lite ist nicht begonnen.** Die Fachart steht in §6.1 auf *geplant*: Die
Vorlage §7.7 ist fertig, eine Migration im maßgeblichen Arbeitsbaum gibt es
nicht.

### 10.3 Noch nicht benutzbar

```text
gemeinsames Auffinden        die gemeinsame Lesesicht über die Fachtabellen
  (P-011)                    fehlt – die größte einzelne Lücke
Verantwortung (P-004)        keine Entsprechung; für den ersten Go-live
                             ausdrücklich befristet zurückgestellt (§10.2)
Sammelvorgang (§7.6.1)       als Vorgangsart noch ausgeschlossen (§10.2)
Sprint, KEP-Lite und die übrigen Facharten, Renderer und
Benutzeroberfläche
```

**Prüfnachweis und Arbeitsdokumentation stehen nicht hier, sondern in §6.2:**
Sie sind nicht „noch nicht gebaut“, sondern nach P-012 **nicht angenommen**.

### 10.4 Wechselbarkeit

Technische Formen dürfen ersetzt werden. Erhalten bleiben müssen die fachlichen
Festlegungen dieser Spezifikation – oder eine begründete Ablösung nach P-010.

---

## 11. Nächster fachlicher Meilenstein

**Ein vollständiger Vorgangslebenslauf im wirklichen Betrieb** – nicht eine
weitere Fachart, sondern der erste Gegenstand, der den ganzen Weg geht:

1. Projekt wählen;
2. Vorgang nach §7.6 im Eingang anlegen;
3. ihn über die Pflichtschwellen nach *bereit* führen (§7.1.1);
4. einen zweiten Vorgang als Voraussetzung anlegen und mit `depends_on`
   verbinden; der Wechsel des abhängigen Vorgangs nach *in Arbeit* wird bei
   offener Abhängigkeit abgewiesen; den vorausgesetzten Vorgang vollständig
   durch seinen zulässigen Lebenslauf führen und abschließen; danach gelingt
   der Wechsel (Regel 12);
5. einen Kindvorgang anlegen; der Abschluss des Elternvorgangs wird zunächst
   abgewiesen; danach den Kindvorgang durch seinen zulässigen Lebenslauf
   führen und abschließen, die Abschlusskriterien des Elternvorgangs erfüllen
   und den Elternvorgang abschließen; der Beendigungszeitpunkt wird gesetzt
   (Regel 1);
6. prüfen, dass abgewiesene Übergänge weder Zustand noch Verlauf verändern,
   und den Zustandsverlauf der erfolgreichen Wechsel lesen (P-010);
7. die beteiligten Vorgänge über das gemeinsame Mindestraster auffinden
   (§7.3, P-011).

Die in §10.2 benannte befristete Abweichung für Verantwortung bleibt für diesen
ersten Go-live bestehen; sie ist daher kein Abnahmekriterium dieses
Meilensteins.

**Kontextquelle:** Work-Item-Praxis und der Scrum Guide zur Definition of Done
(§6.1) – ein Element gilt erst als fertig, wenn es der gemeinsamen
Fertigstellungsregel genügt.

**Warum keine zweite Fachart davor?** Der Vorgang trägt bereits alle
Mechanismen, die jede weitere Vorlage später wiederverwendet: Mindestraster,
Zustände und Schwellen, Beziehungen und Verlauf. Eine zweite Vorlage vor dem
ersten vollständigen Lebenslauf würde nichts prüfen, was dieser Ablauf nicht
schon prüft.

**Die übrigen Facharten folgen bei konkretem Bedarf.** Sprint, KEP-Lite, ADR
und Richtlinie stehen in §6.1 auf *geplant*; keine von ihnen ist Voraussetzung
dieses Meilensteins. Eine Fachart wird umgesetzt, sobald ein wirklicher
Projektablauf sie benötigt (§12.4). Dasselbe gilt für die Vorhaben-Schranke
(§7.6, Regel 11): Die Entscheidung bleibt fachlich gültig; ihre technische
Umsetzung erfolgt zusammen mit der benötigten Sprint-Unterstützung.

**Gegenbeispiel:** Ein technisch anlegbarer Vorgang ohne geprüften
Zustandswechsel, ohne Verlauf und ohne gemeinsames Auffinden erfüllt den
Meilenstein nicht – ein grüner Testlauf über eine Tabelle ist kein Nachweis
eines Ablaufs (§2).

---

## 12. Ablösung und offene Punkte

### 12.1 Ablösung

Diese Datei ersetzt auf der Produktschicht die früher getrennten
Produktanforderungen, Ablauf-Spezifikationen und Erweiterungsvorschläge in
`.local/`. Technische Ableitungen bleiben getrennte, nicht normative Unterlagen
der Umsetzungsschicht und richten sich nach §7.

### 12.2 Offene Punkte

1. **Marktprüfung – erledigt am 27. Juli 2026, mit zwei Vorbehalten.** Neun
   Werkzeuge sind in Anhang D geprüft. Sie stützt sich auf
   Herstellerdokumentation, nicht auf eigenen Betrieb. **Und sie ist an der
   falschen Menge geprüft:** Der wirkliche Vergleichsfall ist ein Paar aus
   Tracker und Wiki (Jira + Confluence, GitHub Issues + Wiki + ADR-Dateien,
   Linear + Notion, Backstage/TechDocs). Zu wiederholen, bevor größere
   Umsetzungsentscheidungen darauf gestützt werden.
2. **Wortlautprüfung.** Alle Paraphrasen in *Was sie sagt* sind an den
   Originaltexten der Klassen A, B und C zu prüfen. Geprüft am 27. Juli 2026:
   NASA WBS Handbook, DACS Statement of Principles, SAA Dictionary,
   Gotel/Finkelstein 1994. Geprüft am 2. August 2026: Open Guide to Kanban
   v2025.7, Atlassian-Jira- und OpenProject-Workflow-Dokumentation – bei
   OpenProject zusätzlich die Umsetzung. Alles Übrige bleibt **(ungeprüft)**.
3. **Bruchfall-Prüfung.** Die mit `(offen)` markierten Bruchfälle sind zu
   belegen; die Anfragen stehen in §12.3.
4. **Allgemeine Abschlussrichtlinie.** §7.6 verweist auf eine projektweit
   geltende Abschlussdefinition; ihr Inhalt ist nicht entschieden.
5. **Erfassungsgrenze der Sprintauswertung.** Ob Zuarbeit, Unterbrechungen und
   Gespräche als Vorgänge geführt werden, ist nicht entschieden. Bis dahin gilt
   jede Auslastungsaussage als untere Schranke.
6. **Urheber von Beiträgen.** §7.6.1, Regel 3 nennt keinen Urheber. Bei mehreren
   Gruppen an demselben Sammelvorgang ist Regel 5 nicht mehr auswertbar.
7. **Erwartungswerte, gesetzt und zu überprüfen.** Drei Zahlen stehen als
   *Erwartung* in den Vorlagen, damit die Regeln greifen. Sie sind
   Eigenentscheidungen ohne Quelle und werden nach der ersten Benutzung
   überprüft:

   ```text
   Prüffrist für Runbooks        180 Tage      §7.10, Regel 1
   Sammelvorgang-Wächter          30 %         §7.6.1, Regel 8
   Postmortem-Auslöser            außerhalb des Teams bemerkt   Ablauf E
   ```
8. **Welche Projektionen veröffentlicht werden.** Dass sich aus dem
   Beziehungsgraphen Seiten ableiten lassen, ist entschieden; welche, nicht. Ein
   Graph lässt sich beliebig schneiden, und die meisten Schnitte sind
   vollständig und unlesbar. Zu entscheiden sind mindestens: die Einstiegsseite,
   die Gliederungsachse, die Behandlung überholter Gegenstände und ob Fachtexte
   in allen Pflichtsprachen nebeneinander erscheinen. Diese Fragen gehören in
   die Umsetzungsschicht oder in ein KEP-Lite – §3.2 hält Darstellung heraus.

   Zur Veranschaulichung, welche Projektionen ohne zusätzliche Erfassung möglich
   wären:

   ```text
   je Entscheidung   KEP-Lite #8c21 → ADR #17ad → #9e2b, #4c19
   je Regel          DEPLOY-03 → Beiträge, die den Schlüssel nennen
   je Ablösung       ADR #17ad → #19cf → #21b7      „was galt wann?“
   ```
9. **Anbindung an Dokumentationsformate – bewusst vertagt.** Ob und wie
   Pages-PM-Gegenstände mit AsciiDoc, Markdown im Repository oder Docstrings
   zusammengeführt werden, ist offen. **Die Vertagung ist die Entscheidung:**
   Der Quelltext ist die direkteste Quelle für den Ist-Zustand, Pages PM die
   maßgebliche für das Soll – zwei maßgebliche Quellen für dieselbe Aussage sind
   die Doppelpflege aus §3.2. Wieder aufzunehmen, sobald der Renderer steht.
10. **Zwei Regeln der Grundlage ruhen auf einer Quelle.** Ablauf A1 und Ablauf D
    ruhen auf dem Scrum Guide, der sich selbst als unvollständig bezeichnet und
    beispielfrei ist. Für sie gibt es keinen Ersatz in der Literatur; ihre
    Belege müssen aus der Erfahrung kommen (§12.3, Zeilen zu Ablauf A1 und Ablauf D).

### 12.3 Anfragen an die archivierte PM

**Reihenfolge:** zuerst die Quelle, dann diese Liste. Die Liste enthält nur
Regeln, deren Quelle nichts hergibt.

| Regel | Frage | Wo suchen | Positiver Fund heißt |
|---|---|---|---|
| **Ablauf A1** | Wurde über „fertig" gestritten? | Kommentarverläufe abgeschlossener Vorgänge; Wiedereröffnungen | Ein Vorgang wurde als erledigt markiert und danach bestritten |
| **Ablauf D** | Lief ungeplante Arbeit, die im Sprint nicht auftauchte? | Sprintberichte gegen Aktivitätsverläufe | Bearbeitete Vorgänge fehlen im Sprintumfang |
| **§7.12 Drift-Bericht** | Gab es zwei zusammengehörende Abweichungen? | Fehlervorgänge mit ähnlichem Titel; Prüfberichte | Zwei Befunde, gemeinsam zu bewerten gewesen |
| **§7.13 Feature-Matrix** | Wurde eine Vergleichstabelle nach der Entscheidung noch geöffnet oder geändert? | Wiki- und Dateianhänge mit Änderungsdaten | Änderungsdatum nach dem Entscheidungsdatum |
| P-004 | Hat jemand seine eigene Arbeit geprüft? | Vorgänge mit Bearbeiter- und Prüferfeld | Beide Felder gleich |
| P-005 | Gab es eine Sprachkarte, die vollständig aussah und keine war? | Felder mit identischem Wert in beiden Sprachen; „TODO“ | inhaltlich nicht übersetzt |
| P-008 | Wurde eine Beziehung gesetzt, die niemand deuten konnte? | Verknüpfungen „relates to“ | Bedeutung nicht rekonstruierbar |
| P-011 | Blieb eine Frage unbeantwortet, weil zwei Arten getrennt lagen? | Kommentare „wo steht …“ | Antwort lag in einer anderen Objektart |
| §7.6.1 | Wurde Kleinarbeit nicht erfasst? | Commits ohne Vorgangsbezug | Änderung ohne jeden Vorgang |
| §7.6, Zustand *in Klärung* | Wurde derselbe Eintrag zweimal angefangen? | doppelte Titel; zwei Beginn-Ereignisse | zwei Personen begannen dieselbe Beurteilung |
| §7.6, Regel 12 | Wie oft wurde gegen einen halbfertigen Vorgänger begonnen? | Blockierbeziehungen, Startdatum gegen Vorgängerabschluss | Start vor dem Abschluss des Vorgängers |
| §7.9 | Wurde je auf eine einzelne Regel verwiesen? | Kommentare, Commits, Reviews | Verweis auf einen benannten Regelabschnitt |
| §12.2, Punkt 8 | Welche Übersichtsseite wurde gelesen, welche nie? | Wiki-Zugriffszahlen | Seite mit hoher bzw. null Nutzung |

Gestrichen, weil die Quelle geantwortet hat: P-002, P-003 und Ablauf C (NASA WBS
Handbook), P-006 (DACS), Anhang C.1 (Gotel/Finkelstein).

**Dringend: Ablauf A1 und Ablauf D** – für sie gibt es keine Literatur.
**Für eine Aufnahme nötig: §7.13 und §7.12.**

### 12.4 Umfang der ersten Fassung

**Was zurückgestellt ist, ist entschieden – nicht vergessen.**

| Art | Grund | Wiederaufnahme, wenn |
|---|---|---|
| **Prüfnachweis** (Anhang C.1) | kein bestimmbarer Entstehungsanlass; bricht P-014, weil ein Feldschlüssel zum Existenzgrund eines Gegenstands würde | eine Schnittstelle benannt ist, die Nachweise ohne Rauschen und ohne zweiten Bestand erzeugt |
| **Arbeitsdokumentation** (Anhang C.2) | ihre vier Angaben haben jeweils einen anderen Ort; kein eigener Zweck | ein Arbeitszusammenhang über mehrere Systeme auftritt, dessen Stand kein Repository kennt |
| **Sprint** (§7.5) | eigener, späterer Ausbau mit umfangreichen zusätzlichen Regeln und Auswertungen (Ist-Umfang aus dem Zustandsverlauf, Sammelvorgang-Wächter, Projektionen); nicht Teil des ersten Go-live | Vorgang und Zustandsverlauf (P-010) betrieblich in Benutzung sind und ein wirklicher Sprintzeitraum geplant und ausgewertet werden soll |

**Zurückgestellt heißt hier nicht „nicht angenommen“** (anders als Prüfnachweis
und Arbeitsdokumentation, §6.2): Sprint bleibt eine angenommene Fachart mit
Reifegrad *geplant* (§6.1). Zurückgestellt ist nur seine Aufnahme in den
**ersten Go-live**.

**Umfang des ersten Go-live.**

```text
1. Grundlage               Identität, Register, Kurzkennung, Sprachen,
                            Projekte und Bereiche, Projektzugehörigkeit,
                            Herkunft, Beziehungen, Zustandsverlauf,
                            gemeinsame Rechte, Hilfsfunktionen und Lesesicht
2. Vorgangsebene (§7.6)     vollständige Vorgangsvorlage auf dem
                            gemeinsamen Vorlagenmuster
3. erste tatsächlich        kein Vorratsbau aller angenommenen Facharten
   benötigte Dokumentvorlage
4. erster wirklicher        Pages-PM-Arbeit vollständig darin führen
   End-to-End-Ablauf
```

Die gemeinsame Lesesicht (P-011) gehört zur Grundlage, auch wenn sie erst mit
dem Vorgang praktisch gefüllt wird. Die gemeinsame Vorlagenebene (§7.1–7.3)
ist ebenfalls keine eigene betriebliche Stufe nach dem Vorgang, sondern das
gemeinsame Umsetzungsmuster, das die Vorgangsvorlage in Schritt 2 bereits
selbst verwendet.

Sprint wird erst aufgenommen, wenn die Bedingung in der Tabelle oben eintritt.

**Wo die Zuständigkeit endet.**

```text
Pages PM führt        „dass es fertig ist“
                      #9e2b abgeschlossen 08-12, Prüfung: Dani

die Schnittstelle     „woran es fertig ist“
                      Testlauf, Einreichung, Prüflauf

„Einmal durchgefallen“ bleibt lesbar – am Rückweg im Verlauf,
nicht am Kriterium. Wo das nicht genügt, ist der Vorgang zu groß
geschnitten (§7.6, Regel 16).
```

**Was die erste Fassung enthält.** Auf der vorhandenen Grundlage – Identität,
Register, Sprachen, Bereiche, Herkunft, Beziehungen, Projekte – kommen die
Inhaltsarten. Jede folgt demselben Muster; das ist eine **lineare Ergänzung**:

```text
je Art:  feste Felder · Zustand · Nebenfolgen · ein dynamisches Feld
         dazu Objektart eintragen, Registrierung, Sprachprüfung, Rechte
         – alles aus der Grundlage fertig, kein neuer Mechanismus
```

**Die einzige nicht-lineare Stelle ist §8.2.** Facharten wachsen linear,
Endpunktkombinationen mit den Paaren. Fehlt eine Zeile, ist die Kante unzulässig
– die richtige Voreinstellung.

**Warum nicht nur Vorgänge.** Mit Vorgängen allein wäre Pages PM ein Tracker
ohne Dokumentation – und dann leisten bestehende Werkzeuge mehr (Anhang D). Der
Unterschied entsteht erst dadurch, dass Steuerung und geltende Dokumente **im
selben Graphen** liegen.

**Was die erste Fassung leistet und andere nicht:**

```text
Übernahme bei Bedarf statt in einem Zug
    Fremdeinheiten werden einzeln normalisiert (P-006); kein
    Import-Stichtag. Der Altbestand landet als Vorgang im Eingang.

Kennung statt laufender Nummer
    Übernommenes bekommt keine Nummer, die eine Reihenfolge behauptet

Steuerung und Dokumentation in einem Graphen
    keine zweite Anwendung daneben, kein Wiki mit eigenem Bestand

Kanten sind geprüft
    eine falsche Verbindung ist ein Fehler, keine Meinung (§8.2)
```

---

## Anhang A – Wie diese Spezifikation geschrieben ist

Dieser Anhang richtet sich an die, die die Spezifikation fortschreiben.

### A.1 Beschreibungsform

Jede fachliche Regel ist eine **Pages-PM-Festlegung**. Zu jeder Regel wird eine
**Kontextquelle** genannt: ein Erfahrungsfeld, auf dem dieselbe Frage bereits
bearbeitet wurde. Die Kontextquelle begründet die Regel nicht. Begründet wird sie
durch den **Auswahlgrund**.

Jede fachliche Anforderung und jeder Kernablauf folgt diesem Muster:

1. **Ohne diese Regel:** der Schaden, den es ohne sie gibt – mit Herkunftsmarke;
2. **Aufgabe:** die fachliche Frage, die Pages PM entscheiden muss;
3. **Kontextquelle** mit *Was sie sagt*;
4. **Optionen:** die ernsthaft in Frage kommenden Ausprägungen, **jede mit dem
   kleinsten Fall und der Stelle, an der sie bricht**;
5. **Festlegung**;
6. **Auswahlgrund** – in der Regel ein Satz, weil die Begründung in den Optionen
   steht;
7. **Kosten** – Pflicht, wo die Wahl einen erkennbaren Preis hat;
8. **Beispiel:** der kleinste gültige Fall;
9. **Gegenbeispiel:** ein ähnlich aussehender Fall, für den die Regel nicht gilt.

**Ein Beispiel ist der kleinste gültige Fall.** Was mehr zeigt als nötig, ist
eine Erläuterung und gehört nach §9.

**Prüfmaßstab:** Wenn beim Lesen die Frage „wovon genau ist hier die Rede?“
entsteht, fehlt ein Beispiel.

```text
ohne   „Auffindbarkeit entsteht durch einheitliche Typisierung
        und filterbare Facetten.“
        → Wovon? Welche Facetten? Unterschied zur Suche?

mit    find(area = i18n, zustand = bereit)   →  {#4c19, #7b0d}
        volltext("fallback")                 →  61 Treffer
```

**Das gilt auch für Definitionen.** Eine Definitionstabelle ohne danebengestellten
Fall verlangt vom Leser, sich den Fall selbst auszudenken. Betroffen und
umgestellt sind §2, §7.2, §7.4 und §7.5.

**Abstrakte Zusammenfassungen ersetzen den Fall nicht.** Wörter wie *Invariante*,
*atomar*, *konsistent*, *bleibt gewahrt* oder *darf nicht umgangen werden* sind
nur zulässig, wenn daneben unmittelbar erkennbar ist, welcher konkrete Fall die
Regel erfüllt und welcher sie verletzt. Bei einer
Reihenfolgeregel werden die gültige und die ungültige Reihenfolge gezeigt.

```text
nicht ausreichend
  „Die Invariante gilt nach jedem abgeschlossenen Schritt.“

ausreichend
  Ausgang      E verworfen
               └─ T verworfen
  zulässig     erst E → in Klärung, danach T → in Klärung
  unzulässig   T → in Klärung, während E verworfen ist
```

**Regel gegen Scheinalternativen:** Eine Option zählt in Punkt 4 nur, wenn sie in
einer Quelle benannt ist oder wirklich erwogen wurde – **und wenn sich für sie
ein kleinster Fall und eine Bruchstelle angeben lassen.** Schwache Optionen zu
erfinden, damit die eigene Wahl zwingend aussieht, macht die Prüfung wertlos.
Die Regel schneidet in beide Richtungen: Eine ernsthafte Option wegzulassen ist
derselbe Fehler.

Die vollständige Form gilt für §4, §5 und §8.1. Die Tabellen in §3 und §6 führen
nur *Kontextquelle*, *Was sie sagt*, *Festlegung* und *Auswahlgrund*.

### A.2 Quellenklassen

| Klasse | Art | Tragfähigkeit |
|---|---|---|
| **A** | frei zugänglicher Volltext mit spezifizierendem Anspruch | Wortlaut prüfbar; darf zitiert werden |
| **B** | frei zugängliche Praxisliteratur | Wortlaut prüfbar; Erfahrungsaussage |
| **C** | Werkzeug- und Herstellerdokumentation | zeigt gelebte Praxis; keine Autorität |
| **D** | kostenpflichtige Normen und Rahmenwerke | **Wortlaut nicht geprüft**; nur Themenhinweis |

**Klasse D darf keine Aussage tragen** – und keinen Bruchfall.

**Der übliche Ausweg ist nicht der Aufstieg, sondern der Ersatz.**

```text
vorher   PMI, Practice Standard for WBS       Klasse D, trägt nichts
nachher  NASA WBS Handbook SP-20210023927     Klasse B, freier Volltext
         → dieselbe Regel im geprüften Wortlaut
         → dazu Kapitel 3.5 „Common Development Errors“
```

**Eine Quelle liefert nicht automatisch Bruchfälle.** Der Scrum Guide bezeichnet
sich als „purposely incomplete“ und ist beispielfrei.

### A.3 Herkunft von Bruchfällen

Gesucht wird in dieser Reihenfolge: **Quelle → Archiv-PM → Konstruktion.**

Eine Anfrage trägt **kein Kürzel**, sondern die Stelle, die sie belegt –
„Anfrage zu §7.13“, nicht „Anfrage FM“. Ein Kürzel bräuchte ein eigenes
Register; die Stelle steht ohnehin daneben (A.6).

| Marke | Bedeutung |
|---|---|
| `belegt: …` | Die Quelle beschreibt den Schaden selbst |
| `erlebt: …` | In einem wirklichen Ablauf vorgekommen |
| `konstruiert` | Ausgedacht, plausibel, nicht vorgekommen |
| `offen – Archiv-PM` | Benannte Frage an jemanden mit Zugang (§12.3) |

**Mock-Daten sind Darstellung, keine Herkunft.** Die Marke sagt, woher der
*Mechanismus* stammt; die Kleidung ist davon unabhängig.

**Ein konstruierter Bruchfall, für den sich kein plausibler Hergang erfinden
lässt, ist ein Befund über die Regel**, nicht über den Autor.

**Ausnahmen von der Bruchfallpflicht:**

| | Wo | Was stattdessen |
|---|---|---|
| **Definitionen** | §2, §7.2 | **Abgrenzungsbeispiel** – ein Fall, der darunterzufallen scheint |
| **Konfigurationswahlen** | `{de,en}` in P-005 | Marke **Eigenentscheidung ohne Quelle** |
| **Erwartungswerte** | §12.2, Punkt 7 | Marke **Erwartung** mit Begründung und Überprüfungsanlass |

### A.4 Zuständigkeit von Kontextquellen

Eine Quelle ist zuständig, wenn alle vier Bedingungen gelten:

1. **Geltungsbereich deckt die Frage.**
2. **Auflösungsgrad reicht.**

   ```text
   zuständig    RFC 5646 für P-005 – nennt Tags, Struktur, Beispiele
   unzuständig  Agiles Manifest für P-005 – sagt nichts über Sprachen
   unzuständig  Scrum Guide für P-001 – sagt nichts über Kennungen
   ```
3. **Autorität passt zur Verbindlichkeit.**
4. **Keine spezifischere Quelle vorhanden.**

**Zusammengesetzte Aufgaben werden vorher getrennt.**

**Die Suche darf abbrechen.** „Keine zuständige Quelle“ ist ein gültiges
Ergebnis und führt zur unbelegten Festlegung.

### A.5 Wortlautvorbehalt

Die Abschnitte *Was sie sagt* sind **Paraphrasen**, keine Zitate. Wörtliche
Zitate stehen in Anführungszeichen und stammen aus einem zugänglichen
Originaltext der Klassen A, B oder C. Wo eine Paraphrase noch nicht geprüft
ist, steht **(ungeprüft)** – der Stand ist in §12.2, Punkt 2 geführt.

*Zu Klasse C:* Herstellerdokumentation ist zitierfähig, wenn ihr Wortlaut
zugänglich und geprüft ist. Ihre Tragfähigkeit begrenzt bereits die Klasse
selbst (A.2): Sie zeigt gelebte Praxis, keine Autorität.

### A.6 Kennzeichen und Belegort

**Ohne eine Regel dazu** *(erlebt: §7.5 in Fassung 4, §12.2 in Fassung 6)*

```text
Fassung 4, §7.5:  Regeln 1–7, dann 10, dann 8 und 9.
                  Jemand hat eingefügt und nicht umsortiert.
```

**Der naheliegende Ausweg wurde geprüft und verworfen.** Ein Regelschlüssel
(`VORGANG-ABHAENGIGKEIT` statt „§7.6, Regel 12“) braucht ein eigenes Register:

```text
Schlüssel   Ist der Name vergeben? → nur beantwortbar, wenn jemand eine
            Liste aller Schlüssel führt → ein zweiter Bestand, von Hand

Nummer      Ist sie vergeben? → nachsehen. Die Gliederung ist die Liste.
```

Und P-001, Option (b2) gilt hier nicht:

```text
Vorgang         „der zweite“ sagt nichts über den Vorgang.
                Position ist zufällig → Nummer ist eine Lüge

Spezifikation   „§7.6, Regel 12“ sagt: Vorgangsvorlage, zwölfte Prüfregel.
                Position IST die Aussage → Nummer ist die Wahrheit
```

Ein Dokument hat eine rekursive Gliederung und kann sie gegen sich selbst
prüfen. Pages PM kann das nicht – dort liegen solche Listen in einem dynamischen
Feld und sind für Filter unsichtbar. Deshalb gelten dort andere Regeln.

**Festlegung**

```text
Kennzeichen     die Abschnitts- und Regelnummer
prüfbar         Nummerierung lückenlos und aufsteigend;
                jeder Verweis nennt eine existierende Stelle
nicht prüfbar   ob hinter der Nummer noch dieselbe Regel steht
                → Preis, klein, weil Spezifikation und Tests gemeinsam
                  versioniert sind
Umnummerieren   redaktionelle Änderung
```

**Belegort.** §10 nennt Abschnittsnummer und Ablauf von Hand. Eine berechnete
Abdeckung setzte einen Nachweisbegriff voraus, der feiner auflöst als jeder
Pages-PM-Gegenstand:

```text
Commit-Trailer   Pages-PM: #d5aa   → zeigt auf ein Objekt              ✓
Testbezug        eine Regel, und der Test prüft einen Fall davon
                 → feiner als jedes Objekt                             ✗
```

Sie ist deshalb kein Ziel dieser Spezifikation.

**Nicht jede Regel ist prüfbar, und das steht dabei.** Die Marke
**NICHT PRÜFBAR** tragen P-012 (eine Regel über Entscheidungen) und P-014 (eine
Regel über den Entwurf). Die Ziele Z1 bis Z8 sind keine Regeln.

### A.7 Normativität

Die Wörter folgen BCP 14 (RFC 2119 / RFC 8174), Klasse A.

| Begriff | Bedeutung | Umsetzung |
|---|---|---|
| **Muss** | Für den Produktzweck erforderlich. | Ohne Erfüllung fachlich nicht abgeschlossen. |
| **Soll** | Regelfall; Abweichung braucht einen begründeten Anlass. | Die Abweichung wird sichtbar begründet. |
| **Kann** | Optionale Fähigkeit. | Die Nutzung hängt vom Ablauf ab. |

In den Fachvorlagen bedeutet eine Pflichtangabe **Muss**.

**Eine Regel kann in beide Stufen zerfallen.** P-003 ist ein *Soll* – Bereiche
zu führen ist der Regelfall –, aber „Bereiche sind verwaltet“ ist ein *Muss*.
P-004 ist ein *Soll*, der Agenten-Zirkel ein *Muss*. Wo das vorkommt, steht die
Stufe an der einzelnen Regel, nicht nur in der Überschrift.

---

## Anhang B – Quellenregister

Nach Tragfähigkeit gegliedert (A.2).

### Klasse A – frei zugänglicher Volltext, spezifizierend

1. **BCP 14 / RFC 2119 und RFC 8174** – Schlüsselwörter für Anforderungsstufen.
   <https://www.rfc-editor.org/info/bcp14>
2. **RFC 5646 / BCP 47** – Sprachkennungen.
   <https://www.rfc-editor.org/rfc/rfc5646.html>
3. **W3C PROV-DM** – Provenienz-Datenmodell. <https://www.w3.org/TR/prov-dm/>
4. **Schwaber/Sutherland, Scrum Guide 2020**.
   <https://scrumguides.org/scrum-guide.html>
5. **RFC-Metadaten „Obsoletes“ / „Obsoleted by“** – Ablösepraxis der IETF.
6. **RFC 7807** – Problem Details for HTTP APIs. *(P-013)*
7. **DACS, Statement of Principles** – Provenienzprinzip; Abruf nach Herkunft.
   <https://saa-ts-dacs.github.io/dacs/04_statement_of_principles.html>
   *(P-006, Z5; Wortlaut geprüft 2026-07-27)*
8. **Open Guide to Kanban**, v2025.7 –
   <https://kanbanguides.org/open-guide-to-kanban/2025.7/>, Anpassung des
   *Kanban Guide* (Mai 2025) unter CC BY-SA 4.0. Die *Definition of
   Workflow* verlangt „one or more defined states that the Work Items Flow
   [through]“ und „a set of Explicit policies about how Work Items can Flow
   through each state“; sie wird fortlaufend überprüft: „Kanban system members
   often review the Definition of Workflow to discuss and adopt needed
   changes“, Änderungen „informed by evidence“. Eine Richtung oder Reihenfolge
   der Zustände gibt der Leitfaden nicht vor. *(§7.1.2; trägt, dass der
   Arbeitsfluss definiert und aufgrund empirischer Erkenntnisse
   weiterentwickelt wird, nicht eine bestimmte Pages-PM-Kante; Wortlaut geprüft
   2026-08-02)*

### Klasse B – frei zugängliche Praxisliteratur

9. **NASA Work Breakdown Structure Handbook**, NASA/SP-20210023927 –
   produktorientierte Zerlegung; Kapitel 3.5 „Common Development Errors“.
   *(P-002, P-003, Ablauf C; Wortlaut geprüft 2026-07-27)*
10. **Gotel/Finkelstein, „An Analysis of the Requirements Traceability
    Problem“** (ICRE 1994). *(Anhang C.1)*
11. **SAA, Dictionary of Archives Terminology**, *provenance*, *respect des
    fonds*. *(P-006)*
12. **Michael Nygard, „Documenting Architecture Decisions“**.
13. **MADR – Markdown Architectural Decision Records**. <https://adr.github.io/>
14. **Martin Fowler, „Yagni“**. <https://martinfowler.com/bliki/Yagni.html>
15. **Martin Fowler, „Event Sourcing“**.
16. **Martin Fowler, „Opportunistic Refactoring“**. *(§7.6.1, Regel 10)*
17. **Google SRE Book**, „Postmortem Culture“ und Incident Response.
18. **arc42 Template Overview**. <https://arc42.org/overview>
19. **Kubernetes Enhancement Proposals (KEP)**.
20. **PEP 1** – mit dem Pflichtabschnitt „Rejected Ideas“. *(Ablauf B)*
21. **Tim Berners-Lee, „Cool URIs don't change“** (W3C).
22. **Rosenfeld/Morville, *Information Architecture***.
23. **Kombinatorische Testpraxis** (NIST-Material).

### Klasse C – Werkzeug- und Herstellerdokumentation

24. **Jira-Verknüpfungstypen** – `blocks`, `duplicates`, `causes`, `relates to`.
25. **GitHub, schließende Schlüsselwörter** – „fixes #123“.
26. **AWS Systems Manager Automation**.
27. **Drift-Erkennung in Infrastructure-as-Code-Werkzeugen**.
28. **Unicode CLDR** und **Mozilla Fluent** – Sprach-Fallback.
29. **Atlassian Jira, Workflow-Dokumentation** – Übergänge zwischen Zuständen
    sind gerichtete, einzeln konfigurierbare Beziehungen: „Transitions are also
    *one-way*“; „To move a work item back and forth, you need two separate
    transitions“, angelegt über *From status* und *To status*.
    <https://support.atlassian.com/jira-cloud-administration/docs/create-workflow-transitions/>
    *(§7.1.2; zeigt, dass Rück- und Seitenwege ausdrückbar sind; begründet keine
    bestimmte Pages-PM-Kante; Wortlaut geprüft 2026-08-02)*
30. **OpenProject, Workflow-Dokumentation und Implementierung** – ein Workflow
    ist „the allowed transitions between work package status for a role and a
    type“; die Matrix ist gerichtet (Ausgangsstatus in den Zeilen, Zielstatus
    in den Spalten).
    <https://www.openproject.org/docs/system-admin-guide/manage-work-packages/work-package-workflows/>;
    Umsetzung: <https://github.com/opf/openproject>, `app/models/workflow.rb`
    mit `old_status`, `new_status`, `type` und `role`, Stand `079baeb`.
    *(§7.1.2; zeigt gerichtete Rück- und Seitenwege; die technische Matrix ist
    keine fachliche Soll-Matrix für Pages PM; Wortlaut geprüft 2026-08-02,
    Implementierung eingesehen)*

### Noch nicht eingeordnet

- **Poka-yoke** aus der Fertigungspraxis (P-013). Es gibt keinen frei geprüften
  Text; P-013 ruht allein auf RFC 7807, und Poka-yoke ist ein Themenhinweis.

### Klasse D – kostenpflichtig, Wortlaut nicht geprüft

Diese Quellen dürfen **keine Aussage und keinen Bruchfall tragen**.

28. **ISO 21500:2021** · 29. **ISO 21502:2020** · 30. **ISO 10006:2017** ·
31. **ISO 21511:2018** · 32. **ISO 10007:2017** ·
33. **ISO/IEC/IEEE 29119** *(Testfallstruktur, §7.14)* ·
34. **PMI, Practice Standard for Work Breakdown Structures** *(trägt seit
    Fassung 5 nichts mehr)* · 35. **ITIL 4, Change Enablement**

---

## Anhang C – Geprüfte, nicht angenommene Facharten

**Status: nicht angenommen.** Dieser Anhang dokumentiert verworfene
Produktmöglichkeiten. **Seine Beispiele beschreiben ausdrücklich nicht das
Verhalten der ersten Fassung.**

Warum getrennt: Eine Vorlage, die zwischen den gebauten Arten steht, wird
gelesen wie eine gebaute. §7 enthält deshalb nur, was gebaut wird.

### C.1 Prüfnachweis

*Prüffrage (§6.2): Welche Schnittstelle erzeugt einen Nachweis, ohne zu rauschen
und ohne zweiten Bestand?*

**Ohne diese Regel** *(belegt: Gotel/Finkelstein 1994 – die Frage „woher kommt diese Anforderung, und wer hat sie beurteilt?“ ist regelmäßig unbeantwortbar, weil nur das Ergebnis festgehalten wird)*

```text
Häkchen am Kriterium:   #9e2b / K2   erfüllt ✓
  Wer? Wann? Woran? Schon einmal durchgefallen?   unbekannt
```

**Zweck:** Die Erfüllung genau eines benannten Kriteriums feststellen.

**Kontextquelle:** Gotel/Finkelstein 1994; NASA WBS Handbook 3.3.3
(Kreuzreferenzmatrix).
*Was sie sagt:* Die Nachverfolgbarkeit zerfällt in zwei Probleme – den Weg *zur*
Anforderung hin und den Weg *von* ihr weg. Die Kreuzreferenzmatrix zeigt entlang
der Achse sofort die Elemente ohne zugehörige Anforderung.

**Festlegung (verworfen):** Ein Prüfnachweis verweist mit einer Kante auf den
Gegenstand, nennt den Kriterienschlüssel in einem Feld und trägt Ergebnis,
Zeitpunkt und Belegort.

> **Nicht angenommen.** Zwei Gründe, beide gegen P-012:
>
> **Kein bestimmbarer Entstehungsanlass.** Automatisch je Testlauf erzeugt
> Rauschen. Von Hand erzeugt zwei ungekoppelte Bestände und damit die
> Doppelpflege aus §3.2. Der Beleg entsteht ohnehin an einer **Schnittstelle**.
>
> **Er bricht die Auflösungsgrenze.** Sein Existenzgrund ist ein
> **Feldschlüssel**. Damit wäre jede Zeile jeder Punktfolge nachweisfähig. Wo
> das aufhört, ist nicht bestimmbar; der Nachweis definiert seine eigenen Ziele.
>
> **Was ohne ihn gilt:** §7.6, Regel 1 und Regel 15 – die Auflösung entsteht
> durch kleinere Vorgänge, nicht durch feinere Gegenstände.

| Angabe | Art | Pflicht ab |
|---|---|---|
| geprüftes Objekt | Verweis | Anlage |
| Kriterienschlüssel | Kurzwert | Anlage |
| Ergebnis | Kurzwert: *bestanden*, *nicht bestanden*, *blockiert*, *nicht anwendbar* | Anlage |
| Prüfzeitpunkt, Belegort | Zeitpunkt / Fachtext | Anlage |
| Umgebung, Notiz | Kurzwert / Fachtext | – (optional) |

**Prüfregeln (verworfen):** Ein Kriterium gilt als erfüllt, wenn der jüngste
Prüfnachweis *bestanden* trägt. Frühere bleiben lesbar. *nicht anwendbar*
verlangt eine Notiz.

**Gegenbeispiel:** Ein Testlauf ist kein Prüfnachweis, sondern sein Beleg.

### C.2 Arbeitsdokumentation

*Prüffrage (§6.2): Gibt es einen Arbeitszusammenhang über mehrere Systeme,
dessen Stand weder aus Commits noch aus dem Zustandsverlauf ablesbar ist?*

**Zweck:** Ziel, Stand, Prüfplan und Abschluss eines Arbeitszusammenhangs an
einer Stelle halten.

**Kontextquelle:** Praxis fortlaufend gepflegter Arbeitsdokumente;
Importer-Praxis.

> **Nicht angenommen.** Ihre vier Angaben haben jeweils einen anderen Ort:
>
> ```text
> Ziel        → §7.6 Beschreibung: „Anlass und gewünschtes Ergebnis“
> Prüfplan    → §7.14 Testmatrix
> Stand       → Commits und Zustandsverlauf (P-010); §3.2 verbietet,
>               Git zu kopieren
> Herkunft    → P-006, Nebenfolge an jedem Gegenstand
> ```
>
> Damit bleibt kein eigener Zweck (P-012). Für den Import genügt ein **Vorgang**
> im Zustand *Eingang* mit Herkunft – er landet dort, wo er hingehört:
> ungesichtet, mit sichtbarem Eingangsalter.

| Angabe | Art | Pflicht ab |
|---|---|---|
| Zustand | Kurzwert: *aktiv*, *blockiert*, *abgeschlossen*, *aufgegeben* | Anlage |
| Ziel, Aktueller Stand | Fachtext | Anlage |
| Abschlusszusammenfassung | Fachtext | abgeschlossen |
| Bezogener Vorgang, Prüfplan, Verweise | Verweis / Fachtext / Punktfolge | – (optional) |

**Gegenbeispiel:** Eine Arbeitsdokumentation ist kein Postmortem.

---

## Anhang D – Marktprüfung

**Geprüft am 27. Juli 2026.** Dies ist keine Marktanalyse mit Anspruch auf
Vollständigkeit, sondern eine Prüfung benannter Kandidaten zu einem benannten
Datum, gestützt auf Herstellerdokumentation, nicht auf eigenen Betrieb.

### D.1 Prüfkriterien

```text
Abfragbares Fachmodell     Liest ein Agent den Bestand in einer Abfrage
                           oder über eine HTTP-Schnittstelle?
Dokumentarten mit Zustand  Sind Richtlinie, ADR, Runbook eigene Arten mit
                           Zustand, Pflege und Ablösung – oder Wiki-Text?
Geprüfte Beziehungen       Ist eine falsche Kante ein Fehler oder eine Meinung?
Äußere Adressierbarkeit    Kann ein Commit einen Gegenstand nennen, ohne das
                           Werkzeug zu öffnen? Bleibt der Verweis nach einer
                           Umbenennung gültig?
Regelbezug                 Kann auf eine einzelne Regel verwiesen werden
                           statt auf ein Dokument?
Betriebsaufwand            Was kostet der Betrieb für ein bis fünf Personen?
```

### D.2 Neun geprüfte Werkzeuge

| Werkzeug | Was es kann | Warum es hier nicht trägt |
|---|---|---|
| **git-bug** | Vorgänge als Git-Objekte, offline, verteilt, kein Server | Am nächsten am Gedanken „Daten liegen beim Repository“. Aber: flaches Vorgangsmodell, keine Dokumentarten, keine typisierten Beziehungen, keine Abfragesprache. |
| **Fossil** | Versionsverwaltung mit Ticketsystem, Wiki, Forum – alles in **einer SQLite-Datei** | Technisch der nächste Verwandte: der Bestand *ist* eine abfragbare Datenbank. Aber das Ticketschema ist auf Ticket plus Kommentare ausgelegt, und Fossil bringt die Versionsverwaltung mit, die hier nicht ersetzt werden soll. |
| **Plane** | Community Edition (AGPL-3.0), Work Items, Cycles, Modules, Abhängigkeiten, REST-API, Selbsthosting | Deckt §7.5 und §7.6 heute vollständig ab. Der Unterschied liegt woanders: Pages (das Wiki) ist Freitext ohne Zustand, ohne Pflegeverantwortung, ohne Ablösung und ohne prüfbare Verbindung zur Arbeit. Damit derselbe Fall wie Jira + Confluence, nur in einem Werkzeug. |
| **Taiga** | Scrum-nativ: Backlog, Sprints, Epics, Untervorgänge, Burndown | Fachlich nah an §7.5/§7.6. Aber Kaleidos hat den Betrieb eingestellt; der Nachfolger Tenzu ist von Funktionsgleichheit weit entfernt. |
| **Redmine** | Lange stabil, Unterprojekte, konfigurierbare Tracker, große Plugin-Landschaft | Unterprojekte und Rollen decken P-002 und P-004 gut ab. Facharten müssten als Tracker-Konfiguration nachgebaut werden; geprüfte Kanten gibt es nicht. |
| **OpenProject** | Work Packages, Gantt, Rollen, Selbsthosting | Auf Governance ausgelegt, nicht auf Abfragbarkeit; mehrere Planungsfunktionen sind kostenpflichtig. |
| **GitLab Issues** | Issues, Epics, Meilensteine, Abhängigkeiten, dicht am Code | Setzt eine GitLab-Instanz voraus – genau der Betriebsaufwand, den §0.2 vermeiden will. |
| **Tuleap** | ALM mit agiler Planung und Nachverfolgbarkeit | Für größere Entwicklungsorganisationen gebaut; Formalitätsniveau widerspricht Z8. |
| **Trac** | Minimalistisch, Wiki plus Vorgänge | Keine Boards, keine Sprints, keine Auswertung. Zu wenig für §7.5. |

**Wie die neun mit Dokumentation umgehen:**

```text
Wiki neben dem Tracker, Freitext, ohne Zustand und ohne Beziehung:
    Plane · Taiga · Redmine · OpenProject · GitLab · Trac · Tuleap · Fossil

Typisierte Dokumentarten mit eigenem Zustand, eigener Pflege
und geprüften Beziehungen, unabhängig vom Vorgang:
    keines der neun

git-bug hat gar kein Dokumentmodell – nur Vorgänge.
```

### D.3 Was daraus folgt

```text
1  Der Entwurfsgrund bleibt bestehen.
   Kein geprüftes Werkzeug legt sein Fachmodell als abfragbares Schema
   offen. Fossil ist die Ausnahme, hat aber kein Fachmodell für §6.

2  Der stärkste Unterschied ist nicht der Tracker, sondern das
   Vorlagensystem. Alle neun trennen „Arbeit“ von „was gilt“.
   Das ist auch der Teil, der am meisten Erfassungsaufwand kostet.

3  Der Entwurfsgrund ist schwächer als früher behauptet.
   Wer nur Sprints und Vorgänge braucht, sollte Plane nehmen.
```

### D.4 Offen: die Prüfung ist an der falschen Menge erfolgt

Geprüft wurden neun **Tracker**. Der wirkliche Vergleichsfall in kleinen Teams
ist ein **Paar**:

```text
Jira + Confluence                       der Regelfall in kleinen Firmen
GitHub Issues + Wiki + ADR-Dateien      der Regelfall in Repositories
Linear + Notion
Backstage / TechDocs                    Dokumentation neben dem Dienstkatalog
```

Solange diese vier nicht an denselben sechs Kriterien geprüft sind – besonders
an **äußerer Adressierbarkeit** und **Regelbezug** –, trägt der Satz „die
Verbindung gibt es nirgends“ nicht. Die Wiederholung steht in §12.2, Punkt 1.
