local s_game_time_config = require("s_game_time_config")

-- 初始化：开服时间2025年1月1日8:00，玩家时区东8区（+8）
s_game_time_config.init("202501010800", 8)

-- 1. 固定时间段（如春节活动：2025-01-29至2025-02-04）
local fixed_period = s_game_time_config.create_fixed_period(
    "2025-01-29 00:00", 
    "2025-02-04 23:59"
)
print("[1] 固定时间段配置描述：", s_game_time_config.get_config_desc(fixed_period))
print("   是否在2025-02-01范围内：", s_game_time_config.is_in_time(fixed_period, s_game_time_config.utils.str_to_timestamp("202502011200")))

-- 2. 从起始时间持续N天（如新版本活动：2025-03-15开始持续7天）
local duration_from_start = s_game_time_config.create_duration_from_start(
    "202503150500", 
    7
)
print("\n[2] 持续时间配置描述：", s_game_time_config.get_config_desc(duration_from_start))
print("   活动结束时间：", s_game_time_config.utils.timestamp_to_str(duration_from_start["end"]))

-- 3. 每周固定星期几（如每周三晚8点-10点双倍掉落）
local weekly_fixed_day = s_game_time_config.create_weekly_fixed_day(
    3,  -- 周三（1=周一，7=周日）
    "202501012000", 
    "202501012200"
)
print("\n[3] 每周固定日配置描述：", s_game_time_config.get_config_desc(weekly_fixed_day))
print("   周三21:00是否在范围内：", s_game_time_config.is_in_time(weekly_fixed_day, s_game_time_config.utils.str_to_timestamp("202501082100")))

-- 4. 开服后N天内（如开服前3天新手保护）
local after_server_open = s_game_time_config.create_after_server_open(3)
print("\n[4] 开服后配置描述：", s_game_time_config.get_config_desc(after_server_open))
print("   开服第2天是否在范围内：", s_game_time_config.is_in_time(after_server_open, s_game_time_config.utils.str_to_timestamp("202501030000")))

-- 5. 每日固定时段（如每日12:00-14:00签到奖励）
local daily = s_game_time_config.create_daily(
    "12:00", 
    "14:00"
)
print("\n[5] 每日时段配置描述：", s_game_time_config.get_config_desc(daily))
print("   每天13:30是否在范围内：", s_game_time_config.is_in_time(daily, s_game_time_config.utils.str_to_timestamp("202501011330")))

-- 6. 每周固定时段（如每周五至周日晚7点-9点活动）
local weekly = s_game_time_config.create_weekly(
    5,  -- 周五
    "19:00", 
    7,  -- 周日
    "21:00"
)
print("\n[6] 每周时段配置描述：", s_game_time_config.get_config_desc(weekly))
print("   周六18:30是否在范围内：", s_game_time_config.is_in_time(weekly, s_game_time_config.utils.str_to_timestamp("202501111830")))

-- 7. 固定间隔循环（如每2小时刷新一次BOSS，持续30分钟）
local circular_fixed_interval = s_game_time_config.create_circular_fixed_interval(2, 30)
print("\n[7] 固定间隔配置描述：", s_game_time_config.get_config_desc(circular_fixed_interval))
print("   当前时间是否在循环内：", s_game_time_config.is_in_time(circular_fixed_interval))

-- 8. 每月固定日期（如每月1日和15日的会员福利）
local monthly_fixed_date = s_game_time_config.create_monthly_fixed_date(
    {1, 15},  -- 每月1日和15日
    "00:00", 
    "23:59"
)
print("\n[8] 每月固定日配置描述：", s_game_time_config.get_config_desc(monthly_fixed_date))
print("   1月15日是否在范围内：", s_game_time_config.is_in_time(monthly_fixed_date, s_game_time_config.utils.str_to_timestamp("202501151200")))

-- 9. 累计在线时长（如累计在线2小时领取奖励）
local cumulative_online_time = s_game_time_config.create_cumulative_online_time(7200)  -- 7200秒=2小时
print("\n[9] 累计在线配置描述：", s_game_time_config.get_config_desc(cumulative_online_time))
s_game_time_config.update_cumulative_online_time(3600)  -- 增加1小时在线时间
print("   在线1小时是否满足：", s_game_time_config.is_in_time(cumulative_online_time))
s_game_time_config.update_cumulative_online_time(3600)  -- 再增加1小时
print("   在线2小时是否满足：", s_game_time_config.is_in_time(cumulative_online_time))

-- 10. 开服周年庆（如开服365天周年庆，持续7天）
local server_open_anniversary = s_game_time_config.create_server_open_anniversary(365, 7)
print("\n[10] 开服周年配置描述：", s_game_time_config.get_config_desc(server_open_anniversary))
print("   周年庆开始时间：", s_game_time_config.utils.timestamp_to_str(server_open_anniversary.start))

-- 11. 法定节假日（如包含春节和国庆节的活动）
local holiday_fixed = s_game_time_config.create_holiday_fixed({
    {start_time_str = "202501290000", end_time_str = "202502042359"},  -- 春节
    {start_time_str = "202510010000", end_time_str = "202510072359"}   -- 国庆
})
print("\n[11] 节假日配置描述：", s_game_time_config.get_config_desc(holiday_fixed))
print("   2025-10-03是否在节假日内：", s_game_time_config.is_in_time(holiday_fixed, s_game_time_config.utils.str_to_timestamp("202510031200")))

-- 12. 跨天循环（如每晚23点至次日2点的夜间活动）
local cross_day_cycle = s_game_time_config.create_cross_day_cycle(
    "23:00", 
    "02:00"
)
print("\n[12] 跨天循环配置描述：", s_game_time_config.get_config_desc(cross_day_cycle))
print("   凌晨1点是否在范围内：", s_game_time_config.is_in_time(cross_day_cycle, s_game_time_config.utils.str_to_timestamp("202501010100")))

-- 13. 随机间隔（如每天最多3次随机事件，每次1小时，间隔至少4小时）
local random_interval = s_game_time_config.create_random_interval(3, 60, 4)
print("\n[13] 随机间隔配置描述：", s_game_time_config.get_config_desc(random_interval))
print("   随机事件配置是否有效：", s_game_time_config.is_in_time(random_interval))  -- 实际需结合历史记录

-- 14. 等级解锁后每日（如30级解锁的每日副本，19:00-21:00开放）
local level_locked_daily = s_game_time_config.create_level_locked_daily(
    30,  -- 解锁等级
    "19:00", 
    "21:00"
)
print("\n[14] 等级解锁每日配置描述：", s_game_time_config.get_config_desc(level_locked_daily))
print("   25级玩家是否可参与：", s_game_time_config.is_in_time(level_locked_daily, nil, {player_level = 25}))
print("   30级玩家是否可参与：", s_game_time_config.is_in_time(level_locked_daily, nil, {player_level = 30}))

-- 15. 赛季循环（如90天一个赛季，每日5点-24点开放）
local season_cycle = s_game_time_config.create_season_cycle(
    90,  -- 赛季天数
    "05:00", 
    "23:59"
)
print("\n[15] 赛季循环配置描述：", s_game_time_config.get_config_desc(season_cycle))
print("   开服第100天是否在赛季内：", s_game_time_config.is_in_time(season_cycle, s_game_time_config.utils.str_to_timestamp("202504101200")))

-- 16. 时区适配（如玩家当地时间18:00-20:00的全球活动）
local timezone_adapt = s_game_time_config.create_timezone_adapt(18, 20)
print("\n[16] 时区适配配置描述：", s_game_time_config.get_config_desc(timezone_adapt))
print("   玩家时区19:00是否在范围内：", s_game_time_config.is_in_time(timezone_adapt))

-- 17. 每日次数限制+时段（如每日10:00-22:00可参与，最多3次）
local limit_daily_times = s_game_time_config.create_limit_daily_times(
    3,  -- 最大次数
    "10:00", 
    "22:00"
)
print("\n[17] 每日次数限制配置描述：", s_game_time_config.get_config_desc(limit_daily_times))
print("   已参与2次是否可继续：", s_game_time_config.is_in_time(limit_daily_times, nil, {used_times_today = 2}))
print("   已参与3次是否可继续：", s_game_time_config.is_in_time(limit_daily_times, nil, {used_times_today = 3}))

-- 18. 开服后N天解锁并永久生效（如开服15天后解锁的永久功能）
local after_server_open_permanent = s_game_time_config.create_after_server_open_permanent(15)
print("\n[18] 开服后永久生效配置描述：", s_game_time_config.get_config_desc(after_server_open_permanent))
print("   开服第10天是否解锁：", s_game_time_config.is_in_time(after_server_open_permanent, s_game_time_config.utils.str_to_timestamp("202501110800")))
print("   开服第20天是否解锁：", s_game_time_config.is_in_time(after_server_open_permanent, s_game_time_config.utils.str_to_timestamp("202501210800")))
print("   开服1年后是否有效：", s_game_time_config.is_in_time(after_server_open_permanent, s_game_time_config.utils.str_to_timestamp("202601010800")))