local GameTimeConfig = {}

-- 时间配置类型枚举
GameTimeConfig.Type = {
    FIXED_PERIOD = 1,          -- 固定时间段
    DURATION_FROM_START = 2,   -- 从起始时间开始持续N天
    WEEKLY_FIXED_DAY = 3,      -- 每周固定星期几
    AFTER_SERVER_OPEN = 4,     -- 开服后N天内
    DAILY = 5,                 -- 每日固定时段
    WEEKLY = 6,                -- 每周固定时段
    CIRCULAR_FIXED_INTERVAL = 7,  -- 固定间隔循环
    MONTHLY_FIXED_DATE = 8,       -- 每月固定日期
    CUMULATIVE_ONLINE_TIME = 9,   -- 累计在线时长
    SERVER_OPEN_ANNIVERSARY = 10, -- 开服周年/半周年
    HOLIDAY_FIXED = 11,           -- 法定节假日
    CROSS_DAY_CYCLE = 12,         -- 跨天循环
    RANDOM_INTERVAL = 13,         -- 随机间隔
    LEVEL_LOCKED_DAILY = 14,      -- 等级解锁后每日
    SEASON_CYCLE = 15,            -- 赛季循环
    TIMEZONE_ADAPT = 16,          -- 时区适配
    LIMIT_DAILY_TIMES = 17,       -- 每日次数限制+时段
}

-- 全局状态存储
GameTimeConfig.globalState = {
    serverOpenTime = nil,
    playerTimezoneOffset = 0,  -- 玩家时区偏移（小时）
    cumulativeOnlineTime = 0   -- 玩家累计在线时长（秒）
}

-- 核心工具函数：解析多种可读时间格式为时间戳
local function strToTimestamp(timeStr)
    if not timeStr or type(timeStr) ~= "string" then
        return nil
    end

    -- 处理仅时间格式（如"18:00"）：补全当天日期
    if string.find(timeStr, "^%d%d:%d%d") then
        local today = os.date("%Y-%m-%d")
        timeStr = today .. " " .. timeStr
    end

    -- 移除所有分隔符，统一为纯数字串处理
    local cleanStr = string.gsub(timeStr, "[-/: ]", "")

    -- 补全长度
    local len = #cleanStr
    if len == 8 then       -- 仅日期（YYYYMMDD）→ 补全时间为00:00:00
        cleanStr = cleanStr .. "000000"
    elseif len == 10 then  -- YYYYMMDDHH → 补全为YYYYMMDDHH0000
        cleanStr = cleanStr .. "0000"
    elseif len == 12 then  -- YYYYMMDDHHMM → 补全为YYYYMMDDHHMM00
        cleanStr = cleanStr .. "00"
    elseif len ~= 14 then  -- 不符合标准长度
        return nil
    end

    -- 提取年月日时分秒
    local year = tonumber(string.sub(cleanStr, 1, 4))
    local month = tonumber(string.sub(cleanStr, 5, 6))
    local day = tonumber(string.sub(cleanStr, 7, 8))
    local hour = tonumber(string.sub(cleanStr, 9, 10)) or 0
    local min = tonumber(string.sub(cleanStr, 11, 12)) or 0
    local sec = tonumber(string.sub(cleanStr, 13, 14)) or 0

    -- 校验时间合法性
    if not (year and month and day and hour and min and sec) then
        return nil
    end
    if month < 1 or month > 12 then return nil end
    local maxDay = 31
    if month == 2 then
        maxDay = (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0) and 29 or 28
    elseif month == 4 or month == 6 or month == 9 or month == 11 then
        maxDay = 30
    end
    if day < 1 or day > maxDay then return nil end
    if hour < 0 or hour >= 24 then return nil end
    if min < 0 or min >= 60 then return nil end
    if sec < 0 or sec >= 60 then return nil end

    return os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec
    })
end

-- 工具函数：时间戳转可读字符串
local function timestampToStr(timestamp, format)
    if not timestamp then return "invalid time" end
    format = format or "%Y-%m-%d %H:%M:%S"
    return os.date(format, timestamp)
end

-- 工具函数：获取星期几（1=周一，7=周日）
local function getWeekday(timestamp)
    local wday = os.date("%w", timestamp)  -- Lua默认：0=周日，1=周一...6=周六
    return wday == "0" and 7 or tonumber(wday)
end

-- 工具函数：计算两个时间戳的天数差
local function dayDiff(timestamp1, timestamp2)
    return math.floor((timestamp1 - timestamp2) / 86400)
end

-- 工具函数：获取当月日期
local function getMonthDay(timestamp)
    return tonumber(os.date("%d", timestamp))
end

-- 工具函数：转换为玩家时区时间戳
local function toPlayerTimeTimestamp(serverTimestamp)
    return serverTimestamp + GameTimeConfig.globalState.playerTimezoneOffset * 3600
end

-- 初始化配置
function GameTimeConfig.init(openTimeStr, timezoneOffset)
    GameTimeConfig.globalState.serverOpenTime = strToTimestamp(openTimeStr)
    GameTimeConfig.globalState.playerTimezoneOffset = timezoneOffset or 0
    assert(GameTimeConfig.globalState.serverOpenTime, 
        "无效的开服时间格式！支持：2025-10-27 08:30 或 202510270830 等")
end

-- 更新玩家累计在线时长
function GameTimeConfig.updateCumulativeOnlineTime(addedSeconds)
    GameTimeConfig.globalState.cumulativeOnlineTime = GameTimeConfig.globalState.cumulativeOnlineTime + addedSeconds
end

-- 获取开服天数
function GameTimeConfig.getServerOpenDays(checkTime)
    assert(GameTimeConfig.globalState.serverOpenTime, "请先调用init初始化配置")
    checkTime = checkTime or os.time()
    return math.max(0, dayDiff(checkTime, GameTimeConfig.globalState.serverOpenTime))
end

-- 原有配置创建方法
function GameTimeConfig.createFixedPeriod(startTimeStr, endTimeStr)
    local startTs = strToTimestamp(startTimeStr)
    local endTs = strToTimestamp(endTimeStr)
    assert(startTs and endTs and startTs < endTs, 
        "无效的固定时间段！")
    
    return {
        type = GameTimeConfig.Type.FIXED_PERIOD,
        start = startTs,
        ["end"] = endTs,
        startStr = timestampToStr(startTs),
        endStr = timestampToStr(endTs)
    }
end

function GameTimeConfig.createDurationFromStart(startTimeStr, days)
    local startTs = strToTimestamp(startTimeStr)
    assert(startTs and days > 0, 
        "无效的持续时间配置！")
    
    local endTs = startTs + days * 86400
    return {
        type = GameTimeConfig.Type.DURATION_FROM_START,
        start = startTs,
        durationDays = days,
        ["end"] = endTs,
        startStr = timestampToStr(startTs),
        endStr = timestampToStr(endTs)
    }
end

function GameTimeConfig.createWeeklyFixedDay(weekday, startTimeStr, endTimeStr)
    assert(weekday >= 1 and weekday <= 7, "星期几必须在1-7之间")
    
    local startTs = strToTimestamp(startTimeStr)
    local endTs = strToTimestamp(endTimeStr)
    assert(startTs and endTs, 
        "无效的时间格式！")
    
    local startDate = os.date("*t", startTs)
    local endDate = os.date("*t", endTs)
    
    local weekdayMap = {
        [1] = "周一", [2] = "周二", [3] = "周三",
        [4] = "周四", [5] = "周五", [6] = "周六", [7] = "周日"
    }
    local timeDesc = string.format("%s %02d:%02d-%02d:%02d", 
        weekdayMap[weekday], startDate.hour, startDate.min, 
        endDate.hour, endDate.min)
    
    return {
        type = GameTimeConfig.Type.WEEKLY_FIXED_DAY,
        weekday = weekday,
        startHour = startDate.hour,
        startMin = startDate.min,
        endHour = endDate.hour,
        endMin = endDate.min,
        desc = timeDesc
    }
end

function GameTimeConfig.createAfterServerOpen(days)
    assert(GameTimeConfig.globalState.serverOpenTime, "请先调用init初始化配置")
    assert(days > 0, "天数必须大于0")
    
    local startTs = GameTimeConfig.globalState.serverOpenTime
    local endTs = startTs + days * 86400
    return {
        type = GameTimeConfig.Type.AFTER_SERVER_OPEN,
        durationDays = days,
        start = startTs,
        ["end"] = endTs,
        startStr = timestampToStr(startTs),
        endStr = timestampToStr(endTs)
    }
end

function GameTimeConfig.createDaily(startTimeStr, endTimeStr)
    local startTs = strToTimestamp(startTimeStr)
    local endTs = strToTimestamp(endTimeStr)
    assert(startTs and endTs, 
        "无效的每日时间格式！")
    
    local startDate = os.date("*t", startTs)
    local endDate = os.date("*t", endTs)
    
    local timeDesc = string.format("每日 %02d:%02d-%02d:%02d", 
        startDate.hour, startDate.min, endDate.hour, endDate.min)
    
    return {
        type = GameTimeConfig.Type.DAILY,
        startHour = startDate.hour,
        startMin = startDate.min,
        endHour = endDate.hour,
        endMin = endDate.min,
        desc = timeDesc
    }
end

function GameTimeConfig.createWeekly(startWeekday, startTimeStr, endWeekday, endTimeStr)
    assert(startWeekday >= 1 and startWeekday <= 7, "起始星期几必须在1-7之间")
    assert(endWeekday >= 1 and endWeekday <= 7, "结束星期几必须在1-7之间")
    
    local startTs = strToTimestamp(startTimeStr)
    local endTs = strToTimestamp(endTimeStr)
    assert(startTs and endTs, 
        "无效的每周时间格式！")
    
    local startDate = os.date("*t", startTs)
    local endDate = os.date("*t", endTs)
    
    local weekdayMap = {
        [1] = "周一", [2] = "周二", [3] = "周三",
        [4] = "周四", [5] = "周五", [6] = "周六", [7] = "周日"
    }
    local weekDesc = startWeekday == endWeekday 
        and weekdayMap[startWeekday]
        or string.format("%s至%s", weekdayMap[startWeekday], weekdayMap[endWeekday])
    
    local timeDesc = string.format("%s %02d:%02d-%02d:%02d", 
        weekDesc, startDate.hour, startDate.min, endDate.hour, endDate.min)
    
    return {
        type = GameTimeConfig.Type.WEEKLY,
        startWeekday = startWeekday,
        startHour = startDate.hour,
        startMin = startDate.min,
        endWeekday = endWeekday,
        endHour = endDate.hour,
        endMin = endDate.min,
        desc = timeDesc
    }
end

-- 新增场景化配置创建方法
function GameTimeConfig.createCircularFixedInterval(intervalHours, durationMinutes)
    assert(intervalHours > 0 and durationMinutes > 0, "间隔和时长必须大于0")
    return {
        type = GameTimeConfig.Type.CIRCULAR_FIXED_INTERVAL,
        intervalSeconds = intervalHours * 3600,
        durationSeconds = durationMinutes * 60,
        desc = string.format("每%d小时一次，每次%d分钟", intervalHours, durationMinutes)
    }
end

function GameTimeConfig.createMonthlyFixedDate(dateList, startTimeStr, endTimeStr)
    assert(type(dateList) == "table" and #dateList > 0, "日期列表不能为空")
    local startTs = strToTimestamp(startTimeStr)
    local endTs = strToTimestamp(endTimeStr)
    assert(startTs and endTs, "无效的时间格式！")
    
    local startDate = os.date("*t", startTs)
    local endDate = os.date("*t", endTs)
    
    local timeDesc = string.format("每月%s %02d:%02d-%02d:%02d", 
        table.concat(dateList, "、"), startDate.hour, startDate.min, 
        endDate.hour, endDate.min)
    
    return {
        type = GameTimeConfig.Type.MONTHLY_FIXED_DATE,
        dateList = dateList,
        startHour = startDate.hour,
        startMin = startDate.min,
        endHour = endDate.hour,
        endMin = endDate.min,
        desc = timeDesc
    }
end

function GameTimeConfig.createCumulativeOnlineTime(requiredSeconds)
    assert(requiredSeconds > 0, "累计时长必须大于0")
    return {
        type = GameTimeConfig.Type.CUMULATIVE_ONLINE_TIME,
        requiredSeconds = requiredSeconds,
        desc = string.format("累计在线%d秒可参与", requiredSeconds)
    }
end

function GameTimeConfig.createServerOpenAnniversary(targetDays, durationDays)
    assert(GameTimeConfig.globalState.serverOpenTime, "请先调用init初始化配置")
    assert(targetDays > 0 and durationDays > 0, "目标天数和持续天数必须大于0")
    
    local startTs = GameTimeConfig.globalState.serverOpenTime + targetDays * 86400
    local endTs = startTs + durationDays * 86400
    return {
        type = GameTimeConfig.Type.SERVER_OPEN_ANNIVERSARY,
        targetDays = targetDays,
        durationDays = durationDays,
        start = startTs,
        ["end"] = endTs,
        desc = string.format("开服%d天（%d周年），持续%d天", 
            targetDays, targetDays/365, durationDays)
    }
end

function GameTimeConfig.createHolidayFixed(holidayList)
    assert(type(holidayList) == "table" and #holidayList > 0, "节假日列表不能为空")
    local validList = {}
    for _, holiday in ipairs(holidayList) do
        local startTs = strToTimestamp(holiday.startTimeStr)
        local endTs = strToTimestamp(holiday.endTimeStr)
        assert(startTs and endTs and startTs < endTs, "无效的节假日时间配置")
        table.insert(validList, {start = startTs, ["end"] = endTs})
    end
    return {
        type = GameTimeConfig.Type.HOLIDAY_FIXED,
        holidayList = validList,
        desc = string.format("包含%d个节假日时段", #validList)
    }
end

function GameTimeConfig.createCrossDayCycle(startTimeStr, endTimeStr)
    local startTs = strToTimestamp(startTimeStr)
    local endTs = strToTimestamp(endTimeStr)
    assert(startTs and endTs, "无效的时间格式！")
    
    local startDate = os.date("*t", startTs)
    local endDate = os.date("*t", endTs)
    
    local timeDesc = string.format("%02d:%02d-次日%02d:%02d（每日）", 
        startDate.hour, startDate.min, endDate.hour, endDate.min)
    
    return {
        type = GameTimeConfig.Type.CROSS_DAY_CYCLE,
        startHour = startDate.hour,
        startMin = startDate.min,
        endHour = endDate.hour,
        endMin = endDate.min,
        desc = timeDesc
    }
end

function GameTimeConfig.createRandomInterval(maxDailyTimes, durationMinutes, minIntervalHours)
    assert(maxDailyTimes > 0 and durationMinutes > 0 and minIntervalHours > 0, 
        "次数、时长和间隔必须大于0")
    return {
        type = GameTimeConfig.Type.RANDOM_INTERVAL,
        maxDailyTimes = maxDailyTimes,
        durationSeconds = durationMinutes * 60,
        minIntervalSeconds = minIntervalHours * 3600,
        desc = string.format("每天最多%d次，每次%d分钟，间隔≥%d小时", 
            maxDailyTimes, durationMinutes, minIntervalHours)
    }
end

function GameTimeConfig.createLevelLockedDaily(requiredLevel, startTimeStr, endTimeStr)
    assert(requiredLevel > 0, "解锁等级必须大于0")
    local startTs = strToTimestamp(startTimeStr)
    local endTs = strToTimestamp(endTimeStr)
    assert(startTs and endTs, "无效的时间格式！")
    
    local startDate = os.date("*t", startTs)
    local endDate = os.date("*t", endTs)
    
    local timeDesc = string.format("等级≥%d解锁，每日%02d:%02d-%02d:%02d", 
        requiredLevel, startDate.hour, startDate.min, endDate.hour, endDate.min)
    
    return {
        type = GameTimeConfig.Type.LEVEL_LOCKED_DAILY,
        requiredLevel = requiredLevel,
        startHour = startDate.hour,
        startMin = startDate.min,
        endHour = endDate.hour,
        endMin = endDate.min,
        desc = timeDesc
    }
end

function GameTimeConfig.createSeasonCycle(seasonDays, dailyStartTimeStr, dailyEndTimeStr)
    assert(seasonDays > 0, "赛季天数必须大于0")
    local startTs = strToTimestamp(dailyStartTimeStr)
    local endTs = strToTimestamp(dailyEndTimeStr)
    assert(startTs and endTs, "无效的时间格式！")
    
    local startDate = os.date("*t", startTs)
    local endDate = os.date("*t", endTs)
    
    local timeDesc = string.format("%d天一个赛季，每日%02d:%02d-%02d:%02d", 
        seasonDays, startDate.hour, startDate.min, endDate.hour, endDate.min)
    
    return {
        type = GameTimeConfig.Type.SEASON_CYCLE,
        seasonDays = seasonDays,
        startHour = startDate.hour,
        startMin = startDate.min,
        endHour = endDate.hour,
        endMin = endDate.min,
        desc = timeDesc
    }
end

function GameTimeConfig.createTimezoneAdapt(startHour, endHour)
    assert(startHour >= 0 and startHour < 24 and endHour >= 0 and endHour < 24, 
        "小时必须在0-23之间")
    return {
        type = GameTimeConfig.Type.TIMEZONE_ADAPT,
        startHour = startHour,
        endHour = endHour,
        desc = string.format("玩家时区%d:%02d-%d:%02d", 
            startHour, 0, endHour, 0)
    }
end

function GameTimeConfig.createLimitDailyTimes(maxTimes, startTimeStr, endTimeStr)
    assert(maxTimes > 0, "最大次数必须大于0")
    local startTs = strToTimestamp(startTimeStr)
    local endTs = strToTimestamp(endTimeStr)
    assert(startTs and endTs, "无效的时间格式！")
    
    local startDate = os.date("*t", startTs)
    local endDate = os.date("*t", endTs)
    
    local timeDesc = string.format("每日%02d:%02d-%02d:%02d，最多%d次", 
        startDate.hour, startDate.min, endDate.hour, endDate.min, maxTimes)
    
    return {
        type = GameTimeConfig.Type.LIMIT_DAILY_TIMES,
        maxTimes = maxTimes,
        startHour = startDate.hour,
        startMin = startDate.min,
        endHour = endDate.hour,
        endMin = endDate.min,
        desc = timeDesc
    }
end

-- 时间校验核心函数
function GameTimeConfig.isInTime(config, checkTime, extraData)
    checkTime = checkTime or os.time()
    extraData = extraData or {}
    if not config then return false end
    
    if config.type == GameTimeConfig.Type.FIXED_PERIOD then
        return checkTime >= config.start and checkTime <= config["end"]
        
    elseif config.type == GameTimeConfig.Type.DURATION_FROM_START then
        return checkTime >= config.start and checkTime <= config["end"]
        
    elseif config.type == GameTimeConfig.Type.WEEKLY_FIXED_DAY then
        local wday = getWeekday(checkTime)
        if wday ~= config.weekday then
            return false
        end
        
        local date = os.date("*t", checkTime)
        local checkMinutes = date.hour * 60 + date.min
        local startMinutes = config.startHour * 60 + config.startMin
        local endMinutes = config.endHour * 60 + config.endMin
        
        if startMinutes <= endMinutes then
            return checkMinutes >= startMinutes and checkMinutes <= endMinutes
        else
            return checkMinutes >= startMinutes or checkMinutes <= endMinutes
        end
        
    elseif config.type == GameTimeConfig.Type.AFTER_SERVER_OPEN then
        return checkTime >= config.start and checkTime <= config["end"]
        
    elseif config.type == GameTimeConfig.Type.DAILY then
        local date = os.date("*t", checkTime)
        local checkMinutes = date.hour * 60 + date.min
        local startMinutes = config.startHour * 60 + config.startMin
        local endMinutes = config.endHour * 60 + config.endMin
        
        if startMinutes <= endMinutes then
            return checkMinutes >= startMinutes and checkMinutes <= endMinutes
        else
            return checkMinutes >= startMinutes or checkMinutes <= endMinutes
        end
        
    elseif config.type == GameTimeConfig.Type.WEEKLY then
        local wday = getWeekday(checkTime)
        local date = os.date("*t", checkTime)
        local checkMinutes = date.hour * 60 + date.min
        local startMinutes = config.startHour * 60 + config.startMin
        local endMinutes = config.endHour * 60 + config.endMin
        
        if config.startWeekday <= config.endWeekday then
            if wday < config.startWeekday or wday > config.endWeekday then
                return false
            end
            if wday == config.startWeekday and checkMinutes < startMinutes then
                return false
            end
            if wday == config.endWeekday and checkMinutes > endMinutes then
                return false
            end
            return true
        else
            if wday > config.endWeekday and wday < config.startWeekday then
                return false
            end
            if wday == config.startWeekday and checkMinutes < startMinutes then
                return false
            end
            if wday == config.endWeekday and checkMinutes > endMinutes then
                return false
            end
            return true
        end
        
    elseif config.type == GameTimeConfig.Type.CIRCULAR_FIXED_INTERVAL then
        local baseTime = os.time({year=1970, month=1, day=1})  -- 纪元时间作为基准
        local elapsed = checkTime - baseTime
        local cyclePos = elapsed % config.intervalSeconds
        return cyclePos < config.durationSeconds
        
    elseif config.type == GameTimeConfig.Type.MONTHLY_FIXED_DATE then
        local day = getMonthDay(checkTime)
        local isMatchDate = false
        for _, date in ipairs(config.dateList) do
            if date == day then
                isMatchDate = true
                break
            end
        end
        if not isMatchDate then return false end
        
        local date = os.date("*t", checkTime)
        local checkMinutes = date.hour * 60 + date.min
        local startMinutes = config.startHour * 60 + config.startMin
        local endMinutes = config.endHour * 60 + config.endMin
        
        if startMinutes <= endMinutes then
            return checkMinutes >= startMinutes and checkMinutes <= endMinutes
        else
            return checkMinutes >= startMinutes or checkMinutes <= endMinutes
        end
        
    elseif config.type == GameTimeConfig.Type.CUMULATIVE_ONLINE_TIME then
        return GameTimeConfig.globalState.cumulativeOnlineTime >= config.requiredSeconds
        
    elseif config.type == GameTimeConfig.Type.SERVER_OPEN_ANNIVERSARY then
        return checkTime >= config.start and checkTime <= config["end"]
        
    elseif config.type == GameTimeConfig.Type.HOLIDAY_FIXED then
        for _, holiday in ipairs(config.holidayList) do
            if checkTime >= holiday.start and checkTime <= holiday["end"] then
                return true
            end
        end
        return false
        
    elseif config.type == GameTimeConfig.Type.CROSS_DAY_CYCLE then
        local date = os.date("*t", checkTime)
        local checkMinutes = date.hour * 60 + date.min
        local startMinutes = config.startHour * 60 + config.startMin
        local endMinutes = config.endHour * 60 + config.endMin
        
        -- 跨天循环必然是start > end（如23:00 > 02:00）
        return checkMinutes >= startMinutes or checkMinutes <= endMinutes
        
    elseif config.type == GameTimeConfig.Type.RANDOM_INTERVAL then
        -- 随机间隔需要额外记录触发时间，这里简化处理为始终返回true（实际需结合历史记录）
        return true
        
    elseif config.type == GameTimeConfig.Type.LEVEL_LOCKED_DAILY then
        if (extraData.playerLevel or 0) < config.requiredLevel then
            return false
        end
        
        local date = os.date("*t", checkTime)
        local checkMinutes = date.hour * 60 + date.min
        local startMinutes = config.startHour * 60 + config.startMin
        local endMinutes = config.endHour * 60 + config.endMin
        
        if startMinutes <= endMinutes then
            return checkMinutes >= startMinutes and checkMinutes <= endMinutes
        else
            return checkMinutes >= startMinutes or checkMinutes <= endMinutes
        end
        
    elseif config.type == GameTimeConfig.Type.SEASON_CYCLE then
        local openDays = GameTimeConfig.getServerOpenDays(checkTime)
        local seasonNum = math.floor(openDays / config.seasonDays)
        local seasonStart = GameTimeConfig.globalState.serverOpenTime + seasonNum * config.seasonDays * 86400
        local seasonEnd = seasonStart + config.seasonDays * 86400
        
        if checkTime < seasonStart or checkTime >= seasonEnd then
            return false
        end
        
        local date = os.date("*t", checkTime)
        local checkMinutes = date.hour * 60 + date.min
        local startMinutes = config.startHour * 60 + config.startMin
        local endMinutes = config.endHour * 60 + config.endMin
        
        if startMinutes <= endMinutes then
            return checkMinutes >= startMinutes and checkMinutes <= endMinutes
        else
            return checkMinutes >= startMinutes or checkMinutes <= endMinutes
        end
        
    elseif config.type == GameTimeConfig.Type.TIMEZONE_ADAPT then
        local playerTime = toPlayerTimeTimestamp(checkTime)
        local date = os.date("*t", playerTime)
        return date.hour >= config.startHour and date.hour < config.endHour
        
    elseif config.type == GameTimeConfig.Type.LIMIT_DAILY_TIMES then
        if (extraData.usedTimesToday or 0) >= config.maxTimes then
            return false
        end
        
        local date = os.date("*t", checkTime)
        local checkMinutes = date.hour * 60 + date.min
        local startMinutes = config.startHour * 60 + config.startMin
        local endMinutes = config.endHour * 60 + config.endMin
        
        if startMinutes <= endMinutes then
            return checkMinutes >= startMinutes and checkMinutes <= endMinutes
        else
            return checkMinutes >= startMinutes or checkMinutes <= endMinutes
        end
    end
    
    return false
end

-- 获取配置描述
function GameTimeConfig.getConfigDesc(config)
    if not config then return "无效配置" end
    
    if config.desc then
        return config.desc
    elseif config.startStr and config.endStr then
        return string.format("%s 至 %s", config.startStr, config.endStr)
    else
        return "未定义描述"
    end
end

-- 导出工具函数
GameTimeConfig.utils = {
    strToTimestamp = strToTimestamp,
    timestampToStr = timestampToStr,
    getWeekday = getWeekday,
    dayDiff = dayDiff
}

return GameTimeConfig


-- 测试代码
local GameTimeConfig = require("GameTimeConfig")
GameTimeConfig.init("202501010800", 8) -- 开服时间+玩家时区偏移（东8区）

-- 新增配置示例
local every2Hour = GameTimeConfig.createCircularFixedInterval(2, 30) -- 每2小时一次，每次30分钟
local monthly1And15 = GameTimeConfig.createMonthlyFixedDate({1,15}, "202501011000", "202501012200") -- 每月1/15号10-22点
local need2HourOnline = GameTimeConfig.createCumulativeOnlineTime(7200) -- 累计在线2小时
local anniversary365 = GameTimeConfig.createServerOpenAnniversary(365, 7) -- 开服1周年，持续7天
local springFestival = GameTimeConfig.createHolidayFixed({
    {startTimeStr="202501290000", endTimeStr="202502042359"}
}) -- 春节活动
local crossDay = GameTimeConfig.createCrossDayCycle("202501012300", "202501010200") -- 23点-次日2点
local randomDaily = GameTimeConfig.createRandomInterval(3, 60, 4) -- 每天最多3次，每次1小时，间隔≥4小时
local level30Daily = GameTimeConfig.createLevelLockedDaily(30, "202501011900", "202501012100") -- 30级解锁，每天19-21点
local season90Days = GameTimeConfig.createSeasonCycle(90, "202501010500", "202501012359") -- 90天赛季，每日5点-24点
local timezone18To20 = GameTimeConfig.createTimezoneAdapt(18, 20) -- 玩家时区18-20点
local daily3Times = GameTimeConfig.createLimitDailyTimes(3, "202501011000", "202501012200") -- 10-22点，最多3次

-- 检查示例
print("是否在每2小时循环内:", GameTimeConfig.isInTime(every2Hour))
print("是否满足累计在线2小时:", GameTimeConfig.isInTime(need2HourOnline))
print("30级玩家是否可参与每日活动:", GameTimeConfig.isInTime(level30Daily, nil, {playerLevel=30}))
print("玩家时区是否18-20点:", GameTimeConfig.isInTime(timezone18To20))
print("今日是否还能参与（已用2次）:", GameTimeConfig.isInTime(daily3Times, nil, {usedTimesToday=2}))