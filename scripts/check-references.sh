#!/bin/sh
# Verweisprüfer für die Produktspezifikation und die sie zitierenden Dateien.
#
# Umnummerierung und Verschiebung von Abschnitten sollen kein Vorgang sein,
# der von sorgfältigem Lesen abhängt. Dieses Skript stellt jeden Verweis
# gegen sein tatsächliches Ziel.
#
# Zwei Stufen:
#   FEHLER   Der Verweis zeigt ins Leere oder eine Kennung ist mehrfach
#            bzw. gar nicht definiert. Rückgabewert 1.
#   HINWEIS  Der Verweis ist auflösbar, aber positionsabhängig
#            ("§7.6, Regel 20"): Er bricht still, sobald eine Regel davor
#            eingefügt oder entfernt wird. Bricht den Lauf noch nicht — die
#            stabilen Regelschlüssel kommen als eigener Arbeitsschritt.
#
# Aufruf:  scripts/check-references.sh [--strict]
#   --strict  lässt auch HINWEIS den Rückgabewert auf 1 setzen.

set -eu

cd "$(dirname "$0")/.."

SPEC=product_spec.md
STRICT=0
[ "${1:-}" = "--strict" ] && STRICT=1

# Geprüfte Dateien. Eine fehlende Quelle wird gemeldet und bricht den Lauf:
# Ein Prüfer, der stillschweigend weniger prüft, meldet grundlos "sauber".
for required in "$SPEC" README.md README.en.md migrations tests; do
    if [ ! -e "$required" ]; then
        echo "check-references: $required fehlt" >&2
        exit 2
    fi
done

FILES=$(
    echo "$SPEC"
    echo README.md
    echo README.en.md
    find migrations tests -name '*.sql'
)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------
# 1. Ziele aus product_spec.md erheben.
#
#    sections   §-Nummern:            0  0.1  7.6  7.6.1
#    appendix   Anhänge:              Anhang A   Anhang A.1
#    rules      Kennungen P-0NN, ZN, je Fundzeile (Mehrfachdefinition
#               soll auffallen, nicht stillschweigend zusammenfallen)
#    anchors    Markdown-Anker je Datei
# ---------------------------------------------------------------------

# $2 ist die Nummer selbst ("7.6", "0."); nur ein abschließender Punkt der
# Zählweise "## 0. Vorhang" fällt weg, nicht der Punkt innerhalb von "7.6".
awk '
    /^#{2,4} [0-9]/ {
        n = $2
        sub(/\.$/, "", n)
        print n
    }
' "$SPEC" | sort -u > "$WORK/sections"

awk '
    /^## Anhang [A-Z]/ { current = $3; print "Anhang " current; next }
    /^#{3,4} [A-Z]\.[0-9]/ {
        n = $2
        sub(/\.$/, "", n)
        if (current != "" && substr(n, 1, 1) == current)
            print "Anhang " n
    }
' "$SPEC" | sort -u > "$WORK/appendix"

# Kennungen: Definitionsstellen. P-0NN als eigene Überschrift, ZN als
# fettgesetzter Kopf einer Tabellenzeile im Zielabschnitt.
{
    grep -nE '^### P-[0-9]{3} ' "$SPEC" \
        | sed -E 's/^([0-9]+):### (P-[0-9]{3}).*/\2 \1/'
    grep -nE '^\| \*\*Z[0-9]+ ' "$SPEC" \
        | sed -E 's/^([0-9]+):\| \*\*(Z[0-9]+).*/\2 \1/'
} | sort > "$WORK/keys"

# Anker je geprüfter Markdown-Datei, nach der GitHub-Regel: Kleinschreibung,
# Satzzeichen entfernt, Leerraum zu Bindestrich. Umlaute bleiben erhalten.
for f in "$SPEC" README.md README.en.md; do
    # SC1112: die typografischen Anführungszeichen stehen in einer awk-
    # Zeichenklasse, nicht in Shell-Code. GitHub entfernt sie aus Ankern;
    # ohne sie erzeugte eine Überschrift mit „…“ einen Falschbefund.
    # shellcheck disable=SC1112
    awk -v file="$f" '
        /^#{1,6} / {
            t = $0
            sub(/^#+ +/, "", t)
            gsub(/\*|`|_/, "", t)                 # Auszeichnung
            gsub(/–|—/, "", t)                    # Gedankenstriche
            gsub(/[.,:;!?()\[\]{}"§\047„“”‚‘’…\/]/, "", t)
            # tolower() erfasst nur ASCII; die deutschen Großumlaute müssen
            # eigens abgebildet werden, sonst zerfällt jeder Anker mit Umlaut.
            gsub(/Ä/, "ä", t); gsub(/Ö/, "ö", t); gsub(/Ü/, "ü", t)
            t = tolower(t)
            # Jedes Leerzeichen wird ein Bindestrich, auch mehrere in Folge:
            # aus "F – Import" wird "f--import", nicht "f-import".
            gsub(/ /, "-", t)
            sub(/^-+/, "", t); sub(/-+$/, "", t)
            print file "#" t
        }
    ' "$f"
done | sort -u > "$WORK/anchors"

# ---------------------------------------------------------------------
# 2. Verweise prüfen.
# ---------------------------------------------------------------------

: > "$WORK/errors"
: > "$WORK/notes"

report() {  # stufe datei zeile verweis fehlerart
    printf '%s\t%s:%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" \
        >> "$WORK/$([ "$1" = FEHLER ] && echo errors || echo notes)"
}

for f in $FILES; do
    # --- §-Verweise ---
    grep -noE '§ ?[0-9]+(\.[0-9]+)*' "$f" | while IFS=: read -r ln ref; do
        num=$(printf '%s' "$ref" | sed -E 's/^§ ?//')
        grep -qxF "$num" "$WORK/sections" \
            || report FEHLER "$f" "$ln" "$ref" "Abschnitt existiert nicht"
    done

    # --- Anhangverweise ---
    grep -noE 'Anhang [A-Z](\.[0-9]+)*' "$f" | while IFS=: read -r ln ref; do
        grep -qxF "$ref" "$WORK/appendix" \
            || report FEHLER "$f" "$ln" "$ref" "Anhang existiert nicht"
    done

    # --- Kennungen P-0NN / ZN ---
    grep -noE '\bP-[0-9]{3}\b|\bZ[0-9]+\b' "$f" | while IFS=: read -r ln ref; do
        count=$(awk -v k="$ref" '$1 == k' "$WORK/keys" | wc -l | tr -d ' ')
        case "$count" in
            0) report FEHLER "$f" "$ln" "$ref" "Kennung nirgends definiert" ;;
            1) ;;
            *) report FEHLER "$f" "$ln" "$ref" "Kennung $count-mal definiert" ;;
        esac
    done

    # --- Anker: datei.md#slug und dateiinterne #slug ---
    grep -noE '\]\(([A-Za-z0-9_.-]+\.md)?#[^)]+\)' "$f" \
        | while IFS=: read -r ln ref; do
        target=$(printf '%s' "$ref" | sed -E 's/^\]\(//; s/\)$//')
        case "$target" in
            '#'*) target="$f$target" ;;
        esac
        grep -qxF "$target" "$WORK/anchors" \
            || report FEHLER "$f" "$ln" "$target" "Anker existiert nicht"
    done

    # --- fragile Positionsverweise ---
    grep -noE 'Regeln? [0-9]+' "$f" | while IFS=: read -r ln ref; do
        report HINWEIS "$f" "$ln" "$ref" "fragiler Positionsverweis"
    done
done

# Eine Lücke in der Kennungsfolge (P-001, P-002, …) wird ausdrücklich NICHT
# geprüft. Stabile Kennungen sind Identität, keine Zählung: Wird eine Regel
# entfernt, muss ihre Kennung frei bleiben. Eine Lückenprüfung erzeugte
# genau den Druck, den stabile Kennungen vermeiden sollen — nachrücken oder
# eine alte Kennung erneut vergeben.

# ---------------------------------------------------------------------
# 3. Ausgabe.
# ---------------------------------------------------------------------

n_err=$(wc -l < "$WORK/errors" | tr -d ' ')
n_note=$(wc -l < "$WORK/notes" | tr -d ' ')

if [ "$n_err" -gt 0 ]; then
    echo "FEHLER ($n_err):"
    sort -u "$WORK/errors" | cut -f2- | sed 's/^/  /'
fi

if [ "$n_note" -gt 0 ]; then
    [ "$n_err" -gt 0 ] && echo
    echo "HINWEIS ($n_note fragile Positionsverweise, $(cut -f2 "$WORK/notes" | cut -d: -f1 | sort -u | wc -l | tr -d ' ') Dateien):"
    cut -f2 "$WORK/notes" | cut -d: -f1 | sort | uniq -c | sort -rn | sed 's/^/  /'
    echo "  (vollständig mit: scripts/check-references.sh --strict)"
fi

if [ "$STRICT" -eq 1 ] && [ "$n_note" -gt 0 ]; then
    echo
    echo "Fragile Positionsverweise im Einzelnen:"
    sort -u "$WORK/notes" | cut -f2- | sed 's/^/  /'
fi

if [ "$n_err" -eq 0 ] && [ "$n_note" -eq 0 ]; then
    echo "check-references: alle Verweise auflösbar."
fi

[ "$n_err" -gt 0 ] && exit 1
[ "$STRICT" -eq 1 ] && [ "$n_note" -gt 0 ] && exit 1
exit 0
