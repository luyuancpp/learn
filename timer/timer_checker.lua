-- 定义 s_time_checker 类（假设使用类似 middleclass 的 class 函数）
local s_time_checker = class("s_time_checker")

-- 构造函数：初始化时间记录
function s_time_checker:ctor()
    self.last_sec = nil  -- 秒级时间戳（os.time()）
    self.last_ms = nil  -- 毫秒级时间戳（os.clock()*1000）
end

-- 记录当前时间（同时更新秒级和毫秒级基准）
function s_time_checker:record()
    self.last_sec = os.time()
    self.last_ms = os.clock() * 1000
end

-- 获取当前与上次记录的秒级间隔（返回数值，未记录则返回nil）
function s_time_checker:get_interval_sec()
    if not self.last_sec then
        return nil
    end
    return os.time() - self.last_sec
end

-- 获取当前与上次记录的毫秒级间隔（返回数值，未记录则返回nil）
function s_time_checker:get_interval_ms()
    if not self.last_ms then
        return nil
    end
    return os.clock() * 1000 - self.last_ms
end

-- 判断是否小于指定秒数
function s_time_checker:is_less_than_sec(threshold_sec)
    if type(threshold_sec) ~= "number" or threshold_sec <= 0 then
        error("阈值必须是正数（秒）")
    end
    local interval = self:get_interval_sec()
    return interval ~= nil and interval < threshold_sec or false
end

-- 判断是否小于指定毫秒数
function s_time_checker:is_less_than_ms(threshold_ms)
    if type(threshold_ms) ~= "number" or threshold_ms <= 0 then
        error("阈值必须是正数（毫秒）")
    end
    local interval = self:get_interval_ms()
    return interval ~= nil and interval < threshold_ms or false
end

-- 重置计时
function s_time_checker:reset()
    self.last_sec = nil
    self.last_ms = nil
end

-- 使用示例（实例化类并调用）
local checker = s_time_checker:new()  -- 创建实例

checker:record()
print("首次记录后：")
print("  秒级间隔：", checker:get_interval_sec())  -- 0
print("  毫秒级间隔：", checker:get_interval_ms())  -- ~0

-- 等待1.2秒
local start = os.clock()
while os.clock() - start < 1.2 do end

print("\n1.2秒后：")
print("  秒级间隔：", checker:get_interval_sec())  -- 1（整数秒）
print("  毫秒级间隔：", checker:get_interval_ms())  -- ~1200（精确值）
print("  是否小于2秒：", checker:is_less_than_sec(2))  -- true
print("  是否小于1000毫秒：", checker:is_less_than_ms(1000))  -- false