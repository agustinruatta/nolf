# Lead Programmer — Agent Memory

## Skill Authoring Conventions

### Frontmatter
- Fields: `name`, `description`, `argument-hint`, `user-invocable`, `allowed-tools`
- Read-only analysis skills that run in isolation also carry `context: fork` and `agent:`
- Interactive skills (write files, ask questions) do NOT use `context: fork`
- `AskUserQuestion` is a usage pattern described in skill body text — it is NOT listed
  in `allowed-tools` frontmatter (no existing skill does this)

### File Layout
- Skills live in `.claude/skills/<name>/SKILL.md` (subdirectory per skill, never flat .md)
- Section headers use `##` for phases, `###` for sub-sections
- Phase names follow "Phase N: Verb Noun" pattern (e.g., "Phase 1: Find the Story")
- Output format templates go in fenced code blocks

### Known Canonical Paths (verify before referencing in new skills)
- Tech debt register: `docs/tech-debt-register.md` (NOT `production/tech-debt.md`)
- Sprint files: `production/sprints/`
- Epic story files: `production/epics/[epic-slug]/story-[NNN]-[slug].md`
- Control manifest: `docs/architecture/control-manifest.md`
- Session state: `production/session-state/active.md`
- Systems index: `design/gdd/systems-index.md`
- Engine reference: `docs/engine-reference/[engine]/VERSION.md`

### Skills Completed
- `story-done` — end-of-story completion handshake (Phase 1-8, writes story file)

## MLS Epic

- [MLS stories created 2026-04-30](project_mls_stories_created.md) — 5 VS-scoped stories; dependency order 001→002→003→004→005; 3 open questions live

## Failure & Respawn Epic

- [F&R stories created 2026-04-30](project_fr_stories_created.md) — 6 VS-scoped stories; all 14 TR-IDs covered; dependency chain 001→002→003; 001→004; {002,003,004}→005→006
