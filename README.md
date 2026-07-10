# Categorized Reading Stats

Categorized Reading Stats is a KOReader plugin that shows reading statistics
grouped by KOReader Collections.

It reads KOReader's existing Reading Statistics data and Collections.
It reads the official Reading Statistics SQLite database in read-only mode and
does not modify it.

## Install

1. Copy the `categorized_stats.koplugin` folder into KOReader's `plugins`
   directory.

   Location:

   ```text
   koreader/plugins/categorized_stats.koplugin
   ```

2. Restart KOReader.

3. Open KOReader's main menu.

4. Go to:

   ```text
   More tools -> Categorized Reading Stats
   ```

## How to Use

Use KOReader Collections like usual.

The plugin calculates Reading Statistics grouped by Collection.
Books with Reading Statistics entries but no Collection are shown as `Unknown`.
Books that belong to multiple Collections may appear in each matching category.

## Features
1. Global stats by Collection
2. Weekly view
3. Daily timeline with clickable book details
4. Daily log
5. Unknown items review

## Notes

- KOReader Reading Statistics must be enabled for useful results.
- Collection names are used directly as category names.
- The plugin currently focuses on Collection-based categorized stats.

## Keywords

KOReader categorized reading stats, KOReader categorized reading statistics,
collections reading stats, Collection-based reading statistics, KOReader
Collections statistics, categorized ebook reading stats, reading statistics by
Collection, KOReader plugin reading stats.
