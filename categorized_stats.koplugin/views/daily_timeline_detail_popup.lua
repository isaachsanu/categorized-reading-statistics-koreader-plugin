local ButtonDialog = require("ui/widget/buttondialog")
local Device = require("device")
local Font = require("ui/font")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local DailyTimelineView = require("views/daily_timeline")

local DailyTimelineDetailPopupView = {}

local FONT_SCALE = 1.35
local POPUP_MAX_HEIGHT_RATIO = 0.75
local POPUP_LINE_HEIGHT = 32
local POPUP_MIN_CONTENT_HEIGHT = 160

local function scaled_font_size(size)
    return math.floor(((tonumber(size) or 14) * FONT_SCALE) + 0.5)
end

local function page_label(pages)
    pages = math.max(0, math.floor(tonumber(pages) or 0))
    return string.format("%d %s", pages, pages == 1 and "page" or "pages")
end

local function track_text(book, date)
    local lines = {
        "Date: " .. tostring(date or ""),
        "",
        "Track baca hari ini:",
        "",
    }

    local blocks = book and book.merged_blocks or {}
    if #blocks == 0 then
        table.insert(lines, "No reading activity found.")
        return table.concat(lines, "\n"), #lines
    end

    for _, block in ipairs(blocks) do
        table.insert(lines, string.format(
            "%s - %s | %s | %s",
            block.start_label or "--:--",
            block.end_label or "--:--",
            DailyTimelineView.durationLabel(block.duration),
            page_label(block.pages)
        ))
    end

    return table.concat(lines, "\n"), #lines
end

function DailyTimelineDetailPopupView.newWidget(args)
    args = args or {}
    local book = args.book or {}
    local title = tostring(book.title or "(Untitled)")
    local text, line_count = track_text(book, args.date)
    local popup

    popup = ButtonDialog:new{
        title = title,
        buttons = {
            {
                {
                    text = _("Close"),
                    id = "close",
                    callback = function()
                        if args.on_close then
                            args.on_close()
                        else
                            UIManager:close(popup)
                        end
                    end,
                },
            },
        },
    }

    local content_width = popup:getAddedWidgetAvailableWidth()
    local max_height = math.floor(Device.screen:getHeight() * POPUP_MAX_HEIGHT_RATIO)
    local content_height = math.min(
        max_height,
        math.max(POPUP_MIN_CONTENT_HEIGHT, line_count * POPUP_LINE_HEIGHT)
    )

    popup:addWidget(ScrollTextWidget:new{
        text = text,
        face = Font:getFace("infofont", scaled_font_size(14)),
        width = content_width,
        height = content_height,
        dialog = popup,
        not_focusable = true,
    })

    return popup
end

return DailyTimelineDetailPopupView
