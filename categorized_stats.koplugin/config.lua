local DataStorage = require("datastorage")

local Config = {}

Config.defaults = {
    statistics_db_path = DataStorage:getSettingsDir() .. "/statistics.sqlite3",
    unknown_label = "Unknown",
}

function Config:get()
    return self.defaults
end

return Config
