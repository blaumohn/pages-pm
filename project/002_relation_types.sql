-- Pages-PM-spezifische Projektkonfiguration, keine Schema-Migration.
-- Muss nach migrations/006_relation_types.sql laufen und wird als migrator
-- ausgeführt. Die nötigen Rechte werden dort unmittelbar auf
-- pm.relation_types vergeben.
--
-- Anfänglicher Satz bewusst klein gehalten: derived_from, implements,
-- references, depends_on. "assigned_to" und "documents" sind ausdrücklich
-- NICHT hier vertreten — assigned_to ist keine allgemeine Objektbeziehung,
-- sondern gehört in das Verantwortungsmodell der jeweiligen Fachart;
-- "documents" ist zu mehrdeutig und wird erst bei einem echten
-- Anwendungsfall präzisiert.
--
-- depends_on: Reihenfolge zwischen Vorgängen (§8.1), installationsweit
-- zyklenfrei, auch über Projektgrenzen hinweg, weil die Zyklenprüfung in
-- 007_object_relations.sql je Beziehungsart über die gesamte
-- pm.object_relations läuft, ohne nach Projekt einzuschränken. Ihre
-- Endpunktregel (issue -> issue) wird erst mit der Vorgangsmigration
-- eingetragen, weil die Objektart issue hier noch nicht existiert; ohne
-- Endpunktzeile ist depends_on bis dahin für keine Kombination verwendbar
-- (007_object_relations.sql, pm.enforce_object_relation_rules).
--
-- Keine allgemeine Beziehungsart "supersedes": Eindeutige Ersetzungen
-- (z. B. bei ADRs) werden durch einen unmittelbaren Fremdschlüssel wie
-- superseded_by_id in der jeweiligen Fachtabelle abgebildet, nicht durch eine
-- typübergreifende Beziehungsart. Das Beziehungsfundament unterstützt
-- zyklusfreie, beschreibungspflichtige Beziehungsarten unabhängig davon
-- weiterhin.
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
        'references',
        '{"de": "verweist auf", "en": "references"}'::jsonb,
        '{
            "de": "Das Quellobjekt verweist informativ auf das Zielobjekt, ohne eine stärkere fachliche Aussage. Diese Beziehungsart darf nur verwendet werden, wenn keine genauere Beziehungsart passt.",
            "en": "The source object informatively references the target object without making a stronger claim. Use this relation type only when no more specific relation type applies."
        }'::jsonb,
        true, false
    ),
    (
        'depends_on',
        '{"de": "wartet auf", "en": "depends on"}'::jsonb,
        '{
            "de": "Das Quellobjekt darf grundsätzlich erst nach Abschluss des Zielobjekts nach \"in Arbeit\" wechseln. Die Abhängigkeit setzt selbst keinen Zustand und kann mit einem festgehaltenen Grund übergangen werden.",
            "en": "The source object may normally transition to \"in progress\" only after the target object is completed. The dependency does not set any state itself and may be overridden with a recorded reason."
        }'::jsonb,
        false, true
    );
