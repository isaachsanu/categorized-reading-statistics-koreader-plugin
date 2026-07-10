local Format = require("views/format")

local DailyLogView = {}

local function sorted_dates(daily)
    local dates = {}
    for date in pairs(daily) do
        table.insert(dates, date)
    end
    table.sort(dates, function(a, b)
        return a > b
    end)
    return dates
end

function DailyLogView.render(report)
    local lines = {
        "Daily Reading Log",
        "",
    }

    local dates = sorted_dates(report.daily)
    if #dates == 0 then
        table.insert(lines, "No daily reading activity found.")
        return table.concat(lines, "\n")
    end

    for _, date in ipairs(dates) do
        table.insert(lines, date)
        for _, item in ipairs(report.daily[date]) do
            table.insert(lines, string.format(
                "- %s | %s | %s | %d pages",
                item.title,
                Format.list(item.collections, report.config.unknown_label),
                Format.seconds(item.duration),
                item.pages
            ))
        end
        table.insert(lines, "")
    end

    return table.concat(lines, "\n")
end

return DailyLogView
