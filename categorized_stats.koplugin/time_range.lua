local TimeRange = {}

local DAY_SECONDS = 24 * 60 * 60

local function day_start(timestamp)
    local parts = os.date("*t", timestamp)
    parts.hour = 0
    parts.min = 0
    parts.sec = 0
    return os.time(parts)
end

function TimeRange.date_key(timestamp)
    return os.date("%Y-%m-%d", timestamp)
end

function TimeRange.time_key(timestamp)
    return os.date("%H:%M", timestamp)
end

function TimeRange.week_start(timestamp)
    local start = day_start(timestamp)
    local wday = tonumber(os.date("%w", start)) or 1
    local days_since_monday = (wday + 6) % 7
    return start - (days_since_monday * DAY_SECONDS)
end

function TimeRange.week_key(timestamp)
    return TimeRange.date_key(TimeRange.week_start(timestamp))
end

function TimeRange.week_days(week_start)
    local days = {}
    for offset = 0, 6 do
        local timestamp = week_start + (offset * DAY_SECONDS)
        table.insert(days, {
            date = TimeRange.date_key(timestamp),
            label = os.date("%a", timestamp),
            timestamp = timestamp,
        })
    end
    return days
end

function TimeRange.minute_of_day(timestamp)
    local parts = os.date("*t", timestamp)
    return (parts.hour * 60) + parts.min
end

function TimeRange.split_session(row)
    local start_time = tonumber(row.start_time)
    local duration = tonumber(row.duration) or 0
    if not start_time or duration <= 0 then
        return {}
    end

    local end_time = start_time + duration
    local current_start = start_time
    local segments = {}

    while current_start < end_time do
        local current_day_start = day_start(current_start)
        local next_day_start = current_day_start + DAY_SECONDS
        local current_end = math.min(end_time, next_day_start)

        table.insert(segments, {
            id = row.id,
            title = row.title,
            authors = row.authors,
            md5 = row.md5,
            page = row.page,
            pages = row.pages or 1,
            start_time = current_start,
            end_time = current_end,
            duration = current_end - current_start,
            date = TimeRange.date_key(current_start),
            start_label = TimeRange.time_key(current_start),
            end_label = current_end == next_day_start and "24:00" or TimeRange.time_key(current_end),
            start_minute = TimeRange.minute_of_day(current_start),
            end_minute = current_end == next_day_start and 1440 or TimeRange.minute_of_day(current_end),
        })

        current_start = current_end
    end

    return segments
end

return TimeRange
