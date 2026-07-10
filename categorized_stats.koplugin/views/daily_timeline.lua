local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextWidget = require("ui/widget/textwidget")

local Format = require("views/format")

local DailyTimelineView = {}

local PADDING = 20
local TITLE_WIDTH = 256
local HEADER_HEIGHT = 48
local BOOK_ROW_HEIGHT = 64
local BOOK_TITLE_SIZE = 12
local BOOK_COLLECTION_SIZE = 10
local BOOK_TITLE_Y_OFFSET = 6
local BOOK_COLLECTION_Y_OFFSET = 30
local BOOK_COLLECTION_FONT = "NotoSans-Italic.ttf"
local MIN_HOUR_WIDTH = 28
local BOX_VERTICAL_PADDING = 8
local BOX_LABEL_SIZE = 12
local GANTT_FILL_COLOR = Blitbuffer.COLOR_DARK_GRAY or Blitbuffer.COLOR_GRAY or Blitbuffer.COLOR_BLACK
local BUTTON_WIDTH = 96
local BUTTON_HEIGHT = 48
local BUTTON_GAP = 16

local function screen_width()
    return Device.screen:getWidth()
end

local function screen_height()
    return Device.screen:getHeight()
end

local function paint_rect(bb, x, y, w, h, color)
    if w > 0 and h > 0 then
        bb:paintRect(x, y, w, h, color or Blitbuffer.COLOR_BLACK)
    end
end

local function paint_border(bb, x, y, w, h)
    paint_rect(bb, x, y, w, 1)
    paint_rect(bb, x, y + h - 1, w, 1)
    paint_rect(bb, x, y, 1, h)
    paint_rect(bb, x + w - 1, y, 1, h)
end

local function text_widget(text, size, color, font_face)
    return TextWidget:new{
        text = tostring(text or ""),
        face = Font:getFace(font_face or "cfont", size or 14),
        fgcolor = color,
    }
end

local function paint_text(bb, text, x, y, size, color, font_face)
    local widget = text_widget(text, size, color, font_face)
    widget:paintTo(bb, x, y)
    local dimen = widget:getSize()
    return dimen.w, dimen.h
end

local function paint_button(bb, text, x, y, w, h)
    paint_border(bb, x, y, w, h)
    paint_text(bb, text, x + 8, y + 6, 14)
end

local function clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
end

local function crop_to_width(text, max_width, size, font_face)
    text = tostring(text or "")
    if max_width <= 0 then
        return ""
    end

    local widget = text_widget(text, size, nil, font_face)
    if widget:getSize().w <= max_width then
        return text
    end

    local low = 0
    local high = #text
    while low < high do
        local mid = math.ceil((low + high) / 2)
        widget = text_widget(text:sub(1, mid), size, nil, font_face)
        if widget:getSize().w <= max_width then
            low = mid
        else
            high = mid - 1
        end
    end

    return text:sub(1, low)
end

local function duration_label(seconds)
    local minutes = math.max(1, math.floor(((tonumber(seconds) or 0) + 30) / 60))
    local hours = math.floor(minutes / 60)
    minutes = minutes % 60

    if hours > 0 and minutes > 0 then
        return string.format("%dh %dm", hours, minutes)
    elseif hours > 0 then
        return string.format("%dh", hours)
    end

    return string.format("%dm", minutes)
end

local function paint_centered_text(bb, text, x, y, w, h, size)
    local widget = text_widget(text, size, Blitbuffer.COLOR_WHITE)
    local dimen = widget:getSize()
    local text_w = dimen.w
    local text_h = dimen.h
    local text_x = x + math.floor((w - text_w) / 2)
    local text_y = y + math.max(1, math.floor((h - text_h) / 2))

    paint_rect(bb, text_x - 2, text_y - 1, text_w + 4, text_h + 2, GANTT_FILL_COLOR)
    widget:paintTo(bb, text_x, text_y)
end

local function paint_precise_segment_box(bb, table_x, title_width, hour_width, row_y, segment)
    local start_minute = segment.start_minute or 0
    local end_minute = segment.end_minute or start_minute
    local left = table_x + title_width + math.floor(start_minute / 60 * hour_width)
    local width = math.max(3, math.floor((end_minute - start_minute) / 60 * hour_width + 0.5))
    local max_width = table_x + title_width + (24 * hour_width) - left - 1
    local box_y = row_y + BOX_VERTICAL_PADDING
    local box_h = math.max(4, BOOK_ROW_HEIGHT - (BOX_VERTICAL_PADDING * 2))

    if max_width > 0 then
        paint_rect(bb, left + 1, box_y, math.min(width, max_width), box_h)
    end
end

local function segment_hour_block(segment)
    local duration = tonumber(segment.duration) or 0
    if duration <= 0 then
        return nil
    end

    local start_hour
    local end_hour

    if segment.start_time and segment.end_time then
        local start_parts = os.date("*t", segment.start_time)
        local end_parts = os.date("*t", segment.end_time)

        start_hour = clamp(start_parts.hour, 0, 23)
        if segment.end_minute == 1440 then
            end_hour = 23
        elseif end_parts.min == 0 and end_parts.sec == 0 then
            end_hour = clamp(end_parts.hour - 1, 0, 23)
        else
            end_hour = clamp(end_parts.hour, 0, 23)
        end
    else
        local start_minute = clamp(segment.start_minute or 0, 0, 1439)
        local end_minute = clamp(segment.end_minute or start_minute, 0, 1440)

        start_hour = clamp(math.floor(start_minute / 60), 0, 23)
        if end_minute <= start_minute then
            end_hour = start_hour
        else
            end_hour = clamp(math.ceil(end_minute / 60) - 1, 0, 23)
        end
    end

    if end_hour < start_hour then
        end_hour = start_hour
    end

    return {
        start_hour = start_hour,
        end_hour = end_hour,
        duration = duration,
    }
end

local function collect_gantt_blocks(segments)
    local blocks = {}

    for _, segment in ipairs(segments or {}) do
        local block = segment_hour_block(segment)
        if block then
            table.insert(blocks, block)
        end
    end

    table.sort(blocks, function(a, b)
        if a.start_hour == b.start_hour then
            return a.end_hour < b.end_hour
        end
        return a.start_hour < b.start_hour
    end)

    local merged = {}
    for _, block in ipairs(blocks) do
        local current = merged[#merged]
        if current and block.start_hour <= current.end_hour + 1 then
            current.end_hour = math.max(current.end_hour, block.end_hour)
            current.duration = current.duration + block.duration
        else
            table.insert(merged, {
                start_hour = block.start_hour,
                end_hour = block.end_hour,
                duration = block.duration,
            })
        end
    end

    return merged
end

local function paint_hour_block_box(bb, table_x, title_width, hour_width, row_y, block)
    local left = table_x + title_width + (block.start_hour * hour_width)
    local width = math.max(3, ((block.end_hour - block.start_hour + 1) * hour_width) - 1)
    local box_y = row_y + BOX_VERTICAL_PADDING
    local box_h = math.max(4, BOOK_ROW_HEIGHT - (BOX_VERTICAL_PADDING * 2))

    paint_rect(bb, left + 1, box_y, width, box_h, GANTT_FILL_COLOR)
    paint_border(bb, left + 1, box_y, width, box_h)
    paint_centered_text(bb, duration_label(block.duration), left + 1, box_y, width, box_h, BOX_LABEL_SIZE)
end

local function paint_hour_segment_box(bb, table_x, title_width, hour_width, row_y, segment)
    local block = segment_hour_block(segment)
    if block then
        paint_hour_block_box(bb, table_x, title_width, hour_width, row_y, block)
    end
end

local function latest_date(report)
    local latest
    for date in pairs(report.timeline_by_date or {}) do
        if not latest or date > latest then
            latest = date
        end
    end
    return latest
end

local function book_key(segment)
    return segment.md5 or segment.title
end

local function collect_books(segments)
    local books = {}
    local by_key = {}

    for _, segment in ipairs(segments or {}) do
        local key = book_key(segment)
        local book = by_key[key]
        if not book then
            book = {
                key = key,
                title = segment.title,
                collections = segment.collections or {},
                first_start = segment.start_time,
                segments = {},
            }
            by_key[key] = book
            table.insert(books, book)
        end
        book.first_start = math.min(book.first_start, segment.start_time)
        table.insert(book.segments, segment)
    end

    table.sort(books, function(a, b)
        if a.first_start == b.first_start then
            return a.title < b.title
        end
        return a.first_start < b.first_start
    end)

    return books
end

local function point_in_box(pos, box)
    return pos
        and pos.x >= box.x
        and pos.x <= box.x + box.w
        and pos.y >= box.y
        and pos.y <= box.y + box.h
end

local DailyTimelineWidget = InputContainer:extend{
    name = "categorized_stats_daily_timeline",
}

function DailyTimelineWidget:init()
    self.dimen = Geom:new{
        x = 0,
        y = 0,
        w = screen_width(),
        h = screen_height(),
    }
    self.hitboxes = {}
    self.ges_events = {
        TapSelect = {
            GestureRange:new{
                ges = "tap",
                range = self.dimen,
            },
        },
    }
end

function DailyTimelineWidget:add_hitbox(action, x, y, w, h)
    table.insert(self.hitboxes, {
        action = action,
        x = x,
        y = y,
        w = w,
        h = h,
    })
end

function DailyTimelineWidget:paintTo(bb, x, y)
    self.hitboxes = {}
    x = x or 0
    y = y or 0

    paint_rect(bb, x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)

    local segments = self.report.timeline_by_date[self.date] or {}
    local books = collect_books(segments)
    local content_width = self.dimen.w - (PADDING * 2)
    local table_x = x + PADDING
    local table_y = y + PADDING + 128
    local table_width = content_width
    local title_width = math.min(TITLE_WIDTH, math.max(1, math.floor(table_width / 3)))
    local hour_area_width = table_width - title_width
    local hour_width = math.max(MIN_HOUR_WIDTH, math.floor(hour_area_width / 24))
    if hour_width * 24 > hour_area_width then
        hour_width = math.max(1, math.floor(hour_area_width / 24))
    end
    local grid_width = title_width + (hour_width * 24)
    local grid_height = HEADER_HEIGHT + (#books * BOOK_ROW_HEIGHT)

    paint_text(bb, "Daily Timeline", x + PADDING, y + PADDING + 4, 20)

    local close_x = x + self.dimen.w - PADDING - BUTTON_WIDTH
    local button_y = y + PADDING
    paint_button(bb, "Close", close_x, button_y, BUTTON_WIDTH, BUTTON_HEIGHT)
    self:add_hitbox("close", close_x, button_y, BUTTON_WIDTH, BUTTON_HEIGHT)

    if self.on_back then
        local back_x = close_x - BUTTON_GAP - BUTTON_WIDTH
        paint_button(bb, "Back", back_x, button_y, BUTTON_WIDTH, BUTTON_HEIGHT)
        self:add_hitbox("back", back_x, button_y, BUTTON_WIDTH, BUTTON_HEIGHT)
    end

    paint_text(bb, "Date: " .. (self.date or ""), x + PADDING, y + PADDING + BUTTON_HEIGHT + 18, 16)

    if #books == 0 then
        paint_text(bb, "No reading activity found for this day.", x + PADDING, table_y, 16)
        return
    end

    paint_border(bb, table_x, table_y, grid_width, grid_height)
    paint_rect(bb, table_x + title_width, table_y, 1, grid_height)
    paint_rect(bb, table_x, table_y + HEADER_HEIGHT, grid_width, 1)

    paint_text(bb, "Title", table_x + 4, table_y + 8, 12)
    for hour = 0, 23 do
        local column_x = table_x + title_width + (hour * hour_width)
        if hour > 0 then
            paint_rect(bb, column_x, table_y, 1, grid_height)
        end
        paint_text(bb, string.format("%02d", hour), column_x + 2, table_y + 8, 11)
    end

    for index, book in ipairs(books) do
        local row_y = table_y + HEADER_HEIGHT + ((index - 1) * BOOK_ROW_HEIGHT)
        paint_rect(bb, table_x, row_y, grid_width, 1)
        local title = crop_to_width(book.title, title_width - 8, BOOK_TITLE_SIZE)
        local collection_label = Format.list(
            book.collections,
            self.report.config and self.report.config.unknown_label or "Unknown"
        )
        collection_label = crop_to_width(
            collection_label,
            title_width - 8,
            BOOK_COLLECTION_SIZE,
            BOOK_COLLECTION_FONT
        )

        paint_text(
            bb,
            title,
            table_x + 4,
            row_y + BOOK_TITLE_Y_OFFSET,
            BOOK_TITLE_SIZE
        )
        paint_text(
            bb,
            collection_label,
            table_x + 4,
            row_y + BOOK_COLLECTION_Y_OFFSET,
            BOOK_COLLECTION_SIZE,
            nil,
            BOOK_COLLECTION_FONT
        )
    end

    for index, book in ipairs(books) do
        local row_y = table_y + HEADER_HEIGHT + ((index - 1) * BOOK_ROW_HEIGHT)
        for _, block in ipairs(collect_gantt_blocks(book.segments)) do
            paint_hour_block_box(bb, table_x, title_width, hour_width, row_y, block)
        end
    end
end

function DailyTimelineWidget:handle_tap(ges)
    local pos = ges and (ges.pos or ges)
    for _, box in ipairs(self.hitboxes or {}) do
        if point_in_box(pos, box) then
            if box.action == "close" and self.on_close then
                self.on_close()
                return true
            elseif box.action == "back" and self.on_back then
                self.on_back()
                return true
            end
        end
    end
end

function DailyTimelineWidget:onTapSelect(_, ges)
    return self:handle_tap(ges)
end

function DailyTimelineWidget:onTap(_, ges)
    return self:handle_tap(ges)
end

function DailyTimelineView.latest_date(report)
    return latest_date(report)
end

function DailyTimelineView.newWidget(args)
    return DailyTimelineWidget:new(args)
end

function DailyTimelineView.render(report, date)
    date = date or latest_date(report)

    local lines = {
        "Daily Timeline",
        "",
    }

    if not date then
        table.insert(lines, "No reading activity found.")
        return table.concat(lines, "\n")
    end

    table.insert(lines, "Date: " .. date)
    table.insert(lines, "")

    local segments = report.timeline_by_date[date] or {}
    if #segments == 0 then
        table.insert(lines, "No reading activity found for this day.")
        return table.concat(lines, "\n")
    end

    for _, segment in ipairs(segments) do
        table.insert(lines, string.format(
            "%s-%s | %s | %s | %s",
            segment.start_label,
            segment.end_label,
            segment.title,
            Format.list(segment.category_labels, report.config.unknown_label),
            Format.seconds(segment.duration)
        ))
    end

    return table.concat(lines, "\n")
end

return DailyTimelineView
