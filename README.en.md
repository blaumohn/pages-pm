<p align="right"><a href="README.md">Deutsch</a> | English</p>

---

# Pages PM

A tested PostgreSQL foundation for repository-oriented project management.

## Status

The tested relational foundation for languages, object registration, areas,
external migration provenance, and typed relations is implemented on top of
the final registry model.

The next operational milestone is managing Pages PM's own development:
current sprints, issues, and the immediately needed document templates will
be implemented as domain tables and used with real project data.

A small Python renderer follows, producing deterministic Markdown output for
GitHub Pages.

PostgREST, a web UI, and a general write API are not part of the MVP.

## Motivation

Pages PM represents project management data in validated PostgreSQL domain
tables. Every domain object type has its own domain table with explicit
columns, constraints, and domain rules. Shared relations, areas, and
migration provenance use an automatically maintained object registry.
Historical content is only normalized on demand; PostgreSQL remains the
authoritative data source.

## Terminology

Three distinct operations share related but different names:

```
Schema migration
    changes the reusable database schema and its rules
    (migrations/)

Project configuration
    registers the concrete languages, object types, and relation types
    of this Pages PM installation (project/)

Content migration / import
    normalizes an external archive unit into an internal object
    (pm.object_origins)
```

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

`project/` supplements this concrete Pages PM installation with languages,
object types, and relation types (see "Terminology" above).

Not yet implemented: domain tables (sprint, issue, and the first needed
document template) together with the shared `pm.objects` view, and the
Python renderer. A general write API, PostgREST, and a UI are planned for a
later expansion.

## Architecture

```
PostgreSQL
├── domain tables are the authoritative objects (not yet implemented)
│   ├── pm.sprints
│   ├── pm.issues
│   ├── pm.kep_lites
│   └── further templates
├── pm.object_registry
│   └── automatically maintained shared UUID and type registration
├── shared rules
│   ├── languages
│   ├── areas
│   ├── migration provenance
│   └── typed relations
└── pm.objects (not yet implemented)
    └── shared read view across the domain tables

Editing
├── editor uses direct, role-scoped SQL
├── multi-part operations run in a single transaction
└── constraints, foreign keys, and triggers enforce integrity

Publication (not yet implemented)
└── Python renderer connects as reader and generates Markdown for GitHub Pages
```

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

## Repository structure

```
migrations/       versioned SQL migrations (001_bootstrap.sql, 002_..., ...)
project/          Pages PM-specific project configuration (languages, object types, relation types)
tests/sql/        pgTAP tests grouped by the migration or subsystem they cover
docker/           test-only Postgres+pgTAP image
scripts/          test-sql.sh (automated test run)
compose.yaml      local development database
compose.test.yaml disposable test database
```

## Roadmap

1. first operational domain core of sprint, issue, and one document
   template, together with the `pm.objects` read view
2. small SQL entry-point wrapper (`scripts/write-sql.sh`): connects as
   `editor`, `ON_ERROR_STOP`, transactional execution of a SQL script
3. current project work directly in Pages PM
4. on-demand migration of historical content
5. minimal Python renderer for GitHub Pages
6. role, permission, and concurrency tests with pytest and psycopg
7. hardening based on real usage

## License

Copyright 2026 Dani Y. (ysdani.com)

Licensed under the Apache License 2.0. See `LICENSE`.
