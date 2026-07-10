local SQ3 = require("lua-ljsqlite3/init")
local lfs = require("libs/libkoreader-lfs")

local StatsReader = {}

local function close(stmt, conn)
    if stmt and stmt.close then
        stmt:close()
    end
    if conn then
        conn:close()
    end
end

local function fetch_rows(db_path, sql, map_row)
    if lfs.attributes(db_path, "mode") ~= "file" then
        return nil, "Statistics database was not found: " .. db_path
    end

    local conn = SQ3.open(db_path)
    conn:exec("PRAGMA query_only = ON;")

    local ok, stmt_or_err = pcall(conn.prepare, conn, sql)
    if not ok or not stmt_or_err then
        close(nil, conn)
        return nil, "Could not prepare statistics query."
    end

    local stmt = stmt_or_err
    local rows = {}

    while true do
        local ok_step, row = pcall(stmt.step, stmt)
        if not ok_step then
            close(stmt, conn)
            return nil, "Could not read statistics rows."
        end
        if not row then
            break
        end
        table.insert(rows, map_row(row))
    end

    close(stmt, conn)
    return rows
end

function StatsReader:read_books(db_path)
    local sql = [[
        SELECT
            id,
            title,
            authors,
            md5,
            COALESCE(total_read_time, 0),
            COALESCE(total_read_pages, 0)
        FROM book
        ORDER BY lower(COALESCE(title, ''))
    ]]

    return fetch_rows(db_path, sql, function(row)
        return {
            id = tonumber(row[1]),
            title = row[2] or "",
            authors = row[3] or "",
            md5 = row[4],
            total_read_time = tonumber(row[5]) or 0,
            total_read_pages = tonumber(row[6]) or 0,
        }
    end)
end

function StatsReader:read_daily_log(db_path)
    local sql = [[
        SELECT
            strftime('%Y-%m-%d', page_stat.start_time, 'unixepoch', 'localtime'),
            book.id,
            book.title,
            book.authors,
            book.md5,
            SUM(page_stat.duration),
            COUNT(DISTINCT page_stat.page)
        FROM page_stat
        JOIN book ON book.id = page_stat.id_book
        GROUP BY 1, book.id
        ORDER BY 1 DESC, 6 DESC, lower(COALESCE(book.title, ''))
    ]]

    return fetch_rows(db_path, sql, function(row)
        return {
            date = row[1] or "unknown date",
            id = tonumber(row[2]),
            title = row[3] or "",
            authors = row[4] or "",
            md5 = row[5],
            duration = tonumber(row[6]) or 0,
            pages = tonumber(row[7]) or 0,
        }
    end)
end

function StatsReader:read_activity(db_path)
    local sql = [[
        SELECT
            page_stat.start_time,
            COALESCE(page_stat.duration, 0),
            page_stat.page,
            book.id,
            book.title,
            book.authors,
            book.md5
        FROM page_stat
        JOIN book ON book.id = page_stat.id_book
        WHERE COALESCE(page_stat.duration, 0) > 0
        ORDER BY page_stat.start_time ASC, lower(COALESCE(book.title, ''))
    ]]

    return fetch_rows(db_path, sql, function(row)
        return {
            start_time = tonumber(row[1]),
            duration = tonumber(row[2]) or 0,
            page = row[3],
            pages = 1,
            id = tonumber(row[4]),
            title = row[5] or "",
            authors = row[6] or "",
            md5 = row[7],
        }
    end)
end

return StatsReader
