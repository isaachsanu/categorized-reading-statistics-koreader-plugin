# AGENTS.md

## Project Goal

Build a custom KOReader plugin that shows categorized reading statistics.

The current implementation is a reporting layer on top of KOReader's existing
Reading Statistics data. It reads KOReader data and groups books by KOReader
Collections.

Core principles:

- `statistics.sqlite3` from KOReader Reading Statistics is read-only.
- KOReader Collections are the current category source.
- Unknown or uncategorized books should be visible for review.
- The plugin should not crash a reading session because of a stats error.

## Current Scope

Implemented or public-facing work should stay focused on:

- Reading KOReader Reading Statistics.
- Reading KOReader Collections.
- Aggregating global stats by Collection.
- Showing daily logs.
- Showing weekly/date-based visual reports.
- Showing unknown items.

Planning docs for future milestones, configuration behavior, and database work
belong in `docs/private/`. That directory is ignored by Git because those notes
describe work that is not implemented yet.

## Engineering Rules

Code must be:

- Modular.
- Simple enough for this plugin.
- Easy to inspect and debug.
- Conservative about KOReader-owned data.

Avoid:

- Large abstractions before they are needed.
- Complex dependency injection.
- Premature plugin frameworks inside the plugin.
- Writing to KOReader's official `statistics.sqlite3`.
- Public docs that describe unimplemented config or database behavior as if it
  already exists.

Prefer:

- Small modules with clear responsibilities.
- Explicit data flow.
- Clear fallback behavior.
- Safe read-only access to KOReader-owned data.
- User-facing docs that describe the current plugin behavior.

## Current Module Structure

```text
categorized_stats.koplugin/
|- _meta.lua
|- main.lua
|- config.lua
|- stats_reader.lua
|- collection_reader.lua
|- classifier.lua
|- aggregator.lua
|- time_range.lua
`- views/
   |- global_stats.lua
   |- daily_log.lua
   |- weekly_bars.lua
   |- daily_timeline.lua
   |- unknown_items.lua
   `- format.lua
```

## Module Responsibilities

### `main.lua`

Plugin entry point.

Responsibilities:

- Register menu items.
- Connect UI actions to readers, aggregators, and views.
- Keep business logic in supporting modules.

### `config.lua`

Small runtime configuration for current behavior.

Responsibilities:

- Provide the current unknown category label.
- Stay minimal until real configurable behavior is implemented.

### `stats_reader.lua`

Read KOReader Reading Statistics.

Responsibilities:

- Open `statistics.sqlite3` for read access only.
- Query book and page statistics.
- Return normalized rows.
- Do not mutate KOReader's database.

### `collection_reader.lua`

Read KOReader Collections.

Responsibilities:

- Resolve book identity to collection membership where possible.
- Use Collection names as report categories.
- Keep collection logic separate from rendering and aggregation.

### `classifier.lua`

Category decision logic.

Responsibilities:

- Assign Collection-based categories.
- Fall back to `Unknown` when no Collection is found.
- Avoid hidden metadata rules that are not implemented yet.

### `aggregator.lua`

Aggregate normalized reading data for views.

Responsibilities:

- Build global category totals.
- Build daily and weekly report data.
- Split timeline sessions across midnight before per-day visual reporting.
- Preserve unknown items for review.

### `views/`

Render KOReader UI text or visual reports.

Responsibilities:

- Keep display formatting out of readers.
- Present useful summaries without mutating source data.

### `views/daily_timeline.lua`

Daily Timeline visual report.

Responsibilities:

- Render rows as book titles and columns as hours `00` through `23`.
- Keep the title column width bounded and crop overlong book titles.
- Build final Gantt blocks from normalized timeline segments before painting.
- Map every positive-duration segment to at least one hour cell, including
  short sessions that start and end inside the same minute.
- Merge overlapping or adjacent hour blocks for the same book and sum their
  original durations.
- Paint only final Gantt blocks; painter code should not decide aggregation
  semantics.

## Data Ownership Rules

### Read-only sources

The plugin may read from:

```text
statistics.sqlite3
KOReader collections
```

### Writable sources

The current plugin should not write to KOReader official data.

The plugin must not write to:

```text
statistics.sqlite3
KOReader official Reading Statistics tables
book files
```

## Error Handling Rules

The plugin should never crash the reading session because of a
statistics/indexing error.

Prefer:

- Log the error.
- Skip the broken item.
- Mark the item as `Unknown`.
- Show unknown items in a review screen.

## Documentation Rules

Keep docs practical.

Public docs should answer:

- What does the plugin currently do?
- How is it installed?
- What does it read?
- What does it not modify?

Private planning docs belong under `docs/private/`.

## Testing Rules

Follow the repository testing rules from the workspace instructions:

- Do not run tests automatically by default.
- Run targeted tests only when the current change clearly requires them or the
  user explicitly asks.
- Do not run database-related tests or commands without explicit permission in
  the current task.
