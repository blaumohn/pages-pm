
<p align="right"><a href="README.md">Deutsch</a> | English</p>

---

# Pages PM
<!-- mdman:toc:start -->

- [Introduction](#introduction)
- [1. What I was looking for — and what Pages PM makes of it](#1-what-i-was-looking-for--and-what-pages-pm-makes-of-it)
  - [Project work lives in separate systems](#project-work-lives-in-separate-systems)
  - [Small tools are too weak, large ones too heavy](#small-tools-are-too-weak-large-ones-too-heavy)
  - [Sequential numbers claim an order that doesn't exist](#sequential-numbers-claim-an-order-that-doesnt-exist)
  - [A full legacy import delays the start](#a-full-legacy-import-delays-the-start)
  - [People, scripts, and agents must not follow different rules](#people-scripts-and-agents-must-not-follow-different-rules)
  - [Historical content should be usable, not just searchable](#historical-content-should-be-usable-not-just-searchable)
- [2. What Pages PM deliberately is not](#2-what-pages-pm-deliberately-is-not)
- [3. Why not just Jira, Confluence, or Plane?](#3-why-not-just-jira-confluence-or-plane)
- [4. Current state in detail](#4-current-state-in-detail)
- [5. Get started in five minutes](#5-get-started-in-five-minutes)
- [6. Technical model](#6-technical-model)
- [7. Repository structure](#7-repository-structure)
- [8. Path to the first go-live](#8-path-to-the-first-go-live)
- [License](#license)

---
<!-- mdman:toc:end -->



## Introduction

**Pages PM is a small, self-hosted project management system in which
issues, decisions, and governing documents live in one shared,
PostgreSQL-validated store — for people, command lines, and AI agents.**

```text
Not Pages PM

Jira issue:  "Implement renderer"
Wiki page:   "Fallback decision"
Repository:  "Completion rules"

Three places, three states, connections only in prose.

With Pages PM

Issue #9e2b --implements--> Decision #8c21
Policy #4d1a governs its completion
depends_on #4c19 is checked before "in progress"
```

> **Status:** The PostgreSQL foundation and the first issue path are
> implemented and tested, including the specification's current issue
> transitions. Next comes `pm.objects`. The path to the first go-live is
> [further below](#8-path-to-the-first-go-live). The examples below show
> the intended interplay, not the current state.

## 1. What I was looking for — and what Pages PM makes of it

### Project work lives in separate systems

**Problem:** The issue sits in the tracker, the decision in the wiki, and
the completion rule in a repository. To understand why an issue may be
closed, the team has to open several places and reconstruct the connection
itself.

**Pages PM:** Issues, decisions, and governing documents live in one shared
store, connected through typed relations — a wrong connection is a bug, not
an opinion.

```text
#9e2b --implements--> #8c21
Policy #4d1a governs the completion of #9e2b
```

[Why Pages PM connects these stores](product_spec.md#02-warum) ·
[Typed relations](product_spec.md#p-008--typisierte-beziehungen-muss)

### Small tools are too weak, large ones too heavy

**Problem:** Small trackers often drop sub-issues, completion criteria, and
dependencies. Larger systems can model that structure, but demand more
setup and operations in return.

**Pages PM:** It adopts only the structure small projects actually need
validated: issues, embedded steps, sub-issues, dependencies, and document
templates added on demand.

```text
Sub-issue
→ its own state and its own accountability

Step
→ part of an issue, no identity of its own

depends_on
→ one issue waits for another to complete, checked
```

[Resolution boundary](product_spec.md#p-014--auflösungsgrenze-muss-nicht-prüfbar) ·
[Issue model](product_spec.md#76-vorgang)

### Sequential numbers claim an order that doesn't exist

**Problem:** IDs like `PAGES-41`, `PAGES-42`, `PAGES-43` look like a
domain-meaningful sequence. In reality, issues get imported, split, or
reassigned to different sub-projects.

**Pages PM:** An internal UUID carries the durable identity. A short ID like
`#a7k2` serves conversation, commits, and outside references. The title may
change freely and is never used for resolution.

[Identity and addressing](product_spec.md#74-kennungen-adressierung-und-rahmen)

### A full legacy import delays the start

**Problem:** Unifying every old Jira issue, wiki page, and file before
go-live costs a lot of work, even though much of it may never be needed
again.

**Pages PM:** An old item is only migrated once today's work actually needs
it. Its provenance is preserved.

```text
JIRA-42 is needed today
→ migrate it now
→ record provenance jira / JIRA-42

an old ADR becomes relevant later
→ migrate it only then
```

[External provenance](product_spec.md#p-006--externe-herkunft-muss-bei-übernahmen) ·
[Import and development history](product_spec.md#f--import-und-entwicklungsverlauf)

### People, scripts, and agents must not follow different rules

**Problem:** If rules are only checked in one UI or one programming
language, every other write path has to reimplement the same validation.
An import script or an agent can otherwise produce different data than the
UI would.

**Pages PM:** PostgreSQL validates the shared store regardless of the write
path. A person, a SQL script, an AI agent, and a future web UI all hit the
same constraints, foreign keys, and transaction rules.

```text
already enforced:
missing required assignment (e.g. an issue without a project)
→ rejected

invalid relation (e.g. depends_on pointing at the wrong object type)
→ rejected

a multi-step operation with one failing step
→ rolled back entirely

moving to “in progress” while a dependency is open
→ rejected unless an override reason is given
```

[Shared product rules](product_spec.md#4-gemeinsame-produktregeln) ·
[Project membership](product_spec.md#p-002--projektzugehörigkeit-muss)

### Historical content should be usable, not just searchable

**Problem:** A Git archive or an old wiki can be searched, but it still
isn't a connected, validated body of work.

**Pages PM:** Needed content gets migrated into today's model, connected to
it, and from then on maintained under the same rules as new content.

[Import and development history](product_spec.md#f--import-und-entwicklungsverlauf)

The full walkthrough with real short IDs and timestamps is in the
[product specification, §0.5](product_spec.md#05-ein-fall-von-anfang-bis-ende)
(German only). ADR and policy are not yet implemented as domain tables; the
issue itself, including its controlled state transition, is implemented. The
examples above show the intended interplay that every upcoming migration is
checked against.

## 2. What Pages PM deliberately is not

- Not a full Scrum or Kanban prescription.
- Not a mirror of conversations, Git, or external systems — only
  governance- and evidence-relevant statements are stored.
- Not a stockpile of document templates built on spec; a new domain type
  needs a demonstrated purpose (P-012).
- No presentation rules in the domain model. Headings, field order, and
  permalinks belong to the renderer, not the domain templates (§3.2).
- Not a cloud SaaS with per-seat pricing and a web UI. The first mode of
  operation is local PostgreSQL plus the command line.

(In full: §3.2 of the specification.)

## 3. Why not just Jira, Confluence, or Plane?

| | Without Pages PM | With Pages PM |
|---|---|---|
| **Agents** | Tracker API: network, token, rate limit per query. | Local SQL; an agent reads the whole store in one query. |
| **Cost** | Per-seat pricing, even for occasional viewing. | Postgres in a container. |
| **Documentation** | The tracker runs issues, the wiki runs prose — the two drift apart. | Policy, ADR, and spec are domain objects of their own, validated and connected (§8). |

Nine existing tools were reviewed on July 27, 2026 (Appendix D of the
specification). **If you only need sprints and issues, use Plane.** Pages PM
pays off once you need the template system — when governing documents should
live in the same validated store as the work itself
([§0.2](product_spec.md#02-warum)).

## 4. Current state in detail

Implemented and tested today:

- languages and object registration;
- projects, areas, and exactly one project membership per ordinary domain
  object;
- short IDs and external provenance;
- typed relations including `depends_on`, with the issue → issue endpoint;
- states for projects and areas;
- the shared foundation for the state history;
- the issue table with its single-row rules, the acyclic hierarchy, and the
  requirement that parent and child issue belong to the same project;
- the controlled state transition of an issue (permitted transitions,
  dependency barrier with a justified override, an epic's completion barrier
  requiring at least one child, and the completion barrier for unfulfilled
  completion criteria), atomically linked with the state history;
- the rule that an ended parent issue has no open child — checked when the
  write transaction completes, so that parent and child issue can be ended or
  resumed together in a single write transaction.

Not yet implemented: the shared `pm.objects` read view, the domain tables for
the remaining planned domain types, and the Python renderer for GitHub Pages.
For
the first go-live an issue deliberately carries no responsible identity yet
(§10.2 of the specification). Sprint is deliberately excluded from the first
go-live (§12.4) — it will be implemented once a concrete project workflow
needs it.

PostgREST, a web UI, and a general write API are not part of the MVP.

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
| `009_projects.sql` | Project hierarchy (`pm.projects`), project membership per domain object (`pm.object_projects`), and its requirement under P-002 (`requires_project_assignment`, deferred constraint triggers) |
| `010_short_ids.sql` | Short IDs (§7.4): a directory not reassignable under normal operation, automatic assignment on registration, and exact resolution |
| `011_project_area_state.sql` | State for projects and areas, plus scope mode for projects (§7.4); blocks new assignments to closed projects |
| `012_state_history.sql` | Shared, append-only-in-effect foundation for the state history per P-010 across all registered domain objects |
| `013_issues.sql` | Issue (§7.6) as the first domain type implemented in the authoritative working tree: `pm.issues`, required fields from *ready* onwards, the schema of completion criteria, an acyclic hierarchy with permitted parent/child types, the requirement that parent and child issue belong to the same project, plus the `depends_on` endpoint issue → issue. `editor` may not change the state directly. |

`project/` supplements this concrete Pages PM installation with languages,
relation types (`derived_from`, `implements`, `references`, `depends_on`),
and the initial project structure. Object types instead arise atomically in
the schema migration of their respective domain table.

## 5. Get started in five minutes

Pages PM is not yet in production with real data — production begins with
the shared `pm.objects` read view, the SQL entry-point wrapper, and full
end-to-end verification
([section 8](#8-path-to-the-first-go-live)). What runs today in five minutes
is the full migration and test run against a disposable database. Requires
Docker.

```sh
./scripts/test-sql.sh
```

Builds a disposable PostgreSQL 18 + pgTAP container, applies all migrations
in order, runs the pgTAP test suite, and tears everything down afterwards.

The tests, among other things, create synthetic domain objects, register
them automatically in the object registry, assign a project, an area, and an
external provenance to them, and connect them via typed relations.
Provenance and relations block deletion until explicitly removed. For
project-required object types, PostgreSQL demands a valid project
assignment by the time of the deferred check at the latest.

## 6. Technical model

```
PostgreSQL
├── domain tables are the authoritative objects
│   ├── pm.issues (work in progress; controlled state transition implemented)
│   └── further domain types are implemented on concrete demand
├── pm.object_registry
│   └── automatically maintained shared UUID and type registration
├── shared foundations
│   ├── languages
│   ├── projects and project membership (exactly one, enforced)
│   ├── areas
│   ├── short IDs
│   ├── migration provenance
│   ├── typed relations (incl. depends_on)
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

`editor` may create an issue and change its title; the resulting entry in
`pm.object_registry` is created automatically by the domain table's
registration trigger. `editor` may not, however, create a registry entry or
a new object type directly. For project-required object types, the deferred
constraint triggers in `009_projects.sql` enforce that a valid project
assignment exists by the time of the check.

The initial implementation uses PostgreSQL as the authoritative store.
A later repository-backed mode may use canonical text data as the durable
source and PostgreSQL as its validation and query projection.

Migrations are not auto-applied in the current operating model. They are
versioned SQL files applied by `migrator` after review. The disposable test
database uses `scripts/test-sql.sh` to apply them automatically.

## 7. Repository structure

```
product_spec.md   authoritative product specification (German)
migrations/       versioned SQL migrations (001_bootstrap.sql, 002_..., ...)
project/          Pages PM-specific project configuration (languages, relation types, project structure)
tests/sql/        pgTAP tests grouped by the migration or subsystem they cover
docker/           test-only Postgres+pgTAP image
scripts/          test-sql.sh (automated test run)
compose.yaml      local development database
compose.test.yaml disposable test database
```

## 8. Path to the first go-live

The [product specification](product_spec.md) (German) grounds and governs
the domain model; this README only explains the product and its state.
Targeted entry points:

| Question | Section |
|---|---|
| Why does Pages PM exist? | [§0.2](product_spec.md#02-warum) |
| A case from start to finish | [§0.5](product_spec.md#05-ein-fall-von-anfang-bis-ende) |
| Why typed relations? | [P-008](product_spec.md#p-008--typisierte-beziehungen-muss) |
| Why not model everything as its own object? | [P-014](product_spec.md#p-014--auflösungsgrenze-muss-nicht-prüfbar) |
| What an issue looks like | [§7.6](product_spec.md#76-vorgang) |
| How relations and `depends_on` work | [§8](product_spec.md#8-beziehungen) |

**Foundation** (languages, registry, areas, provenance, relations incl.
`depends_on`, project membership, short IDs, states for projects and areas,
foundation for the state history), the **issue table** (§7.6) with its
single-row and hierarchy rules, and the **controlled state transition**
(`pm.transition_issue()`: permitted transitions, triggering of the existing
required-field thresholds, the dependency barrier with a justified override,
an epic's completion barrier requiring at least one child, the completion
barrier for unfulfilled completion criteria, and the history entry written in
the same transaction) are implemented. So is the rule that an ended parent
issue has no open child — as an invariant over the table state, checked when
the write transaction completes. What follows, in this order:

1. Add `pm.objects` as the shared read view (P-011) — deliberately built
   only after the issue table, since it would have little content before
   that.
2. Provide the SQL entry-point wrapper (`scripts/write-sql.sh`): connects as
   `editor`, `ON_ERROR_STOP`, transactional execution of a SQL script — the
   first real issue should no longer be created by hand in `psql`.
3. Create the first real Pages PM issue and record the further issues needed
   for end-to-end verification.
4. Carry out a full end-to-end walkthrough (§11 of the specification);
   selected, verified excerpts later replace the placeholder examples in this
   README.
5. Manage Pages PM's own further development within the system itself:
   track the next schema and domain work as real issues, and migrate needed
   historical content on demand.
6. Add further domain types once a concrete project workflow needs them — no
   stockpiling of every accepted domain type.

After the first go-live, the defined further expansion comprises:
continuously extending the end-to-end walkthrough with the real workflows of
whichever domain types get added, a minimal Python renderer for GitHub Pages,
and a validated roles, permissions, and concurrency layer with pytest and
psycopg.

## License

Copyright 2026 Dani Y. (ysdani.com)

Licensed under the Apache License 2.0. See `LICENSE`.
