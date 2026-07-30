<p align="right"><a href="README.md">Deutsch</a> | English</p>

---

# Pages PM

A tested PostgreSQL foundation for repository-oriented project management.

## Status

The tested relational foundation for languages, object registration, areas,
external migration provenance, typed relations, project membership, short
IDs, and states for projects and areas is implemented on top of the final
registry model. Also implemented is the shared foundation for the state
history.

The next operational milestone is managing Pages PM's own development:
issues and the immediately needed document templates will be implemented as
domain tables and used with real project data.

A small Python renderer follows, producing deterministic Markdown output for
GitHub Pages.

Sprint remains part of the full expression scope but is not part of the
first go-live. It will be implemented once a real sprint period needs to be
planned, tracked, and evaluated.

PostgREST, a web UI, and a general write API are not part of the MVP.

## Motivation

Pages PM represents project management data in validated PostgreSQL domain
tables. Every domain object type has its own domain table with explicit
columns, constraints, and domain rules. Shared relations, areas, and
migration provenance use an automatically maintained object registry.
Historical content is only normalized on demand; PostgreSQL remains the
authoritative data source.

The authoritative product specification lives in
[`product_spec.md`](product_spec.md). This README describes the current
technical state, the repository layout, and the path to implementation.

### Example

Suppose Pages PM manages this issue:

```text
Issue 42
Title: Build the GitHub Pages renderer
Sprint: 3
Area: publishing
Prior source: Jira PAGES-42
```

The full issue data lives in `pm.issues`. Inserting it automatically creates
a registry row:

```text
UUID:       018f…42
Object type: issue
```

`pm.object_registry` therefore holds neither the title nor the status of the
issue — only its shared identifier and object type.

The sprint assignment lives directly in `pm.issues.sprint_id`. The
`publishing` area is assigned via `pm.object_areas` — issue 42 could also
belong to `build`, but not twice to `publishing`. The prior Jira unit
`PAGES-42` is recorded as provenance in `pm.object_origins` and may not also
be assigned to another internal object.

Independent of issue 42, `pm.object_relations` could store this relation:

```text
ADR 5 --derived_from--> KEP-lite 2
```

The reverse edge `KEP-lite 2 --derived_from--> ADR 5` would be rejected
because, together with the first edge, it would form a cycle.

Sprint, issue, ADR, and KEP-lite do not yet exist in the current state (see
"Current scope"); the example describes the intended interplay.

## Terminology

Three distinct operations share related but different names:

### Schema migration

Changes the reusable database schema and its rules (`migrations/`).

**Example:** A future migration introduces `pm.issues`. Afterwards, an issue
with title, state, project membership, and completion criteria can be
created; PostgreSQL enforces the domain rules defined for it.

### Project configuration

Registers the concrete languages, relation types, and initial project
structure of this Pages PM installation (`project/`). Object types instead
arise atomically in the schema migration of their respective domain table.

**Example:** `project/001_languages.sql` sets `de` and `en` as required
languages. A title with only `{"de": "Veröffentlichung"}` is therefore
rejected; a title with `{"de": "Veröffentlichung", "en": "Publication"}` is
accepted.

### Content migration / import

Normalizes an external archive unit into an internal object
(`pm.object_origins`).

**Example:** The prior Jira issue `PAGES-42` and the supplementary archive
file `notes/renderer.md` are assigned to the same Pages PM issue as two
separate provenance rows. `PAGES-42` may not then be assigned to a second
internal object.

## Current scope

| Migration | Purpose |
|---|---|
| `001_bootstrap.sql` | Roles (`schema_owner`, `migrator`, `editor`, `reader`), schemas, migration tracking table |
| `002_languages.sql` | Language configuration + central language-map validation |
| `003_object_registry.sql` | Object types (`pm.object_types`), technical registry (`pm.object_registry`), registration functions |
| `004_areas.sql` | Managed classification areas, multi-assignment |
| `005_object_origins.sql` | Mapping of multiple external archive units to one normalized object |
| `006_relation_types.sql` | Relation type definitions + allowed endpoint combinations |
| `007_object_relations.sql` | Validated typed relations between objects (cardinality, cycles, descriptions) |
| `008_common_field_functions.sql` | Shared helper functions for upcoming domain tables, e.g. minimum lengths for required texts and automatic `updated_at` timestamps |
| `009_projects.sql` | Project hierarchy (`pm.projects`) and project membership per domain object (`pm.object_projects`) |
| `010_short_ids.sql` | Short IDs (§7.4): a directory not reassignable under normal operation, automatic assignment on registration, and exact resolution |
| `011_project_area_state.sql` | State for projects and areas, plus scope mode for projects (§7.4); blocks new assignments to closed projects |
| `012_state_history.sql` | Shared, append-only-in-effect foundation for the state history per P-010 across all registered domain objects |

`project/` supplements this concrete Pages PM installation with languages,
relation types, and the initial project structure (see "Terminology" above).
Object types arise atomically in the schema migration of their respective
domain table.

Not yet implemented: domain tables (issue, and the first needed document
template), the atomic recording of their state changes in the state
history, the shared `pm.objects` view, and the Python renderer. A general
write API, PostgREST, and a UI are planned for a later expansion.

## Architecture

```
PostgreSQL
├── domain tables are the authoritative objects (not yet implemented)
│   ├── pm.issues
│   ├── pm.kep_lites
│   └── further templates
├── pm.object_registry
│   └── automatically maintained shared UUID and type registration
├── shared foundations
│   ├── languages
│   ├── projects and project membership
│   ├── areas
│   ├── short IDs
│   ├── migration provenance
│   ├── typed relations
│   ├── states for projects and areas
│   └── foundation for the state history
└── pm.objects (not yet implemented)
    └── shared read view across the domain tables

Editing
├── editor uses direct, role-scoped SQL
├── multi-part operations run in a single transaction
└── constraints, foreign keys, and triggers enforce integrity

Publication (not yet implemented)
└── Python renderer connects as reader and generates Markdown for GitHub Pages
```

For example, `editor` may create issue 42 and change its title. The
resulting entry in `pm.object_registry` is created automatically by the
domain table's registration trigger. `editor` may not, however, create a
registry entry or a new object type directly.

The initial implementation uses PostgreSQL as the authoritative store.
A later repository-backed mode may use canonical text data as the durable
source and PostgreSQL as its validation and query projection.

Migrations are not auto-applied in the current operating model. They are
versioned SQL files applied by `migrator` after review. The disposable test
database uses `scripts/test-sql.sh` to apply them automatically.

## Run the tests

Requires Docker.

```sh
./scripts/test-sql.sh
```

Builds a disposable PostgreSQL 18 + pgTAP container, applies all migrations
in order, runs the pgTAP test suite, and tears everything down afterwards.

The tests, among other things, create two synthetic domain objects, register
them automatically in the object registry, assign one of them to an area and
an external provenance, and connect both via a typed relation. As long as
the provenance or relation exists, PostgreSQL rejects deletion.

## Repository structure

```
product_spec.md   authoritative product specification
migrations/       versioned SQL migrations (001_bootstrap.sql, 002_..., ...)
project/          Pages PM-specific project configuration (languages, relation types, project structure)
tests/sql/        pgTAP tests grouped by the migration or subsystem they cover
docker/           test-only Postgres+pgTAP image
scripts/          test-sql.sh (automated test run)
compose.yaml      local development database
compose.test.yaml disposable test database
```

## Roadmap

The selected domain types (sprint, issue, KEP-lite, ADR, system spec,
process spec, policy, runbook, postmortem, drift report, feature matrix,
test matrix, and Jira work log) are not an optional later expansion but the
defined domain expression scope of Pages PM. Each type takes on its own role
in the workflow; implementing all of them is a firm part of Phase B, even
though when each one is actually used depends on need.

### First operational core

1. Implement issue and a first document template.
2. Introduce `pm.objects` as the shared read view.
3. Add a first domain end-to-end test proving registration, areas,
   provenance, relations, permissions, and deletion rules; selected,
   verified excerpts later replace the placeholder examples in this
   README.
4. Provide the SQL entry-point wrapper (`scripts/write-sql.sh`): connects
   as `editor`, `ON_ERROR_STOP`, transactional execution of a SQL script.
5. Manage Pages PM's own further development within the system itself:
   track the next schema and domain work as real issues, and migrate needed
   historical content on demand.

### Full expression scope

6. Implement the remaining defined domain types.
7. Continuously extend the end-to-end test with the real workflows of new
   domain types, once the types involved exist (e.g. postmortem → action
   item → issue, or KEP-lite → derived ADR).
8. Formally accept Phase B: all domain types are registered, readable via
   `pm.objects`, and validated in their intended workflow.

### Publication and hardening

9. Implement a minimal Python renderer for GitHub Pages.
10. Test roles, permissions, and concurrency with pytest and psycopg.
11. Harden the system based on real usage.

## License

Copyright 2026 Dani Y. (ysdani.com)

Licensed under the Apache License 2.0. See `LICENSE`.
