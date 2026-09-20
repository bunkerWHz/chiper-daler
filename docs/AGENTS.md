---
title: Wiki Schema
type: schema
created: 2026-09-20
updated: 2026-09-20
tags: [meta]
---

# Wiki schema

Instructions for the agent that maintains this vault. Modelled on the
[LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f):
knowledge is compiled into persistent, interlinked pages once and then kept up
to date, instead of being re-derived from raw sources on every question.

This directory (`docs/`) is both the Obsidian vault root and the compiled wiki
layer of the project. Open `docs/` as a folder vault in Obsidian; every `.md`
file here is a wiki page.

## Layers

| Layer | Location | Ownership |
| --- | --- | --- |
| Raw sources | The Godot project outside `docs/`: `game/`, `features/`, `framework/`, `levels/`, `tests/`, `art/`, `assets/`, `project.godot` | Immutable ground truth. Read, never rewrite, never duplicate. |
| Wiki | `docs/*.md` | The agent owns this layer completely: pages, cross-references, index, log. |
| Schema | This file | Co-evolve with the user as conventions change. |

Raw sources are cited by path in backticks (`` `game/enemy/GroundDummy.tscn` ``).
They can never be linked with a vault link: Obsidian cannot resolve targets
outside the vault root. `docs/sources.md` is the catalog of raw sources,
including the project's own `README.md` files, which stay where they are and are
never copied into the wiki.

## Language

- Page content is written in the language of the page it belongs to. Most
  gameplay and authoring pages are Russian; `Architecture_Rules.md`,
  `Enemies.md` and `Actor_States.md` are English. Match the page you edit.
- YAML keys, `type` values, filenames and structural table headers stay in
  English.
- Keep the user's naming for game objects, components and scenes exactly as it
  appears in the editor.

## Directory layout

```text
docs/
  AGENTS.md          # this schema
  index.md           # content catalog - update on every ingest
  overview.md        # top-level synthesis - revise when the big picture changes
  concepts.md        # concept matrix - update on every concept change
  sources.md         # raw-source catalog - update when the project layout moves
  log.md             # append-only operation log
  tools/wiki_lint.mjs# local lint tool, see Verification
  *.md               # topic pages, flat on purpose
  .obsidian/         # vault configuration (committed)
```

Topic pages stay flat so that `` [[wikilinks]] `` and relative markdown links
resolve without path bookkeeping, and so the existing repository links into
`docs/` keep working. Do not introduce topic subfolders. Adding one is a
deliberate change that must update every inbound link in the repository.

## Page types

| Type | Purpose | Examples |
| --- | --- | --- |
| `schema` | Conventions for maintaining this vault. | `AGENTS.md` |
| `index` | Navigation: catalogs and maps of what exists. | `index.md`, `sources.md`, `Project_Guide.md` |
| `overview` | Top-level synthesis of the whole knowledge base. | `overview.md` |
| `concept-table` | Maintained matrix of durable terms: definition, owner page, related terms. | `concepts.md` |
| `log` | Append-only record of operations. | `log.md` |
| `architecture` | How a system is built, its rules, invariants and responsibility boundaries. | `Architecture_Rules.md`, `Actor_States.md`, `Save_System.md` |
| `guide` | Step-by-step authoring work in the editor or in code. | `Level_Authoring.md`, `DOT.md`, `Enemies.md` |
| `reference` | Parameters, catalogs, tables, implementation status of individual fields. | `Components.md`, `Actor_Stats.md`, `Item_Parameters.md` |
| `plan` | Tracked work with checkboxes and outcomes. | `Refactoring_Plan.md` |

## Page format

Every page starts with YAML frontmatter. Unlike the reference pattern, `index.md`
and `log.md` carry it too, so that properties, tags and graph colours work
uniformly.

```yaml
---
title: Система сохранений
type: architecture
created: 2026-09-16
updated: 2026-09-20
tags: [saves, persistence]
---
```

- `title` — human-readable name, in the page's language.
- `type` — exactly one value from the table above.
- `created` / `updated` — `YYYY-MM-DD`. `created` is the date the page first
  entered the repository; `updated` changes on every content edit.
- `tags` — one to four lowercase tags from the controlled vocabulary below.
  Two or more preferred; one is enough for a pure navigation page.

Body conventions:

- Keep the existing heading structure; do not renumber or translate headings
  that other pages link to by anchor.
- One page covers one topic. When a page passes roughly 600 lines or starts
  covering two unrelated systems, split it and update `index.md`.
- State implementation status with the vocabulary already used in
  `Actor_Stats.md`: **Работает**, **Заготовка**, **План**, **Обсудить**,
  **Отменено**. A page describing a mechanic must not imply that a planned
  field works.
- When a new decision supersedes an older one, keep the old claim and mark it
  as superseded next to the new rule, instead of deleting the history silently.
  `Item_Creation_Design.md` and `Actor_Stats.md` are the examples to follow.
- Prefer tables and short lists over prose for parameters. Author instructions
  are numbered steps that name the exact node path.

## Link conventions

- Inside `docs/`, use relative markdown links: `[Характеристики Actor](Actor_Stats.md)`.
  They resolve both in Obsidian and on GitHub, which the rest of the repository
  depends on.
- Navigation pages (`index.md`, `overview.md`, `concepts.md`, `sources.md`) use
  `` [[wikilinks]] `` for their own cross-references: they are the pages a
  reader follows in Obsidian, and wikilinks survive renames.
- Do not rewrite existing markdown links into wikilinks. GitHub does not render
  wikilinks, and inbound links from `game/`, `levels/` and `art/` README files
  point at these paths.
- Anchors work in both forms. Cyrillic anchors must match the heading text
  exactly, as in `Actor_Stats.md#пассивные-навыки-и-требования-предметов`.
- Links to raw sources outside the vault (`../features/...`, `../game/...`) are
  allowed and use the same relative markdown form. They are the repository
  convention, they work on GitHub, and the lint tool verifies that their
  targets exist. Obsidian cannot resolve them, so they appear as unresolved
  links inside the vault — that is expected, and the graph hides them. Use
  backticks instead when the path is a value rather than a destination, for
  example a node path or a scene name inside a sentence.
- Never use a wikilink for a target outside the vault: it silently creates a
  phantom note.

## Controlled tag vocabulary

`actor`, `aiming`, `animation`, `architecture`, `audio`, `balance`, `bosses`,
`combat`, `components`, `dot`, `economy`, `enemies`, `equipment`, `inventory`,
`items`, `levels`, `loot`, `meta`, `player`, `progression`, `saves`, `stats`,
`status-effects`, `testing`, `tilesets`, `ui`, `workflow`.

Add a tag only when an existing one does not fit, and add it to this list in the
same edit.

## Operations

### Ingest

Trigger: a mechanic, scene, resource or decision changed in the project, or the
user asks to document something.

1. Read the affected raw sources completely — scenes, scripts, resources,
   configuration. Do not trust memory of the code.
2. Find the owning page. Update it rather than creating a second page about the
   same system.
3. Update every other page that states a fact that is now wrong: cross-page
   consistency comes before local accuracy.
4. Update `concepts.md` for every term added, renamed, split or materially
   changed.
5. Update `index.md`: add new pages with a one-line summary, refresh summaries
   that no longer describe the page.
6. Revise `overview.md` only when the change alters the project-level picture.
7. Append an entry to `log.md`.
8. Run `node tools/wiki_lint.mjs` from `docs/` and fix what it reports.

### Query

Trigger: the user asks a question about the project.

1. Read `index.md` first; read `concepts.md` too for terminology or
   relationship questions.
2. Open the candidate pages and read them fully. Never answer from a grep hit
   or a heading alone.
3. Follow the relative links on those pages before concluding that the wiki
   lacks the answer.
4. Verify against raw sources when the answer states concrete values, node
   paths or field names.
5. Cite the wiki pages you used.
6. If the answer is durable knowledge — a comparison, a derived rule, a
   synthesis that took real work — offer to archive it as a new page and add it
   to `index.md`.

### Lint

Trigger: the user says lint, review, or health check; also run it before
finishing a documentation change.

1. Run `node tools/wiki_lint.mjs` from `docs/`.
2. Fix mechanically broken things: links inside the vault that resolve to
   nothing, links to raw sources whose file no longer exists, missing or
   malformed frontmatter, unknown `type`, unknown tag, a page missing from
   `index.md`, an index entry pointing at a page that no longer exists.
3. Report, but do not silently rewrite, judgement calls: contradictory claims
   between pages, statuses that the code no longer matches, pages with no
   inbound links, terms used in pages that never reached `concepts.md`, and
   topics the project has that no page covers.
4. Append the outcome to `log.md`.

## Verification

From the `docs/` directory:

```sh
node tools/wiki_lint.mjs
```

The tool is dependency-free and read-only. It checks frontmatter, link
resolution inside and outside the vault, index coverage in both directions, tag
vocabulary and orphan pages. It is a linter, not a source of truth: wiki pages
and raw sources stay authoritative.

For behaviour claims, the project's own checks apply as well — see
[Testing.md](Testing.md) and the commit workflow in the repository root
`AGENTS.md`.
