local Format = require("views/format")

local GlobalStatsView = {}

function GlobalStatsView.render(report)
    local lines = {
        "Categorized Reading Stats",
        "",
    }

    if report.collections_missing then
        table.insert(lines, "Collections file was not found.")
        table.insert(lines, "")
    end

    if #report.books == 0 then
        table.insert(lines, "No reading statistics found.")
        return table.concat(lines, "\n")
    end

    for _, category in ipairs(report.category_order) do
        local total = report.totals[category]
        if total then
            table.insert(lines, total.label)
            table.insert(lines, "- Reading time: " .. Format.seconds(total.reading_time))
            table.insert(lines, "- Pages read: " .. tostring(total.pages))
            table.insert(lines, "- Titles: " .. tostring(total.titles))
            table.insert(lines, "")
        end
    end

    return table.concat(lines, "\n")
end

return GlobalStatsView
