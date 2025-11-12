local s_game_time_config = {}

-- 时间配置类型枚举
s_game_time_config.type = {
    fixed_period = 1,          -- 固定时间段
    duration_from_start = 2,   -- 从起始时间开始持续N天
    weekly_fixed_day = 3,      -- 每周固定星期几
    after_server_open = 4,     -- 开服后N天内
    daily = 5,                 -- 每日固定时段
    weekly = 6,                -- 每周固定时段
    circular_fixed_interval = 7,  -- 固定间隔循环
    monthly_fixed_date = 8,       -- 每月固定日期
    cumulative_online_time = 9,   -- 累计在线时长
    server_open_anniversary = 10, -- 开服周年/半周年
    holiday_fixed = 11,           -- 法定节假日
    cross_day_cycle = 12,         -- 跨天循环
    random_interval = 13,         -- 随机间隔
    level_locked_daily = 14,      -- 等级解锁后每日
    season_cycle = 15,            -- 赛季循环
    timezone_adapt = 16,          -- 时区适配
    limit_daily_times = 17,       -- 每日次数限制+时段
    after_server_open_permanent = 18,  -- 开服后N天解锁，永久生效
}

-- 全局状态存储
s_game_time_config.global_state = {
    server_open_time = nil,
    player_timezone_offset = 0,  -- 玩家时区偏移（小时）
    cumulative_online_time = 0   -- 玩家累计在线时长（秒）
}

-- 核心工具函数：解析多种可读时间格式为时间戳
local function str_to_timestamp(time_str)
    if not time_str or type(time_str) ~= "string" then
        return nil
    end

    -- 处理仅时间格式（如"18:00"）：补全当天日期
    if string.find(time_str, "^%d%d:%d%d") then
        local today = os.date("%Y-%m-%d")
        time_str = today .. " " .. time_str
    end

    -- 移除所有分隔符，统一为纯数字串处理
    local clean_str = string.gsub(time_str, "[-/: ]", "")

    -- 补全长度
    local len = #clean_str
    if len == 8 then       -- 仅日期（YYYYMMDD）→ 补全时间为00:00:00
        clean_str = clean_str .. "000000"
    elseif len == 10 then  -- YYYYMMDDHH → 补全为YYYYMMDDHH0000
        clean_str = clean_str .. "0000"
    elseif len == 12 then  -- YYYYMMDDHHMM → 补全为YYYYMMDDHHMM00
        clean_str = clean_str .. "00"
    elseif len ~= 14 then  -- 不符合标准长度
        return nil
    end

    -- 提取年月日时分秒
    local year = tonumber(string.sub(clean_str, 1, 4))
    local month = tonumber(string.sub(clean_str, 5, 6))
    local day = tonumber(string.sub(clean_str, 7, 8))
    local hour = tonumber(string.sub(clean_str, 9, 10)) or 0
    local min = tonumber(string.sub(clean_str, 11, 12)) or 0
    local sec = tonumber(string.sub(clean_str, 13, 14)) or 0

    -- 校验时间合法性
    if not (year and month and day and hour and min and sec) then
        return nil
    end
    if month < 1 or month > 12 then return nil end
    local max_day = 31
    if month == 2 then
        max_day = (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0) and 29 or 28
    elseif month == 4 or month == 6 or month == 9 or month == 11 then
        max_day = 30
    end
    if day < 1 or day > max_day then return nil end
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
local function timestamp_to_str(timestamp, format)
    if not timestamp then return "invalid time" end
    format = format or "%Y-%m-%d %H:%M:%S"
    return os.date(format, timestamp)
end

-- 工具函数：获取星期几（1=周一，7=周日）
local function get_weekday(timestamp)
    local wday = os.date("%w", timestamp)  -- Lua默认：0=周日，1=周一...6=周六
    return wday == "0" and 7 or tonumber(wday)
end

-- 工具函数：计算两个时间戳的天数差
local function day_diff(timestamp1, timestamp2)
    return math.floor((timestamp1 - timestamp2) / 86400)
end

-- 工具函数：获取当月日期
local function get_month_day(timestamp)
    return tonumber(os.date("%d", timestamp))
end

-- 工具函数：转换为玩家时区时间戳
local function to_player_time_timestamp(server_timestamp)
    return server_timestamp + s_game_time_config.global_state.player_timezone_offset * 3600
end

-- 初始化配置
function s_game_time_config.init(open_time_str, timezone_offset)
    s_game_time_config.global_state.server_open_time = str_to_timestamp(open_time_str)
    s_game_time_config.global_state.player_timezone_offset = timezone_offset or 0
    assert(s_game_time_config.global_state.server_open_time, 
        "无效的开服时间格式！支持：2025-10-27 08:30 或 202510270830 等")
end

-- 更新玩家累计在线时长
function s_game_time_config.update_cumulative_online_time(added_seconds)
    s_game_time_config.global_state.cumulative_online_time = s_game_time_config.global_state.cumulative_online_time + added_seconds
end

-- 获取开服天数
function s_game_time_config.get_server_open_days(check_time)
    assert(s_game_time_config.global_state.server_open_time, "请先调用init初始化配置")
    check_time = check_time or os.time()
    return math.max(0, day_diff(check_time, s_game_time_config.global_state.server_open_time))
end

-- 配置创建方法
function s_game_time_config.create_fixed_period(start_time_str, end_time_str)
    local start_ts = str_to_timestamp(start_time_str)
    local end_ts = str_to_timestamp(end_time_str)
    assert(start_ts and end_ts and start_ts < end_ts, 
        "无效的固定时间段！")
    
    return {
        type = s_game_time_config.type.fixed_period,
        start = start_ts,
        ["end"] = end_ts,
        start_str = timestamp_to_str(start_ts),
        end_str = timestamp_to_str(end_ts)
    }
end

function s_game_time_config.create_duration_from_start(start_time_str, days)
    local start_ts = str_to_timestamp(start_time_str)
    assert(start_ts and days > 0, 
        "无效的持续时间配置！")
    
    local end_ts = start_ts + days * 86400
    return {
        type = s_game_time_config.type.duration_from_start,
        start = start_ts,
        duration_days = days,
        ["end"] = end_ts,
        start_str = timestamp_to_str(start_ts),
        end_str = timestamp_to_str(end_ts)
    }
end

function s_game_time_config.create_weekly_fixed_day(weekday, start_time_str, end_time_str)
    assert(weekday >= 1 and weekday <= 7, "星期几必须在1-7之间")
    
    local start_ts = str_to_timestamp(start_time_str)
    local end_ts = str_to_timestamp(end_time_str)
    assert(start_ts and end_ts, 
        "无效的时间格式！")
    
    local start_date = os.date("*t", start_ts)
    local end_date = os.date("*t", end_ts)
    
    local weekday_map = {
        [1] = "周一", [2] = "周二", [3] = "周三",
        [4] = "周四", [5] = "周五", [6] = "周六", [7] = "周日"
    }
    local time_desc = string.format("%s %02d:%02d-%02d:%02d", 
        weekday_map[weekday], start_date.hour, start_date.min, 
        end_date.hour, end_date.min)
    
    return {
        type = s_game_time_config.type.weekly_fixed_day,
        weekday = weekday,
        start_hour = start_date.hour,
        start_min = start_date.min,
        end_hour = end_date.hour,
        end_min = end_date.min,
        desc = time_desc
    }
end

function s_game_time_config.create_after_server_open(days)
    assert(s_game_time_config.global_state.server_open_time, "请先调用init初始化配置")
    assert(days > 0, "天数必须大于0")
    
    local start_ts = s_game_time_config.global_state.server_open_time
    local end_ts = start_ts + days * 86400
    return {
        type = s_game_time_config.type.after_server_open,
        duration_days = days,
        start = start_ts,
        ["end"] = end_ts,
        start_str = timestamp_to_str(start_ts),
        end_str = timestamp_to_str(end_ts)
    }
end

-- 新增：开服后N天解锁，永久生效
function s_game_time_config.create_after_server_open_permanent(unlock_days)
    assert(s_game_time_config.global_state.server_open_time, "请先调用init初始化配置")
    assert(unlock_days >= 0, "解锁天数不能为负数（0表示开服即永久生效）")
    
    local unlock_ts = s_game_time_config.global_state.server_open_time + unlock_days * 86400
    return {
        type = s_game_time_config.type.after_server_open_permanent,
        unlock_days = unlock_days,
        unlock_ts = unlock_ts,
        unlock_str = timestamp_to_str(unlock_ts),
        desc = unlock_days == 0 
            and "开服即永久生效" 
            or string.format("开服%d天后永久生效", unlock_days)
    }
end

function s_game_time_config.create_daily(start_time_str, end_time_str)
    local start_ts = str_to_timestamp(start_time_str)
    local end_ts = str_to_timestamp(end_time_str)
    assert(start_ts and end_ts, 
        "无效的每日时间格式！")
    
    local start_date = os.date("*t", start_ts)
    local end_date = os.date("*t", end_ts)
    
    local time_desc = string.format("每日 %02d:%02d-%02d:%02d", 
        start_date.hour, start_date.min, end_date.hour, end_date.min)
    
    return {
        type = s_game_time_config.type.daily,
        start_hour = start_date.hour,
        start_min = start_date.min,
        end_hour = end_date.hour,
        end_min = end_date.min,
        desc = time_desc
    }
end

function s_game_time_config.create_weekly(start_weekday, start_time_str, end_weekday, end_time_str)
    assert(start_weekday >= 1 and start_weekday <= 7, "起始星期几必须在1-7之间")
    assert(end_weekday >= 1 and end_weekday <= 7, "结束星期几必须在1-7之间")
    
    local start_ts = str_to_timestamp(start_time_str)
    local end_ts = str_to_timestamp(end_time_str)
    assert(start_ts and end_ts, 
        "无效的每周时间格式！")
    
    local start_date = os.date("*t", start_ts)
    local end_date = os.date("*t", end_ts)
    
    local weekday_map = {
        [1] = "周一", [2] = "周二", [3] = "周三",
        [4] = "周四", [5] = "周五", [6] = "周六", [7] = "周日"
    }
    local week_desc = start_weekday == end_weekday 
        and weekday_map[start_weekday]
        or string.format("%s至%s", weekday_map[start_weekday], weekday_map[end_weekday])
    
    local time_desc = string.format("%s %02d:%02d-%02d:%02d", 
        week_desc, start_date.hour, start_date.min, end_date.hour, end_date.min)
    
    return {
        type = s_game_time_config.type.weekly,
        start_weekday = start_weekday,
        start_hour = start_date.hour,
        start_min = start_date.min,
        end_weekday = end_weekday,
        end_hour = end_date.hour,
        end_min = end_date.min,
        desc = time_desc
    }
end

function s_game_time_config.create_circular_fixed_interval(interval_hours, duration_minutes)
    assert(interval_hours > 0 and duration_minutes > 0, "间隔和时长必须大于0")
    return {
        type = s_game_time_config.type.circular_fixed_interval,
        interval_seconds = interval_hours * 3600,
        duration_seconds = duration_minutes * 60,
        desc = string.format("每%d小时一次，每次%d分钟", interval_hours, duration_minutes)
    }
end

function s_game_time_config.create_monthly_fixed_date(date_list, start_time_str, end_time_str)
    assert(type(date_list) == "table" and #date_list > 0, "日期列表不能为空")
    local start_ts = str_to_timestamp(start_time_str)
    local end_ts = str_to_timestamp(end_time_str)
    assert(start_ts and end_ts, "无效的时间格式！")
    
    local start_date = os.date("*t", start_ts)
    local end_date = os.date("*t", end_ts)
    
    local time_desc = string.format("每月%s %02d:%02d-%02d:%02d", 
        table.concat(date_list, "、"), start_date.hour, start_date.min, 
        end_date.hour, end_date.min)
    
    return {
        type = s_game_time_config.type.monthly_fixed_date,
        date_list = date_list,
        start_hour = start_date.hour,
        start_min = start_date.min,
        end_hour = end_date.hour,
        end_min = end_date.min,
        desc = time_desc
    }
end

function s_game_time_config.create_cumulative_online_time(required_seconds)
    assert(required_seconds > 0, "累计时长必须大于0")
    return {
        type = s_game_time_config.type.cumulative_online_time,
        required_seconds = required_seconds,
        desc = string.format("累计在线%d秒可参与", required_seconds)
    }
end

function s_game_time_config.create_server_open_anniversary(target_days, duration_days)
    assert(s_game_time_config.global_state.server_open_time, "请先调用init初始化配置")
    assert(target_days > 0 and duration_days > 0, "目标天数和持续天数必须大于0")
    
    local start_ts = s_game_time_config.global_state.server_open_time + target_days * 86400
    local end_ts = start_ts + duration_days * 86400
    return {
        type = s_game_time_config.type.server_open_anniversary,
        target_days = target_days,
        duration_days = duration_days,
        start = start_ts,
        ["end"] = end_ts,
        desc = string.format("开服%d天（%d周年），持续%d天", 
            target_days, target_days/365, duration_days)
    }
end

function s_game_time_config.create_holiday_fixed(holiday_list)
    assert(type(holiday_list) == "table" and #holiday_list > 0, "节假日列表不能为空")
    local valid_list = {}
    for _, holiday in ipairs(holiday_list) do
        local start_ts = str_to_timestamp(holiday.start_time_str)
        local end_ts = str_to_timestamp(holiday.end_time_str)
        assert(start_ts and end_ts and start_ts < end_ts, "无效的节假日时间配置")
        table.insert(valid_list, {start = start_ts, ["end"] = end_ts})
    end
    return {
        type = s_game_time_config.type.holiday_fixed,
        holiday_list = valid_list,
        desc = string.format("包含%d个节假日时段", #valid_list)
    }
end

function s_game_time_config.create_cross_day_cycle(start_time_str, end_time_str)
    local start_ts = str_to_timestamp(start_time_str)
    local end_ts = str_to_timestamp(end_time_str)
    assert(start_ts and end_ts, "无效的时间格式！")
    
    local start_date = os.date("*t", start_ts)
    local end_date = os.date("*t", end_ts)
    
    local time_desc = string.format("%02d:%02d-次日%02d:%02d（每日）", 
        start_date.hour, start_date.min, end_date.hour, end_date.min)
    
    return {
        type = s_game_time_config.type.cross_day_cycle,
        start_hour = start_date.hour,
        start_min = start_date.min,
        end_hour = end_date.hour,
        end_min = end_date.min,
        desc = time_desc
    }
end

function s_game_time_config.create_random_interval(max_daily_times, duration_minutes, min_interval_hours)
    assert(max_daily_times > 0 and duration_minutes > 0 and min_interval_hours > 0, 
        "次数、时长和间隔必须大于0")
    return {
        type = s_game_time_config.type.random_interval,
        max_daily_times = max_daily_times,
        duration_seconds = duration_minutes * 60,
        min_interval_seconds = min_interval_hours * 3600,
        desc = string.format("每天最多%d次，每次%d分钟，间隔≥%d小时", 
            max_daily_times, duration_minutes, min_interval_hours)
    }
end

function s_game_time_config.create_level_locked_daily(required_level, start_time_str, end_time_str)
    assert(required_level > 0, "解锁等级必须大于0")
    local start_ts = str_to_timestamp(start_time_str)
    local end_ts = str_to_timestamp(end_time_str)
    assert(start_ts and end_ts, "无效的时间格式！")
    
    local start_date = os.date("*t", start_ts)
    local end_date = os.date("*t", end_ts)
    
    local time_desc = string.format("等级≥%d解锁，每日%02d:%02d-%02d:%02d", 
        required_level, start_date.hour, start_date.min, end_date.hour, end_date.min)
    
    return {
        type = s_game_time_config.type.level_locked_daily,
        required_level = required_level,
        start_hour = start_date.hour,
        start_min = start_date.min,
        end_hour = end_date.hour,
        end_min = end_date.min,
        desc = time_desc
    }
end

function s_game_time_config.create_season_cycle(season_days, daily_start_time_str, daily_end_time_str)
    assert(season_days > 0, "赛季天数必须大于0")
    local start_ts = str_to_timestamp(daily_start_time_str)
    local end_ts = str_to_timestamp(daily_end_time_str)
    assert(start_ts and end_ts, "无效的时间格式！")
    
    local start_date = os.date("*t", start_ts)
    local end_date = os.date("*t", end_ts)
    
    local time_desc = string.format("%d天一个赛季，每日%02d:%02d-%02d:%02d", 
        season_days, start_date.hour, start_date.min, end_date.hour, end_date.min)
    
    return {
        type = s_game_time_config.type.season_cycle,
        season_days = season_days,
        start_hour = start_date.hour,
        start_min = start_date.min,
        end_hour = end_date.hour,
        end_min = end_date.min,
        desc = time_desc
    }
end

function s_game_time_config.create_timezone_adapt(start_hour, end_hour)
    assert(start_hour >= 0 and start_hour < 24 and end_hour >= 0 and end_hour < 24, 
        "小时必须在0-23之间")
    return {
        type = s_game_time_config.type.timezone_adapt,
        start_hour = start_hour,
        end_hour = end_hour,
        desc = string.format("玩家时区%d:%02d-%d:%02d", 
            start_hour, 0, end_hour, 0)
    }
end

function s_game_time_config.create_limit_daily_times(max_times, start_time_str, end_time_str)
    assert(max_times > 0, "最大次数必须大于0")
    local start_ts = str_to_timestamp(start_time_str)
    local end_ts = str_to_timestamp(end_time_str)
    assert(start_ts and end_ts, "无效的时间格式！")
    
    local start_date = os.date("*t", start_ts)
    local end_date = os.date("*t", end_ts)
    
    local time_desc = string.format("每日%02d:%02d-%02d:%02d，最多%d次", 
        start_date.hour, start_date.min, end_date.hour, end_date.min, max_times)
    
    return {
        type = s_game_time_config.type.limit_daily_times,
        max_times = max_times,
        start_hour = start_date.hour,
        start_min = start_date.min,
        end_hour = end_date.hour,
        end_min = end_date.min,
        desc = time_desc
    }
end

-- 时间校验核心函数
function s_game_time_config.is_in_time(config, check_time, extra_data)
    check_time = check_time or os.time()
    extra_data = extra_data or {}
    if not config then return false end
    
    if config.type == s_game_time_config.type.fixed_period then
        return check_time >= config.start and check_time <= config["end"]
        
    elseif config.type == s_game_time_config.type.duration_from_start then
        return check_time >= config.start and check_time <= config["end"]
        
    elseif config.type == s_game_time_config.type.weekly_fixed_day then
        local wday = get_weekday(check_time)
        if wday ~= config.weekday then
            return false
        end
        
        local date = os.date("*t", check_time)
        local check_minutes = date.hour * 60 + date.min
        local start_minutes = config.start_hour * 60 + config.start_min
        local end_minutes = config.end_hour * 60 + config.end_min
        
        if start_minutes <= end_minutes then
            return check_minutes >= start_minutes and check_minutes <= end_minutes
        else
            return check_minutes >= start_minutes or check_minutes <= end_minutes
        end
        
    elseif config.type == s_game_time_config.type.after_server_open then
        return check_time >= config.start and check_time <= config["end"]
        
    elseif config.type == s_game_time_config.type.after_server_open_permanent then
        -- 开服后N天解锁，永久生效（只要当前时间晚于解锁时间即生效）
        return check_time >= config.unlock_ts
        
    elseif config.type == s_game_time_config.type.daily then
        local date = os.date("*t", check_time)
        local check_minutes = date.hour * 60 + date.min
        local start_minutes = config.start_hour * 60 + config.start_min
        local end_minutes = config.end_hour * 60 + config.end_min
        
        if start_minutes <= end_minutes then
            return check_minutes >= start_minutes and check_minutes <= end_minutes
        else
            return check_minutes >= start_minutes or check_minutes <= end_minutes
        end
        
    elseif config.type == s_game_time_config.type.weekly then
        local wday = get_weekday(check_time)
        local date = os.date("*t", check_time)
        local check_minutes = date.hour * 60 + date.min
        local start_minutes = config.start_hour * 60 + config.start_min
        local end_minutes = config.end_hour * 60 + config.end_min
        
        if config.start_weekday <= config.end_weekday then
            if wday < config.start_weekday or wday > config.end_weekday then
                return false
            end
            if wday == config.start_weekday and check_minutes < start_minutes then
                return false
            end
            if wday == config.end_weekday and check_minutes > end_minutes then
                return false
            end
            return true
        else
            if wday > config.end_weekday and wday < config.start_weekday then
                return false
            end
            if wday == config.start_weekday and check_minutes < start_minutes then
                return false
            end
            if wday == config.end_weekday and check_minutes > end_minutes then
                return false
            end
            return true
        end
        
    elseif config.type == s_game_time_config.type.circular_fixed_interval then
        local base_time = os.time({year=1970, month=1, day=1})  -- 纪元时间作为基准
        local elapsed = check_time - base_time
        local cycle_pos = elapsed % config.interval_seconds
        return cycle_pos < config.duration_seconds
        
    elseif config.type == s_game_time_config.type.monthly_fixed_date then
        local day = get_month_day(check_time)
        local is_match_date = false
        for _, date in ipairs(config.date_list) do
            if date == day then
                is_match_date = true
                break
            end
        end
        if not is_match_date then return false end
        
        local date = os.date("*t", check_time)
        local check_minutes = date.hour * 60 + date.min
        local start_minutes = config.start_hour * 60 + config.start_min
        local end_minutes = config.end_hour * 60 + config.end_min
        
        if start_minutes <= end_minutes then
            return check_minutes >= start_minutes and check_minutes <= end_minutes
        else
            return check_minutes >= start_minutes or check_minutes <= end_minutes
        end
        
    elseif config.type == s_game_time_config.type.cumulative_online_time then
        return s_game_time_config.global_state.cumulative_online_time >= config.required_seconds
        
    elseif config.type == s_game_time_config.type.server_open_anniversary then
        return check_time >= config.start and check_time <= config["end"]
        
    elseif config.type == s_game_time_config.type.holiday_fixed then
        for _, holiday in ipairs(config.holiday_list) do
            if check_time >= holiday.start and check_time <= holiday["end"] then
                return true
            end
        end
        return false
        
    elseif config.type == s_game_time_config.type.cross_day_cycle then
        local date = os.date("*t", check_time)
        local check_minutes = date.hour * 60 + date.min
        local start_minutes = config.start_hour * 60 + config.start_min
        local end_minutes = config.end_hour * 60 + config.end_min
        
        -- 跨天循环必然是start > end（如23:00 > 02:00）
        return check_minutes >= start_minutes or check_minutes <= end_minutes
        
    elseif config.type == s_game_time_config.type.random_interval then
        -- 随机间隔需要额外记录触发时间，这里简化处理为始终返回true（实际需结合历史记录）
        return true
        
    elseif config.type == s_game_time_config.type.level_locked_daily then
        if (extra_data.player_level or 0) < config.required_level then
            return false
        end
        
        local date = os.date("*t", check_time)
        local check_minutes = date.hour * 60 + date.min
        local start_minutes = config.start_hour * 60 + config.start_min
        local end_minutes = config.end_hour * 60 + config.end_min
        
        if start_minutes <= end_minutes then
            return check_minutes >= start_minutes and check_minutes <= end_minutes
        else
            return check_minutes >= start_minutes or check_minutes <= end_minutes
        end
        
    elseif config.type == s_game_time_config.type.season_cycle then
        local open_days = s_game_time_config.get_server_open_days(check_time)
        local season_num = math.floor(open_days / config.season_days)
        local season_start = s_game_time_config.global_state.server_open_time + season_num * config.season_days * 86400
        local season_end = season_start + config.season_days * 86400
        
        if check_time < season_start or check_time >= season_end then
            return false
        end
        
        local date = os.date("*t", check_time)
        local check_minutes = date.hour * 60 + date.min
        local start_minutes = config.start_hour * 60 + config.start_min
        local end_minutes = config.end_hour * 60 + config.end_min
        
        if start_minutes <= end_minutes then
            return check_minutes >= start_minutes and check_minutes <= end_minutes
        else
            return check_minutes >= start_minutes or check_minutes <= end_minutes
        end
        
    elseif config.type == s_game_time_config.type.timezone_adapt then
        local player_time = to_player_time_timestamp(check_time)
        local date = os.date("*t", player_time)
        return date.hour >= config.start_hour and date.hour < config.end_hour
        
    elseif config.type == s_game_time_config.type.limit_daily_times then
        if (extra_data.used_times_today or 0) >= config.max_times then
            return false
        end
        
        local date = os.date("*t", check_time)
        local check_minutes = date.hour * 60 + date.min
        local start_minutes = config.start_hour * 60 + config.start_min
        local end_minutes = config.end_hour * 60 + config.end_min
        
        if start_minutes <= end_minutes then
            return check_minutes >= start_minutes and check_minutes <= end_minutes
        else
            return check_minutes >= start_minutes or check_minutes <= end_minutes
        end
    end
    
    return false
end

-- 获取配置描述
function s_game_time_config.get_config_desc(config)
    if not config then return "无效配置" end
    
    if config.desc then
        return config.desc
    elseif config.start_str and config.end_str then
        return string.format("%s 至 %s", config.start_str, config.end_str)
    else
        return "未定义描述"
    end
end

-- 导出工具函数
s_game_time_config.utils = {
    str_to_timestamp = str_to_timestamp,
    timestamp_to_str = timestamp_to_str,
    get_weekday = get_weekday,
    day_diff = day_diff
}

return s_game_time_config