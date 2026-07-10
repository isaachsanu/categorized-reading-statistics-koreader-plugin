local Format = {}

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
