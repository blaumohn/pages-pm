<p align="right"><a href="README.md">Deutsch</a> | English</p>

---

# Pages PM

A tested PostgreSQL foundation for repository-oriented project management.

## Status

Early development. The tested relational foundation is implemented;
domain tables (sprints, issues, ADRs, ...) and application interfaces are not
yet complete.

## Motivation

Project management data (issues, sprints, decision records, runbooks, ...)
is represented by a strict relational domain model in PostgreSQL. Constraints,
triggers, and roles enforce integrity instead of relying on hand-written
validation code in an application layer. A later projection layer may render
the validated data as Git-versioned text, for example for GitHub Pages.

## Current scope

| Migration | Purpose |
|---|---|
| `001_bootstrap.sql` | Roles (`schema_owner`, `migrator`, `build`, `pages_renderer`, `backup`), schemas, migration tracking table |
| `002_languages.sql` | Language configuration + central language-map validation |
| `003_objects.sql` | Common object identity (`pm.objects`), object types |
| `004_areas.sql` | Managed classification areas, multi-assignment |
| `005_object_origins.sql` | External migration provenance |
| `006_relation_types.sql` | Relation type definitions + allowed endpoint combinations |
| `007_object_relations.sql` | Validated typed relations between objects (cardinality, cycles, descriptions) |

Not yet implemented: domain tables (sprint, issue, document templates),
a write API, an application/PostgREST layer, the Git/text projection,
production-grade role and concurrency tests, a UI.

## Architecture

```
PostgreSQL (current authoritative store)
├── roles: schema_owner (NOLOGIN), migrator, build, pages_renderer, backup
├── schemas, constraints, and triggers enforce domain integrity
└── planned published views provide a read-only rendering projection

Application layer (thin, not yet built)
├── renderer — selects publishable data and generates
│              static Markdown/HTML pages for GitHub Pages
├── CLI/API — initially restricted DML through the build role
│             (granted table by table, no blanket privileges);
│             later controlled writes through database functions
└── repository integration — links issues to commits, files, symbols,
                             and other implementation artifacts
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
tests/sql/        pgTAP tests grouped by the migration or subsystem they cover
docker/           test-only Postgres+pgTAP image
scripts/          test-sql.sh (automated test run)
compose.yaml      local development database
compose.test.yaml disposable test database
```

## Roadmap

- sprints, issues and further template-backed document tables
- role/permission and concurrency tests (pytest + psycopg)
- a thin write API using controlled database functions
- Git/text projection for GitHub Pages

## License

Copyright 2026 Dani Y. (ysdani.com)

Licensed under the Apache License 2.0. See `LICENSE`.
