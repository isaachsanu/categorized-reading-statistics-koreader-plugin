local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local TextViewer = require("ui/widget/textviewer")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local _ = require("gettext")

local Aggregator = require("aggregator")
local CollectionReader = require("collection_reader")
local Config = require("config")
local DailyLogView = require("views/daily_log")
local DailyTimelineView = require("views/daily_timeline")
local DailyTimelineDetailPopupView = require("views/daily_timeline_detail_popup")
local GlobalStatsView = require("views/global_stats")
local StatsReader = require("stats_reader")
local UnknownItemsView = require("views/unknown_items")
local WeeklyBarsView = require("views/weekly_bars")

local CategorizedStats = WidgetContainer:extend{
    name = "categorized_stats",
    is_doc_only = false,
}

function CategorizedStats:onDispatcherRegisterActions()
    Dispatcher:registerAction("categorized_stats_global", {
        category = "none",
        event = "ShowCategorizedStatsGlobal",
        title = _("Categorized stats: global"),
        general = true,
    })
    Dispatcher:registerAction("categorized_stats_daily", {
        category = "none",
        event = "ShowCategorizedStatsDaily",
        title = _("Categorized stats: daily log"),
        general = true,
    })
    Dispatcher:registerAction("categorized_stats_weekly", {
        category = "none",
        event = "ShowCategorizedStatsWeekly",
        title = _("Categorized stats: weekly view"),
        general = true,
    })
    Dispatcher:registerAction("categorized_stats_daily_timeline", {
        category = "none",
        event = "ShowCategorizedStatsDailyTimeline",
        title = _("Categorized stats: daily timeline"),
        general = true,
    })
    Dispatcher:registerAction("categorized_stats_unknown", {
        category = "none",
        event = "ShowCategorizedStatsUnknown",
        title = _("Categorized stats: unknown items"),
        general = true,
    })
end

function CategorizedStats:init()
    self.config = Config:get()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function CategorizedStats:addToMainMenu(menu_items)
    menu_items.categorized_stats = {
        text = _("Categorized Reading Stats"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text = _("Global stats"),
                callback = function()
                    self.ui:handleEvent(Event:new("ShowCategorizedStatsGlobal"))
                end,
            },
            {
                text = _("Daily log"),
                callback = function()
                    self.ui:handleEvent(Event:new("ShowCategorizedStatsDaily"))
                end,
            },
            {
                text = _("Weekly view"),
                callback = function()
                    self.ui:handleEvent(Event:new("ShowCategorizedStatsWeekly"))
                end,
            },
            {
                text = _("Daily timeline"),
                callback = function()
                    self.ui:handleEvent(Event:new("ShowCategorizedStatsDailyTimeline"))
                end,
            },
            {
                text = _("Unknown items"),
                callback = function()
                    self.ui:handleEvent(Event:new("ShowCategorizedStatsUnknown"))
                end,
            },
        },
    }
end

function CategorizedStats:buildReport()
    local books, book_err = StatsReader:read_books(self.config.statistics_db_path)
    if not books then
        return nil, book_err
    end

    local daily_rows, daily_err = StatsReader:read_daily_log(self.config.statistics_db_path)
    if not daily_rows then
        return nil, daily_err
    end

    local activity_rows, activity_err = StatsReader:read_activity(self.config.statistics_db_path)
    if not activity_rows then
        return nil, activity_err
    end

    local collection_index = CollectionReader:read()
    return Aggregator.build(books, daily_rows, collection_index, self.config, activity_rows)
end

function CategorizedStats:showText(title, text)
    UIManager:show(TextViewer:new{
        title = title,
        text = text,
        text_type = "code",
    })
end

function CategorizedStats:showReport(title, render)
    local ok, report_or_err = pcall(function()
        local report, err = self:buildReport()
        if not report then
            error(err)
        end
        return report
    end)

    if not ok then
        logger.warn("CategorizedStats:", report_or_err)
        UIManager:show(InfoMessage:new{
            text = _("Could not load categorized statistics."),
        })
        return
    end

    self:showText(title, render(report_or_err))
end

function CategorizedStats:loadReportOrShowError()
    local ok, report_or_err = pcall(function()
        local report, err = self:buildReport()
        if not report then
            error(err)
        end
        return report
    end)

    if not ok then
        logger.warn("CategorizedStats:", report_or_err)
        UIManager:show(InfoMessage:new{
            text = _("Could not load categorized statistics."),
        })
        return nil
    end

    return report_or_err
end

function CategorizedStats:showWeeklyView(week_key)
    local report = self:loadReportOrShowError()
    if not report then
        return
    end

    week_key = week_key or WeeklyBarsView.latest_week_key(report)
    if not week_key then
        self:showText(_("Weekly view"), WeeklyBarsView.render(report, week_key))
        return
    end

    local widget
    widget = WeeklyBarsView.newWidget{
        report = report,
        week_key = week_key,
        previous_week_key = WeeklyBarsView.previous_week_key(report, week_key),
        next_week_key = WeeklyBarsView.next_week_key(report, week_key),
        on_close = function()
            UIManager:close(widget)
        end,
        on_previous_week = function()
            self:showWeeklyView(WeeklyBarsView.previous_week_key(report, week_key))
        end,
        on_next_week = function()
            self:showWeeklyView(WeeklyBarsView.next_week_key(report, week_key))
        end,
        on_select_day = function(date, selected_week_key)
            self:showDailyTimeline(date, selected_week_key)
        end,
    }
    UIManager:show(widget)
end

function CategorizedStats:showDailyTimeline(date, return_week_key)
    local report = self:loadReportOrShowError()
    if not report then
        return
    end

    date = date or DailyTimelineView.latest_date(report)

    local widget
    widget = DailyTimelineView.newWidget{
        report = report,
        date = date,
        return_week_key = return_week_key,
        on_close = function()
            UIManager:close(widget)
        end,
        on_back = return_week_key and function()
            self:showWeeklyView(return_week_key)
        end or nil,
        on_select_book = function(book, selected_date)
            self:showDailyTimelineDetail(book, selected_date)
        end,
    }
    UIManager:show(widget)
end

function CategorizedStats:showDailyTimelineDetail(book, date)
    local popup
    popup = DailyTimelineDetailPopupView.newWidget{
        book = book,
        date = date,
        on_close = function()
            UIManager:close(popup)
        end,
    }
    UIManager:show(popup)
end

function CategorizedStats:onShowCategorizedStatsGlobal()
    self:showReport(_("Global stats"), GlobalStatsView.render)
    return true
end

function CategorizedStats:onShowCategorizedStatsDaily()
    self:showReport(_("Daily log"), DailyLogView.render)
    return true
end

function CategorizedStats:onShowCategorizedStatsWeekly()
    self:showWeeklyView()
    return true
end

function CategorizedStats:onShowCategorizedStatsDailyTimeline()
    self:showDailyTimeline()
    return true
end

function CategorizedStats:onShowCategorizedStatsUnknown()
    self:showReport(_("Unknown items"), UnknownItemsView.render)
    return true
end

return CategorizedStats
