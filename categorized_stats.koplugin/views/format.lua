local Format = {}

local WEEKDAYS = {
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
}

local MONTHS = {
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
}

function Format.date_label(date_key)
    local original = tostring(date_key or "")
    local year, month, day = original:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    year = tonumber(year)
    month = tonumber(month)
    day = tonumber(day)

    if not year or not month or not day or month < 1 or month > 12 or day < 1 or day > 31 then
        return original
    end

    local timestamp = os.time{
        year = year,
        month = month,
        day = day,
        hour = 12,
        min = 0,
        sec = 0,
    }
    if not timestamp then
        return original
    end

    local parts = os.date("*t", timestamp)
    if not parts
        or parts.year ~= year
        or parts.month ~= month
        or parts.day ~= day
        or not WEEKDAYS[parts.wday]
        or not MONTHS[parts.month]
    then
        return original
    end

    return string.format(
        "%s, %d %s %04d",
        WEEKDAYS[parts.wday],
        parts.day,
        MONTHS[parts.month],
        parts.year
    )
end

function Format.seconds(seconds)
    seconds = tonumber(seconds) or 0
    local minutes = math.floor((seconds + 30) / 60)
    local hours = math.floor(minutes / 60)
    minutes = minutes % 60

    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    end

    return string.format("%dm", minutes)
end

function Format.list(values, empty_label)
    if not values or #values == 0 then
        return empty_label or "none"
    end
    return table.concat(values, ", ")
end

function Format.bar(value, max_value, width)
    value = tonumber(value) or 0
    max_value = tonumber(max_value) or 0
    width = tonumber(width) or 12

    if value <= 0 or max_value <= 0 then
        return ""
    end

    local bar_width = math.floor((value / max_value * width) + 0.5)
    bar_width = math.max(1, math.min(width, bar_width))
    return string.rep("=", bar_width)
end

return Format
