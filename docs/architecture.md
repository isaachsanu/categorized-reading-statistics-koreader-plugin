# Architecture

## Overview

Categorized Reading Stats is a KOReader plugin that reports reading activity by
KOReader Collection.

The plugin does not replace KOReader Reading Statistics. It reads KOReader's
existing statistics database and collection metadata, then builds category-aware
views from that data.

```text
KOReader Reading Statistics
        |
        | read-only
        v
statistics.sqlite3
        |
        v
Categorized Reading Stats
        |
        +-- KOReader Collections
        |
        v
UI reports
```

## Main Design Principle

`statistics.sqlite3` is the source of reading activity.

KOReader Collections are the current source of categories.

The plugin must never write to `statistics.sqlite3`, official KOReader Reading
Statistics tables, or book files.

## Data Sources

### Reading Statistics Database

Used for:

- Book identity.
- Reading duration.
- Reading dates.
- Page progress.
- Daily reading log.
- Hour-based daily timeline.
- Global reading stats.

Expected important fields:

```text
book.md5
book.title
book.authors
book.total_read_time
book.total_read_pages
page_stat.start_time
page_stat.duration
```

The exact queries are isolated in `stats_reader.lua`.

### KOReader Collections

Used for category information.

For the current plugin, the KOReader Collection name is the report category
name. No custom collection-to-category mapping is required.

Example categories:

```text
Ebook
Manga
Comic
Light Novel
```

## Category Rule

```text
if book belongs to one or more KOReader Collections:
    category = the Collection name or names
else:
    category = Unknown
```

If a book belongs to multiple Collections, reports may include that book in each
matching Collection.

## Plugin UI Views

```text
Categorized Reading Statistics
|- Global Stats
|- Daily Log
|- Weekly View
|- Daily Timeline
`- Unknown Items
```

## Main Flows

### Global Stats Flow

```text
1. Read activity from statistics.sqlite3.
2. Read KOReader Collection membership.
3. Group books by Collection.
4. Display totals.
```

### Daily Log Flow

```text
1. Read page_stat rows.
2. Group by local date.
3. Resolve Collection categories per book.
4. Display date -> title -> duration -> category.
```

Daily Log uses a database-level daily total per date and book.

### Daily Timeline Flow

```text
1. Read positive-duration page_stat rows.
2. Normalize each row into timeline segments with start time, end time, date,
   duration, and book identity.
3. Split sessions across midnight for per-day visual reporting.
4. Group segments by selected date and book.
5. Convert every positive-duration segment into an hour-cell block.
6. Merge overlapping or adjacent blocks for the same book.
7. Sum original segment durations into the merged block label.
8. Preserve the merged block's time range and unique page count for detail
   display.
9. Render rows as book titles and columns as hours 00 through 23.
```

The Daily Timeline painter renders the final Gantt blocks only. Aggregation
logic decides which hour cells a block covers, what duration label it shows,
and what is presented in the non-fullscreen detail popup when a title cell or
Gantt block is tapped.

### Unknown Items Flow

```text
1. Read books from statistics.sqlite3.
2. Check Collection membership.
3. Display books that do not belong to any Collection.
```

## Out of Scope

The public implementation does not currently include:

- A plugin-owned SQLite database.
- Sidecar metadata scanning.
- Calibre metadata compatibility.
- Full EPUB/PDF/CBZ parsing.
- Bibliographic metadata extraction.
- Editing KOReader official Reading Statistics.
- Automatic file moving.
- Complex category hierarchies.
- Cloud sync.
- Multi-device merge.

Future milestone notes may exist in `docs/private/`, but those notes are not
part of the public implemented behavior.
