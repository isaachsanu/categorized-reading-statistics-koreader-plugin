local DataStorage = require("datastorage")
local DocSettings = require("docsettings")
local LuaSettings = require("luasettings")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")

local CollectionReader = {}

local function realpath(file)
    local ok, resolved = pcall(ffiUtil.realpath, file)
    return ok and resolved or file
end

local function read_sidecar_checksum(file)
    local ok_has, has_sidecar = pcall(function()
        return DocSettings:hasSidecarFile(file)
    end)
    if not ok_has or not has_sidecar then
        return nil
    end

    local ok_open, settings = pcall(DocSettings.open, DocSettings, file)
    if not ok_open or not settings then
        return nil
    end

    local ok_read, checksum = pcall(function()
        return settings:readSetting("partial_md5_checksum")
    end)
    if ok_read then
        return checksum
    end
end

local function partial_md5(file)
    local checksum = read_sidecar_checksum(file)
    if checksum then
        return checksum
    end

    local ok, computed = pcall(util.partialMD5, file)
    if ok then
        return computed
    end

    logger.warn("CategorizedStats: could not compute partial MD5 for collection item", file)
end

local function append_unique(list, value)
    for _, existing in ipairs(list) do
        if existing == value then
            return
        end
    end
    table.insert(list, value)
end

function CollectionReader:read()
    local collection_file = DataStorage:getSettingsDir() .. "/collection.lua"
    local result = {
        collection_file = collection_file,
        by_md5 = {},
        collection_names = {},
        missing = lfs.attributes(collection_file, "mode") ~= "file",
    }

    if result.missing then
        return result
    end

    local settings = LuaSettings:open(collection_file)
    for collection_name, collection in pairs(settings.data or {}) do
        if type(collection) == "table" then
            table.insert(result.collection_names, collection_name)
            for _, item in ipairs(collection) do
                local file = type(item) == "table" and item.file
                if file then
                    file = realpath(file)
                    local checksum = partial_md5(file)
                    if checksum then
                        local entry = result.by_md5[checksum]
                        if not entry then
                            entry = {
                                collections = {},
                                files = {},
                            }
                            result.by_md5[checksum] = entry
                        end
                        append_unique(entry.collections, collection_name)
                        append_unique(entry.files, file)
                    end
                end
            end
        end
    end

    table.sort(result.collection_names)
    for _, entry in pairs(result.by_md5) do
        table.sort(entry.collections)
    end
    return result
end

return CollectionReader
