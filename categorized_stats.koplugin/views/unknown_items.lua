local Format = require("views/format")

local UnknownItemsView = {}

function UnknownItemsView.render(report)
    local lines = {
        "Unknown Items",
        "",
    }

    if #report.review_items == 0 then
        table.insert(lines, "No unknown books found.")
        return table.concat(lines, "\n")
    end

    for _, item in ipairs(report.review_items) do
        table.insert(lines, item.title)
        table.insert(lines, "- Category: " .. report.config.unknown_label)
        table.insert(lines, "- Reason: " .. item.reason)
        table.insert(lines, "- Reading time: " .. Format.seconds(item.total_read_time))
        table.insert(lines, "- Pages read: " .. tostring(item.total_read_pages))
        table.insert(lines, "- Collections: " .. Format.list(item.collections))
        if item.md5 then
            table.insert(lines, "- MD5: " .. item.md5)
        end
        table.insert(lines, "")
    end

    return table.concat(lines, "\n")
end

return UnknownItemsView
