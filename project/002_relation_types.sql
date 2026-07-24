-- Pages-PM-spezifische Projektkonfiguration, keine Schema-Migration.
-- Muss nach migrations/006_relation_types.sql laufen und wird als migrator
-- ausgeführt. Die nötigen Rechte werden dort unmittelbar auf
-- pm.relation_types vergeben.
--
-- Anfänglicher Satz bewusst klein gehalten: derived_from, implements,
-- supersedes, references. "assigned_to" und "documents" sind ausdrücklich
-- NICHT hier vertreten — assigned_to gehört als klarer Fremdschlüssel in die
-- jeweilige Fachtabelle (z. B. pm.issues.sprint_id), "documents" ist zu
-- mehrdeutig und wird erst bei einem echten Anwendungsfall präzisiert.
--
-- Richtung von derived_from: Quellobjekt → Zielobjekt bedeutet "Quellobjekt
-- wurde fachlich aus Zielobjekt abgeleitet" (Beispiel: KEP-lite
-- --derived_from--> Vorgang, der Vorgang ist die Grundlage, das KEP-lite das
-- daraus abgeleitete Objekt).
--
-- Endpunktregeln (pm.relation_type_endpoints) werden hier bewusst NICHT
-- gesetzt: Sie hängen von konkreten Fachtabellen ab, die in diesem Stand
-- noch nicht existieren, und werden zusammen mit der jeweiligen
-- Fachtabellen-Migration ergänzt (Phase B).

INSERT INTO pm.relation_types (
    key,
    title,
    description,
    description_required,
    acyclic
) VALUES
    (
        'derived_from',
        '{"de": "abgeleitet von", "en": "derived from"}'::jsonb,
        '{
            "de": "Das Quellobjekt wurde fachlich aus dem Zielobjekt abgeleitet.",
            "en": "The source object was derived from the target object."
        }'::jsonb,
        false, true
    ),
    (
        'implements',
        '{"de": "setzt um", "en": "implements"}'::jsonb,
        '{
            "de": "Das Quellobjekt setzt Anforderungen oder Entscheidungen des Zielobjekts um.",
            "en": "The source object implements requirements or decisions of the target object."
        }'::jsonb,
        false, false
    ),
    (
        'supersedes',
        '{"de": "ersetzt", "en": "supersedes"}'::jsonb,
        '{
            "de": "Das Quellobjekt ersetzt das Zielobjekt fachlich.",
            "en": "The source object supersedes the target object."
        }'::jsonb,
        true, true
    ),
    (
        'references',
        '{"de": "verweist auf", "en": "references"}'::jsonb,
        '{
            "de": "Das Quellobjekt verweist informativ auf das Zielobjekt, ohne eine stärkere fachliche Aussage. Diese Beziehungsart darf nur verwendet werden, wenn keine genauere Beziehungsart passt.",
            "en": "The source object informatively references the target object without making a stronger claim. Use this relation type only when no more specific relation type applies."
        }'::jsonb,
        true, false
    );
