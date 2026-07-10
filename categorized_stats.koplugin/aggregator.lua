local Classifier = require("classifier")
local TimeRange = require("time_range")

local Aggregator = {}
local UNKNOWN_CATEGORY = "__unknown"

local function title_for(row)
    if row.title and row.title ~= "" then
        return row.title
    end
    return "(Untitled)"
end

local function category_total(report, category, label)
    if not report.totals[category] then
        report.totals[category] = {
            category = category,
            label = label,
            reading_time = 0,
            pages = 0,
            titles = 0,
        }
    end
    return report.totals[category]
end

local function resolved_categories(resolution, config)
    if #resolution.collections == 0 then
        return {
            {
                key = UNKNOWN_CATEGORY,
                label = config.unknown_label,
            },
        }
    end

    local categories = {}
    for _, collection_name in ipairs(resolution.collections) do
        table.insert(categories, {
            key = collection_name,
            label = collection_name,
        })
    end
    return categories
end

local function week_bucket(report, week_key, week_start)
    local week = report.weekly.weeks[week_key]
    if not week then
        week = {
            week_key = week_key,
            week_start = week_start,
            days = TimeRange.week_days(week_start),
            day_totals = {},
            day_categories = {},
            categories = {},
            total_duration = 0,
        }
        report.weekly.weeks[week_key] = week
        table.insert(report.weekly.week_order, week_key)
    end
    return week
end

local function weekly_category(week, key, label)
    local category = week.categories[key]
    if not category then
        category = {
            category = key,
            label = label,
            duration = 0,
            pages = 0,
            titles_by_md5 = {},
            titles = 0,
        }
        week.categories[key] = category
    end
    return category
end

local function day_category(week, date, key, label)
    local day = week.day_categories[date]
    if not day then
        day = {}
        week.day_categories[date] = day
    end

    local category = day[key]
    if not category then
        category = {
            category = key,
            label = label,
            duration = 0,
            pages = 0,
            titles_by_md5 = {},
            titles = 0,
        }
        day[key] = category
    end
    return category
end

function Aggregator.build(books, daily_rows, collection_index, config, activity_rows)
    local report = {
        config = config,
        collection_file = collection_index.collection_file,
        collections_missing = collection_index.missing,
        category_order = {},
        books = {},
        daily = {},
        timeline_by_date = {},
        weekly = {
            weeks = {},
            week_order = {},
        },
        totals = {},
        review_items = {},
    }

    for _, collection_name in ipairs(collection_index.collection_names or {}) do
        table.insert(report.category_order, collection_name)
    end

    for _, book in ipairs(books or {}) do
        local resolution = Classifier.resolve(book.md5, collection_index)
        local enriched = {
            id = book.id,
            title = title_for(book),
            authors = book.authors,
            md5 = book.md5,
            total_read_time = book.total_read_time,
            total_read_pages = book.total_read_pages,
            collections = resolution.collections,
            files = resolution.files,
            reason = resolution.reason,
        }

        table.insert(report.books, enriched)

        if #enriched.collections == 0 then
            local total = category_total(report, UNKNOWN_CATEGORY, config.unknown_label)
            total.reading_time = total.reading_time + enriched.total_read_time
            total.pages = total.pages + enriched.total_read_pages
            total.titles = total.titles + 1
            table.insert(report.review_items, enriched)
        else
            for _, collection_name in ipairs(enriched.collections) do
                local total = category_total(report, collection_name, collection_name)
                total.reading_time = total.reading_time + enriched.total_read_time
                total.pages = total.pages + enriched.total_read_pages
                total.titles = total.titles + 1
            end
        end

    end

    if report.totals[UNKNOWN_CATEGORY] then
        table.insert(report.category_order, UNKNOWN_CATEGORY)
    end

    for _, row in ipairs(daily_rows or {}) do
        local resolution = Classifier.resolve(row.md5, collection_index)
        local day = report.daily[row.date]
        if not day then
            day = {}
            report.daily[row.date] = day
        end

        table.insert(day, {
            title = title_for(row),
            authors = row.authors,
            md5 = row.md5,
            collections = resolution.collections,
            duration = row.duration,
            pages = row.pages,
        })
    end

    for _, row in ipairs(activity_rows or {}) do
        local resolution = Classifier.resolve(row.md5, collection_index)
        local categories = resolved_categories(resolution, config)
        local segments = TimeRange.split_session(row)

        for _, segment in ipairs(segments) do
            segment.title = title_for(segment)
            segment.authors = row.authors
            segment.collections = resolution.collections
            segment.category_labels = {}
            for _, category in ipairs(categories) do
                table.insert(segment.category_labels, category.label)
            end

            local day = report.timeline_by_date[segment.date]
            if not day then
                day = {}
                report.timeline_by_date[segment.date] = day
            end
            table.insert(day, segment)

            local week_start = TimeRange.week_start(segment.start_time)
            local week_key = TimeRange.date_key(week_start)
            local week = week_bucket(report, week_key, week_start)
            week.total_duration = week.total_duration + segment.duration
            week.day_totals[segment.date] = (week.day_totals[segment.date] or 0) + segment.duration

            for _, category_info in ipairs(categories) do
                local category = weekly_category(week, category_info.key, category_info.label)
                category.duration = category.duration + segment.duration
                category.pages = category.pages + (segment.pages or 0)
                if segment.md5 and not category.titles_by_md5[segment.md5] then
                    category.titles_by_md5[segment.md5] = true
                    category.titles = category.titles + 1
                end

                local per_day_category = day_category(week, segment.date, category_info.key, category_info.label)
                per_day_category.duration = per_day_category.duration + segment.duration
                per_day_category.pages = per_day_category.pages + (segment.pages or 0)
                if segment.md5 and not per_day_category.titles_by_md5[segment.md5] then
                    per_day_category.titles_by_md5[segment.md5] = true
                    per_day_category.titles = per_day_category.titles + 1
                end
            end
        end
    end

    table.sort(report.weekly.week_order, function(a, b)
        return a > b
    end)

    for _, segments in pairs(report.timeline_by_date) do
        table.sort(segments, function(a, b)
            if a.start_time == b.start_time then
                return a.title < b.title
            end
            return a.start_time < b.start_time
        end)
    end

    return report
end

return Aggregator
