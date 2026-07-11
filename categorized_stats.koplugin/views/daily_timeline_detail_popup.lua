local ButtonDialog = require("ui/widget/buttondialog")
local Device = require("device")
local Font = require("ui/font")
local Size = require("ui/size")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local logger = require("logger")

local Format = require("views/format")
local DailyTimelineView = require("views/daily_timeline")

local DailyTimelineDetailPopupView = {}

local FONT_SCALE = 1.35
local POPUP_MAX_HEIGHT_RATIO = 0.75
local FALLBACK_LINE_HEIGHT = 32
local FALLBACK_MIN_CONTENT_HEIGHT = 160

local function scaled_font_size(size)
    return math.floor(((tonumber(size) or 14) * FONT_SCALE) + 0.5)
end

local function page_label(pages)
    pages = math.max(0, math.floor(tonumber(pages) or 0))
    return string.format("%d %s", pages, pages == 1 and "page" or "pages")
end

local function track_text(book, date)
    local lines = {
        Format.date_label(date),
        "",
        "Track baca hari ini:",
    }

    local blocks = book and book.merged_blocks or {}
    if #blocks == 0 then
        table.insert(lines, "No reading activity found.")
        return table.concat(lines, "\n")
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

    return table.concat(lines, "\n")
end

local function measure_text_height(text, face, width)
    local measurement = TextBoxWidget:new{
        text = text,
        face = face,
        width = width,
        for_measurement_only = true,
    }
    local height = measurement:getTextHeight()
    local line_height = measurement:getLineHeight()
    measurement:free()
    return height, line_height
end

local function fallback_content_height(text)
    local _, newline_count = text:gsub("\n", "\n")
    local line_count = newline_count + 1
    local max_height = math.floor(Device.screen:getHeight() * POPUP_MAX_HEIGHT_RATIO)
    return math.min(
        max_height,
        math.max(FALLBACK_MIN_CONTENT_HEIGHT, line_count * FALLBACK_LINE_HEIGHT)
    )
end

function DailyTimelineDetailPopupView.newWidget(args)
    args = args or {}
    local book = args.book or {}
    local title = tostring(book.title or "(Untitled)")
    local text = track_text(book, args.date)
    local face = Font:getFace("infofont", scaled_font_size(14))
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
    local content_height = fallback_content_height(text)
    local sizing_ok, fitted_height = pcall(function()
        local text_width = math.max(
            1,
            content_width
                - ScrollTextWidget.scroll_bar_width
                - ScrollTextWidget.text_scroll_span
        )
        local text_height, line_height = measure_text_height(text, face, text_width)

        -- Keep the complete dialog, including title, controls, padding, and
        -- borders, within the configured screen-height ratio. ButtonDialog
        -- adds one spacer between its title and an added widget.
        local max_popup_height = math.floor(Device.screen:getHeight() * POPUP_MAX_HEIGHT_RATIO)
        -- getContentSize() is nil before ButtonDialog has been painted. Its
        -- movable container can still calculate the size from its children.
        local popup_chrome_height = popup.movable:getSize().h + Size.padding.default
        local max_content_height = math.max(line_height, max_popup_height - popup_chrome_height)
        return math.min(text_height, max_content_height)
    end)
    if sizing_ok then
        content_height = fitted_height
    else
        logger.warn("CategorizedStats: adaptive detail popup sizing failed; using fallback:", fitted_height)
    end

    popup:addWidget(ScrollTextWidget:new{
        text = text,
        face = face,
        width = content_width,
        height = content_height,
        dialog = popup,
        not_focusable = true,
    })

    return popup
end

return DailyTimelineDetailPopupView
