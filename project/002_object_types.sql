-- Pages-PM-spezifische Projektkonfiguration, keine Schema-Migration.
-- Muss nach migrations/003_object_registry.sql laufen und wird als migrator
-- ausgeführt. Die nötigen Rechte werden dort unmittelbar auf
-- pm.object_types vergeben.
--
-- Seedet die für Pages PM vorgesehenen Objektarten. table_name bleibt
-- zunächst NULL, da die zugehörigen Fachtabellen noch nicht existieren
-- (Phase B). Erst wenn die jeweilige Fachtabellen-Migration table_name auf
-- die eigene Tabelle setzt, können sich deren Zeilen über
-- pm.register_object() registrieren.
--
-- Künstliche, ausschließlich für Tests verwendete Objektarten wie "widget"
-- gehören nicht hierher. Sie werden nur innerhalb der jeweiligen Testdatei
-- angelegt.

INSERT INTO pm.object_types (key, table_name) VALUES
    ('sprint',             NULL),
    ('issue',              NULL),
    ('adr',                NULL),
    ('drift_report',       NULL),
    ('feature_matrix',     NULL),
    ('jira_work_document', NULL),
    ('kep_lite',           NULL),
    ('postmortem',         NULL),
    ('policy',             NULL),
    ('runbook',            NULL),
    ('flow_spec',          NULL),
    ('system_spec',        NULL),
    ('test_matrix',        NULL);
