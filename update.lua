-- 更新历史数据：按数据类型拆分独立更新函数，按需调用
function s_global_task_mgr.update_history_value(params, global_task_type, target_id, value)
    -- 通用参数校验函数
    local function check_suffix(old_suffix, new_suffix)
        if not old_suffix or not new_suffix then
            s_game_system_log:error(string.format("[check_suffix] invalid suffix: old=%s, new=%s", 
                tostring(old_suffix), tostring(new_suffix)))
            return false
        end
        return true
    end

    -- 1. uint64_t 类型存储更新
    local function update_storage_u64(prefix, old_suffix, new_suffix, change_value)
        if not check_suffix(old_suffix, new_suffix) then return false end
        
        -- 处理旧键
        local old_key = prefix .. tostring(old_suffix)
        local old_val = LUA_API_HUB:si_get_uint64_property(old_key)
        old_val = math.max(old_val - change_value, 0)  -- 确保非负
        LUA_API_HUB:si_set_uint64_property(old_key, old_val)
        
        -- 处理新键
        local new_key = prefix .. tostring(new_suffix)
        local new_val = LUA_API_HUB:si_get_uint64_property(new_key)
        new_val = new_val + change_value
        LUA_API_HUB:si_set_uint64_property(new_key, new_val)
        
        return true, new_key, new_val
    end

    -- 2. int32_t 类型存储更新
    local function update_storage_i32(prefix, old_suffix, new_suffix, change_value)
        if not check_suffix(old_suffix, new_suffix) then return false end
        
        local old_key = prefix .. tostring(old_suffix)
        local old_val = LUA_API_HUB:si_get_int32_property(old_key)
        old_val = old_val - change_value  -- int32允许负数，按需调整边界
        LUA_API_HUB:si_set_int32_property(old_key, old_val)
        
        local new_key = prefix .. tostring(new_suffix)
        local new_val = LUA_API_HUB:si_get_int32_property(new_key)
        new_val = new_val + change_value
        LUA_API_HUB:si_set_int32_property(new_key, new_val)
        
        return true, new_key, new_val
    end

    -- 3. int64_t 类型存储更新
    local function update_storage_i64(prefix, old_suffix, new_suffix, change_value)
        if not check_suffix(old_suffix, new_suffix) then return false end
        
        local old_key = prefix .. tostring(old_suffix)
        local old_val = LUA_API_HUB:si_get_int64_property(old_key)
        old_val = old_val - change_value  -- int64允许负数，按需调整边界
        LUA_API_HUB:si_set_int64_property(old_key, old_val)
        
        local new_key = prefix .. tostring(new_suffix)
        local new_val = LUA_API_HUB:si_get_int64_property(new_key)
        new_val = new_val + change_value
        LUA_API_HUB:si_set_int64_property(new_key, new_val)
        
        return true, new_key, new_val
    end

    -- 4. float 类型存储更新
    local function update_storage_float(prefix, old_suffix, new_suffix, change_value)
        if not check_suffix(old_suffix, new_suffix) then return false end
        
        local old_key = prefix .. tostring(old_suffix)
        local old_val = LUA_API_HUB:si_get_float_property(old_key)
        old_val = old_val - change_value
        LUA_API_HUB:si_set_float_property(old_key, old_val)
        
        local new_key = prefix .. tostring(new_suffix)
        local new_val = LUA_API_HUB:si_get_float_property(new_key)
        new_val = new_val + change_value
        LUA_API_HUB:si_set_float_property(new_key, new_val)
        
        return true, new_key, new_val
    end

    -- 5. double 类型存储更新
    local function update_storage_double(prefix, old_suffix, new_suffix, change_value)
        if not check_suffix(old_suffix, new_suffix) then return false end
        
        local old_key = prefix .. tostring(old_suffix)
        local old_val = LUA_API_HUB:si_get_double_property(old_key)
        old_val = old_val - change_value
        LUA_API_HUB:si_set_double_property(old_key, old_val)
        
        local new_key = prefix .. tostring(new_suffix)
        local new_val = LUA_API_HUB:si_get_double_property(new_key)
        new_val = new_val + change_value
        LUA_API_HUB:si_set_double_property(new_key, new_val)
        
        return true, new_key, new_val
    end

    -- 6. string 类型存储更新（特殊处理：字符串拼接而非数值加减）
    local function update_storage_string(prefix, old_suffix, new_suffix, append_str)
        if not check_suffix(old_suffix, new_suffix) then return false end
        append_str = tostring(append_str)  -- 确保是字符串
        
        -- 旧键：移除旧后缀对应的字符串（示例逻辑，可按需修改）
        local old_key = prefix .. tostring(old_suffix)
        local old_str = LUA_API_HUB:si_get_string_property(old_key)
        local new_old_str = old_str:gsub(append_str .. "|", "")  -- 简单移除匹配内容
        LUA_API_HUB:si_set_string_property(old_key, new_old_str)
        
        -- 新键：追加字符串
        local new_key = prefix .. tostring(new_suffix)
        local new_str = LUA_API_HUB:si_get_string_property(new_key)
        new_str = new_str .. append_str .. "|"  -- 拼接格式示例
        LUA_API_HUB:si_set_string_property(new_key, new_str)
        
        return true, new_key, new_str
    end

    -- 根据任务类型调用对应类型的更新函数
    if global_task_type == enums.global_task_type.player_level_up then
        -- 示例：等级提升用uint64存储，同时记录int32计数和string日志
        local u64_success, u64_key, u64_val = update_storage_u64(
            "player_level_up", 
            params["old_level"], 
            params["new_level"], 
            value
        )
        if u64_success then
            s_game_system_log:info(string.format("player_level_up(u64) change %s %s", u64_key, u64_val))
        end
   elseif global_task_type == enums.global_task_type.player_power_change then
       -- 1. 定义分段单位（每1万战力一个区间）
       local segment_unit = 10000  -- 可根据需求调整（如5000、20000等）
   
       -- 2. 计算旧战力和新战力所属的区间编号（向下取整）
       local old_power = params["old_power"] or 0
       local new_power = params["new_power"] or 0
       -- 处理0战力：避免0/10000=0与10000/10000=1冲突，统一按"实际值//单位"计算
       local old_segment = math.floor(old_power / segment_unit)
       local new_segment = math.floor(new_power / segment_unit)
   
       -- 3. 按区间编号更新数据（替代原始战力值）
       local u64_success, u64_key, u64_val = update_storage_u64(
           "player_power_change_segment",  -- 前缀加_segment区分区间数据
           old_segment,  -- 旧区间编号（如15000→1）
           new_segment,  -- 新区间编号（如25000→2）
           value
       )
       if u64_success then
           s_game_system_log:info(string.format(
               "player_power_change(segment) 单位=%d, 旧区间=%d(旧战力=%d), 新区间=%d(新战力=%d), 变化值=%s", 
               segment_unit, old_segment, old_power, new_segment, new_power, value
           ))
       end
   end
end