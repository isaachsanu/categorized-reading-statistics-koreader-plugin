local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextWidget = require("ui/widget/textwidget")

local Format = require("views/format")

local WeeklyBarsView = {}

local FONT_SCALE = 1.35
local BAR_HEIGHT = 20
local BAR_TOP_OFFSET = 28
local ROW_GAP = 40
local DAY_GAP = 48
local LABEL_WIDTH = 288
local DURATION_WIDTH = 160
local PADDING = 20
local BUTTON_WIDTH = 108
local BUTTON_HEIGHT = 60
local BUTTON_GAP = 16
local HEADER_GAP = 24
local WEEK_INFO_HEIGHT = 36
local DAY_HEADER_HEIGHT = 56
local NO_ACTIVITY_HEIGHT = 32
local PREVIOUS_BUTTON_WIDTH = 132
local NEXT_BUTTON_WIDTH = 96

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

local function scaled_font_size(size)
    return math.floor(((tonumber(size) or 16) * FONT_SCALE) + 0.5)
end

local function text_widget(text, size)
    return TextWidget:new{
        text = tostring(text or ""),
        face = Font:getFace("cfont", scaled_font_size(size or 16)),
    }
end

local function paint_text(bb, text, x, y, size)
    local widget = text_widget(text, size)
    widget:paintTo(bb, x, y)
    local dimen = widget:getSize()
    return dimen.w, dimen.h
end

local function crop_to_width(text, max_width, size)
    text = tostring(text or "")
    if max_width <= 0 then
        return ""
    end

    local widget = text_widget(text, size)
    if widget:getSize().w <= max_width then
        return text
    end

    local low = 0
    local high = #text
    while low < high do
        local mid = math.ceil((low + high) / 2)
        widget = text_widget(text:sub(1, mid), size)
        if widget:getSize().w <= max_width then
            low = mid
        else
            high = mid - 1
        end
    end

    return text:sub(1, low)
end

local function paint_button(bb, text, x, y, w, h)
    paint_border(bb, x, y, w, h)
    paint_text(bb, text, x + 8, y + 6, 14)
end

local function point_in_box(pos, box)
    return pos
        and pos.x >= box.x
        and pos.x <= box.x + box.w
        and pos.y >= box.y
        and pos.y <= box.y + box.h
end

local function ordered_categories(report, categories)
    local rows = {}
    local seen = {}

    for _, category in ipairs(report.category_order or {}) do
        local row = categories and categories[category]
        if row then
            table.insert(rows, row)
            seen[category] = true
        end
    end

    for category, row in pairs(categories or {}) do
        if not seen[category] then
            table.insert(rows, row)
        end
    end

    table.sort(rows, function(a, b)
        if a.duration == b.duration then
            return a.label < b.label
        end
        return a.duration > b.duration
    end)

    return rows
end

local function max_day_category_duration(week)
    local max_duration = 0
    for _, categories in pairs(week.day_categories or {}) do
        for _, category in pairs(categories) do
            max_duration = math.max(max_duration, category.duration)
        end
    end
    return max_duration
end

local WeeklyBarsWidget = InputContainer:extend{
    name = "categorized_stats_weekly_bars",
}

function WeeklyBarsWidget:init()
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

function WeeklyBarsWidget:add_hitbox(action, x, y, w, h, value)
    table.insert(self.hitboxes, {
        action = action,
        x = x,
        y = y,
        w = w,
        h = h,
        value = value,
    })
end

function WeeklyBarsWidget:paintTo(bb, x, y)
    self.hitboxes = {}
    x = x or 0
    y = y or 0

    paint_rect(bb, x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)

    local week = self.report.weekly.weeks[self.week_key]
    local content_width = self.dimen.w - (PADDING * 2)
    local bar_width = math.max(1, content_width - LABEL_WIDTH - DURATION_WIDTH - 12)
    local cursor_y = y + PADDING

    paint_text(bb, "Weekly View", x + PADDING, cursor_y + 4, 20)
    local close_x = x + self.dimen.w - PADDING - BUTTON_WIDTH
    paint_button(bb, "Close", close_x, cursor_y, BUTTON_WIDTH, BUTTON_HEIGHT)
    self:add_hitbox("close", close_x, cursor_y, BUTTON_WIDTH, BUTTON_HEIGHT)
    cursor_y = cursor_y + BUTTON_HEIGHT + HEADER_GAP

    paint_text(bb, "Week of " .. self.week_key, x + PADDING, cursor_y, 16)
    cursor_y = cursor_y + WEEK_INFO_HEIGHT + HEADER_GAP

    local nav_y = cursor_y
    if self.previous_week_key then
        paint_button(bb, "< Previous", x + PADDING, nav_y, PREVIOUS_BUTTON_WIDTH, BUTTON_HEIGHT)
        self:add_hitbox("previous_week", x + PADDING, nav_y, PREVIOUS_BUTTON_WIDTH, BUTTON_HEIGHT)
    end
    if self.next_week_key then
        local next_x = x + PADDING + PREVIOUS_BUTTON_WIDTH + BUTTON_GAP
        paint_button(bb, "Next >", next_x, nav_y, NEXT_BUTTON_WIDTH, BUTTON_HEIGHT)
        self:add_hitbox("next_week", next_x, nav_y, NEXT_BUTTON_WIDTH, BUTTON_HEIGHT)
    end
    cursor_y = cursor_y + BUTTON_HEIGHT + HEADER_GAP

    local max_duration = max_day_category_duration(week)
    if max_duration == 0 then
        paint_text(bb, "No reading activity found for this week.", x + PADDING, cursor_y, 16)
        return
    end

    for _, day in ipairs(week.days) do
        local day_start_y = cursor_y
        paint_text(bb, "Date: " .. day.date, x + PADDING, cursor_y, 16)
        cursor_y = cursor_y + DAY_HEADER_HEIGHT

        local rows = ordered_categories(self.report, week.day_categories[day.date])
        if #rows == 0 then
            paint_text(bb, "No reading activity.", x + PADDING + 12, cursor_y, 14)
            cursor_y = cursor_y + NO_ACTIVITY_HEIGHT
        else
            for _, category in ipairs(rows) do
                local label_x = x + PADDING + 12
                local bar_x = label_x + LABEL_WIDTH
                local duration_x = bar_x + bar_width + 8
                local fill_width = math.max(1, math.floor(category.duration / max_duration * bar_width + 0.5))
                local inner_fill_width = math.max(1, math.min(bar_width - 2, fill_width - 2))

                local category_label = crop_to_width(category.label .. ":", LABEL_WIDTH - 8, 14)
                paint_text(bb, category_label, label_x, cursor_y - 2, 14)
                paint_border(bb, bar_x, cursor_y + BAR_TOP_OFFSET, bar_width, BAR_HEIGHT)
                paint_rect(bb, bar_x + 1, cursor_y + BAR_TOP_OFFSET + 1, inner_fill_width, BAR_HEIGHT - 2)
                paint_text(bb, Format.seconds(category.duration), duration_x, cursor_y - 2, 14)

                cursor_y = cursor_y + BAR_HEIGHT + ROW_GAP
            end
        end

        local day_height = cursor_y - day_start_y
        self:add_hitbox("open_day", x + PADDING, day_start_y, content_width, day_height, day.date)
        cursor_y = cursor_y + DAY_GAP
    end
end

function WeeklyBarsWidget:handle_tap(ges)
    local pos = ges and (ges.pos or ges)
    for _, box in ipairs(self.hitboxes or {}) do
        if point_in_box(pos, box) then
            if box.action == "open_day" and self.on_select_day then
                self.on_select_day(box.value, self.week_key)
                return true
            elseif box.action == "close" and self.on_close then
                self.on_close()
                return true
            elseif box.action == "previous_week" and self.on_previous_week then
                self.on_previous_week()
                return true
            elseif box.action == "next_week" and self.on_next_week then
                self.on_next_week()
                return true
            end
        end
    end
end

function WeeklyBarsWidget:onTapSelect(_, ges)
    return self:handle_tap(ges)
end

function WeeklyBarsWidget:onTap(_, ges)
    return self:handle_tap(ges)
end

function WeeklyBarsView.latest_week_key(report)
    return report.weekly.week_order[1]
end

function WeeklyBarsView.next_week_key(report, week_key)
    for index, key in ipairs(report.weekly.week_order) do
        if key == week_key then
            return report.weekly.week_order[index - 1]
        end
    end
end

function WeeklyBarsView.previous_week_key(report, week_key)
    for index, key in ipairs(report.weekly.week_order) do
        if key == week_key then
            return report.weekly.week_order[index + 1]
        end
    end
end

function WeeklyBarsView.newWidget(args)
    return WeeklyBarsWidget:new(args)
end

function WeeklyBarsView.render(report, week_key)
    week_key = week_key or WeeklyBarsView.latest_week_key(report)

    local lines = {
        "Weekly View",
        "",
    }

    if not week_key then
        table.insert(lines, "No reading activity found.")
        return table.concat(lines, "\n")
    end

    local week = report.weekly.weeks[week_key]
    if not week then
        table.insert(lines, "Selected week was not found.")
        return table.concat(lines, "\n")
    end

    table.insert(lines, "Week of " .. week.week_key)
    table.insert(lines, "")

    for _, day in ipairs(week.days) do
        table.insert(lines, "Date: " .. day.date)
        for _, category in ipairs(ordered_categories(report, week.day_categories[day.date])) do
            table.insert(lines, string.format(
                "%s: [%s] %s",
                category.label,
                Format.bar(category.duration, max_day_category_duration(week), 16),
                Format.seconds(category.duration)
            ))
        end
        table.insert(lines, "")
    end

    return table.concat(lines, "\n")
end

return WeeklyBarsView
