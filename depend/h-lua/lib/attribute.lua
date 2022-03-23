---@class hattribute 属性系统
hattribute = {
    VAL_TYPE = {
        PLAYER = { "gold_ratio", "lumber_ratio", "exp_ratio", "sell_ratio" },
        INTEGER = {
            "life", "mana", "move", "attack_white", "attack_green",
            "attack_range", "attack_range_acquire",
            "defend_white", "defend_green",
            "str_white", "agi_white", "int_white", "str_green", "agi_green", "int_green"
        },
    },
    ---@private
    RELATION = {
        -- 每一点属性对另一个属性的影响
        -- 需要注意的是三围只能影响common内的大部分参数，natural及effect是无效的
        primary = 0, -- 每点主属性提升0点攻击
        -- 三围属性加成
        str = {
            life = 0, -- 每点力量提升0生命（比如）
        },
        agi = {},
        int = {},
    },
    CURE_FLOOR = 0.05, --生命魔法恢复绝对值小于此值时无效
}

--- 判断是否某种类型的数值设定
---@param field string attribute
---@param valType table VAL_TYPE.?
---@return boolean
hattribute.isValType = function(field, valType)
    if (field == nil or valType == nil) then
        return false
    end
    if (table.includes(valType, field)) then
        return true
    end
    return false
end

--- 设置属性对应的其他属性的影响
--- 例如1点力量+10生命
---@param relation table
hattribute.setRelation = function(relation)
    if (type(relation) == "table") then
        hattribute.RELATION = relation
    end
end

--- 为单位初始化属性系统的对象数据
--- @private
hattribute.init = function(whichUnit)
    local uid = hunit.getId(whichUnit)
    if (uid == nil or his.deleted(whichUnit)) then
        return false
    end
    -- init
    local uSlk = hslk.i2v(uid, "slk")
    local attribute = {
        primary = uSlk.Primary or "STR",
        life = cj.GetUnitState(whichUnit, UNIT_STATE_MAX_LIFE),
        mana = cj.GetUnitState(whichUnit, UNIT_STATE_MAX_MANA),
        move = cj.GetUnitDefaultMoveSpeed(whichUnit),
        defend_white = hjapi.GetUnitState(whichUnit, UNIT_STATE_DEFEND_WHITE),
        attack_range = 100,
        attack_range_acquire = 100,
    }
    if (uSlk.dmgplus1) then
        attribute.attack_white = math.floor(uSlk.dmgplus1)
    end
    if (uSlk.rangeN1) then
        attribute.attack_range = math.floor(uSlk.rangeN1)
    end
    if (uSlk.acquire) then
        attribute.attack_range_acquire = math.floor(uSlk.acquire)
    end
    if ((uSlk.weapsOn == "1" or uSlk.weapsOn == "3") and uSlk.cool1) then
        attribute.attack_space_origin = math.round(uSlk.cool1)
    elseif ((uSlk.weapsOn == "2") and uSlk.cool2) then
        attribute.attack_space_origin = math.round(uSlk.cool2)
    end
    for _, v in ipairs(CONST_ATTR_CONF) do
        if (attribute[v[1]] == nil) then
            if (type(v[3]) == "table") then
                attribute[v[1]] = table.clone(v[3])
            else
                attribute[v[1]] = v[3] or 0
            end
        end
    end
    -- 初始化数据
    hcache.set(whichUnit, CONST_CACHE.ATTR, attribute)
    return true
end

-- 设定属性
--[[
    白字攻击 绿字攻击 攻击间隔
    攻速 攻击范围 主动攻击范围
    力敏智 力敏智(绿)
    白字护甲 绿字护甲
    生命 魔法 +恢复
    移动力 ?率
    type(data) == table
    data = { 支持 加/减/乘/除/等
        life = '+100',
        mana = '-100',
        life_back = '*100',
        mana_back = '/100',
        move = '=100',
    }
    during = 0.0 大于0生效；小于等于0时无限持续时间
]]
--- @private
--- @return nil|string buffKey
hattribute.setHandle = function(whichUnit, attr, opr, val, during)
    local valType = type(val)
    local params = hattribute.get(whichUnit)
    if (params == nil) then
        return
    end
    if (params[attr] == nil) then
        return
    end
    -- 机智转接 smart link~
    if (hattributeSetter.smart[attr] ~= nil) then
        attr = hattributeSetter.smart[attr]
    end
    local buffKey
    local diff = 0
    if (valType == "number") then
        if (opr == "+") then
            diff = val
        elseif (opr == "-") then
            diff = -val
        elseif (opr == "*") then
            diff = params[attr] * val - params[attr]
        elseif (opr == "/" and val ~= 0) then
            diff = params[attr] / val - params[attr]
        elseif (opr == "=") then
            diff = val - params[attr]
        end
        --部分属性取整处理，否则失真
        if (hattribute.isValType(attr, hattribute.VAL_TYPE.INTEGER) and diff ~= 0) then
            local dts = hattributeSetter.getDecimalTemporaryStorage(whichUnit, attr)
            local diffI, diffF = math.modf(diff)
            local dtsI, dtsF = math.modf(dts)
            diff = diffI + dtsI
            dts = dtsF + diffF
            if (dts < 0) then
                -- 归0补正
                dts = 1 + dts
                diff = diff - 1
            elseif (math.abs(dts) >= 1) then
                -- 破1退1
                dtsI, dtsF = math.modf(dts)
                diff = diffI + dtsI
                dts = dtsF
            end
            hattributeSetter.setDecimalTemporaryStorage(whichUnit, attr, dts)
        end
        if (diff ~= 0) then
            local currentVal = params[attr]
            local futureVal = currentVal + diff
            if (during > 0) then
                local groupKey = 'attr.' .. attr .. '+'
                if (diff < 0) then
                    groupKey = 'attr.' .. attr .. '-'
                end
                params[attr] = futureVal
                htime.setTimeout(during, function()
                    hattribute.setHandle(whichUnit, attr, "-", diff, 0)
                end)
            else
                params[attr] = futureVal
            end
            -- 关联属性
            hattributeSetter.relation(whichUnit, attr, diff)
            if (attr == "life") then
                -- 最大生命值[JAPI+]
                hattributeSetter.setUnitMaxLife(whichUnit, currentVal, futureVal, diff)
            elseif (attr == "mana") then
                -- 最大魔法值[JAPI+]
                hattributeSetter.setUnitMaxMana(whichUnit, currentVal, futureVal, diff)
            elseif (attr == "move") then
                -- 移动
                local min = math.floor(hslk.misc("Misc", "MinUnitSpeed")) or 0
                local max = math.floor(hslk.misc("Misc", "MaxUnitSpeed")) or 522
                futureVal = math.min(max, math.max(min, math.floor(futureVal)))
                cj.SetUnitMoveSpeed(whichUnit, futureVal)
            elseif (attr == "attack_space_origin") then
                -- 攻击间隔[JAPI*]
                hattributeSetter.setUnitAttackSpace(whichUnit, futureVal)
            elseif (attr == "attack_white") then
                -- 白字攻击[JAPI+]
                hattributeSetter.setUnitAttackWhite(whichUnit, futureVal, diff)
            elseif (attr == "attack_green") then
                -- 绿字攻击
                hattributeSetter.setUnitAttackGreen(whichUnit, futureVal)
            elseif (attr == "attack_range") then
                -- 攻击范围[JAPI]
                if (true == hattributeSetter.setUnitAttackRange(whichUnit, futureVal)) then
                    local ar = cj.GetUnitAcquireRange(whichUnit)
                    if (ar < futureVal) then
                        hattribute.setHandle(whichUnit, "attack_range_acquire", "+", futureVal - ar, during)
                    end
                end
            elseif (attr == "attack_range_acquire") then
                -- 主动攻击范围
                futureVal = math.min(9999, math.max(0, math.floor(futureVal)))
                cj.SetUnitAcquireRange(whichUnit, futureVal)
            elseif (attr == "attack_speed") then
                -- 攻击速度[JAPI+]
                hattributeSetter.setUnitAttackSpeed(whichUnit, futureVal)
            elseif (attr == "defend_white") then
                -- 白字护甲[JAPI*]
                hattributeSetter.setUnitDefendWhite(whichUnit, futureVal)
            elseif (attr == "defend_green") then
                -- 绿字护甲
                hattributeSetter.setUnitDefendGreen(whichUnit, futureVal)
            elseif (his.hero(whichUnit) and table.includes({ "str_white", "agi_white", "int_white", "str_green", "agi_green", "int_green" }, attr)) then
                -- 白/绿字力敏智
                hattributeSetter.setUnitThree(whichUnit, futureVal, attr, diff)
            elseif (attr == "life_back" or attr == "mana_back") then
                -- 生命,魔法恢复
                if (math.abs(futureVal) > hattribute.CURE_FLOOR) then
                    hmonitor.listen(CONST_MONITOR[string.upper(attr)], whichUnit)
                else
                    hmonitor.ignore(CONST_MONITOR[string.upper(attr)], whichUnit)
                end
            end
        end
    elseif (valType == "table") then
        -- table类型只有+-没有别的
        if (opr == "+") then
            local _k = string.attrBuffKey(val)
            if (during > 0) then
                table.insert(params[attr], { _k = _k, _t = val })
                htime.setTimeout(during, function()
                    hattribute.setHandle(whichUnit, attr, "-", val, 0)
                end)
            else
                table.insert(params[attr], { _k = _k, _t = val })
            end
        elseif (opr == "-") then
            local _k = string.attrBuffKey(val)
            local hasKey = false
            for k, v in ipairs(params[attr]) do
                if (v._k == _k) then
                    table.remove(params[attr], k)
                    hasKey = true
                    break
                end
            end
            if (hasKey == true) then
                if (during > 0) then
                    htime.setTimeout(during, function()
                        hattribute.setHandle(whichUnit, attr, "+", val, 0)
                    end)
                end
            end
        end
    elseif (valType == "string") then
        -- string类型只有+-=
        if (opr == "+") then
            local valArr = string.explode(",", val)
            if (during > 0) then
                params[attr] = table.merge(params[attr], valArr)
                htime.setTimeout(during, function()
                    hattribute.setHandle(whichUnit, attr, "-", val, 0)
                end)
            else
                params[attr] = table.merge(params[attr], valArr)
            end
        elseif (opr == "-") then
            local valArr = string.explode(",", val)
            if (during > 0) then
                for _, v in ipairs(valArr) do
                    if (table.includes(params[attr], v)) then
                        table.delete(params[attr], v, 1)
                    end
                end
                htime.setTimeout(during, function()
                    hattribute.setHandle(whichUnit, attr, "+", val, 0)
                end)
            else
                for _, v in ipairs(valArr) do
                    if (table.includes(params[attr], v)) then
                        table.delete(params[attr], v, 1)
                    end
                end
            end
        elseif (opr == "=") then
            local old = table.clone(params[attr])
            if (during > 0) then
                params[attr] = string.explode(",", val)
                htime.setTimeout(during, function()
                    hattribute.setHandle(whichUnit, attr, "=", string.implode(",", old), 0)
                end)
            else
                params[attr] = string.explode(",", val)
            end
        end
    end
    return buffKey
end

--- 设置单位属性
---@param whichUnit userdata
---@param during number 0表示无限
---@param data pilotAttr
---@return nil|table buffKeys，返回buff keys，如果一个buff都没有，返回nil
hattribute.set = function(whichUnit, during, data)
    if (whichUnit == nil) then
        -- 例如有时造成伤害之前把单位删除就捕捉不到这个伤害来源了
        -- 虽然这里直接返回不执行即可，但是提示下可以帮助完善业务的构成~
        print_stack("whichUnit is nil")
        return
    end
    local attribute = hattribute.get(whichUnit)
    if (attribute == nil) then
        return
    end
    -- 处理data
    if (type(data) ~= "table") then
        print_err("data must be table")
        return
    end
    local buffKeys = {}
    for _, arr in ipairs(table.obj2arr(data, CONST_ATTR_KEYS)) do
        local attr = arr.key
        local v = arr.value
        local buffKey
        if (attribute[attr] == nil) then
            attribute[attr] = CONST_ATTR_VALUE[attr] or 0
        end
        if (type(v) == "string") then
            local opr = string.sub(v, 1, 1)
            v = string.sub(v, 2, string.len(v))
            local val = tonumber(v)
            if (val == nil) then
                val = v
            end
            buffKey = hattribute.setHandle(whichUnit, attr, opr, val, during)
        elseif (type(v) == "table") then
            -- table型
            if (v.add ~= nil and type(v.add) == "table") then
                for _, set in ipairs(v.add) do
                    if (set == nil) then
                        print_err("table effect loss[set]!")
                        print_stack()
                        break
                    end
                    if (type(set) ~= "table") then
                        print_err("add type(set) must be a table!")
                        print_stack()
                        break
                    end
                    buffKey = hattribute.setHandle(whichUnit, attr, "+", set, during)
                end
            elseif (v.sub ~= nil and type(v.sub) == "table") then
                for _, set in ipairs(v.sub) do
                    if (set == nil) then
                        print_err("table effect loss[set]!")
                        print_stack()
                        break
                    end
                    if (type(set) ~= "table") then
                        print_err("sub type(set) must be a table!")
                        print_stack()
                        break
                    end
                    buffKey = hattribute.setHandle(whichUnit, attr, "-", set, during)
                end
            end
        end
        if (buffKey ~= nil) then
            table.insert(buffKeys, buffKey)
        end
    end
    if (#buffKeys > 0) then
        return buffKeys
    end
end

--- 通用get
---@param whichUnit userdata
---@param attr string
---@param default any 默认值，默认为0
---@return any
hattribute.get = function(whichUnit, attr, default)
    if (attr == nil) then
        default = default or {}
    else
        default = default or CONST_ATTR_VALUE[attr] or 0
    end
    if (whichUnit == nil) then
        return default
    end
    local attribute = hcache.get(whichUnit, CONST_CACHE.ATTR, nil)
    if (attribute == nil) then
        return default
    elseif (attribute == -1) then
        if (hattribute.init(whichUnit) == false) then
            return default
        end
        attribute = hcache.get(whichUnit, CONST_CACHE.ATTR)
    end
    local sides1 = hunit.getAttackSides1(whichUnit)
    local atk = (attribute.attack_white or 0) + (attribute.attack_green or 0)
    attribute.attack = sides1.rand + atk
    attribute.attack_sides = { sides1.min + atk, sides1.max + atk }
    attribute.defend = math.floor((attribute.defend_white or 0) + (attribute.defend_green or 0))
    attribute.attack_space = math.round(math.max(0, attribute.attack_space_origin) / (1 + math.min(math.max(attribute.attack_speed, -80), 400) * 0.01))
    attribute.str = (attribute.str_white or 0) + (attribute.str_green or 0)
    attribute.agi = (attribute.agi_white or 0) + (attribute.agi_green or 0)
    attribute.int = (attribute.int_white or 0) + (attribute.int_green or 0)
    if (attr == nil) then
        return attribute or default
    end
    return attribute[attr] or default
end

--- 计算单位的属性浮动影响
---@private
hattribute.caleAttribute = function(damageSrc, isAdd, whichUnit, attr, times)
    if (isAdd == nil) then
        isAdd = true
    end
    if (attr == nil) then
        return
    end
    if (attr.disabled == true) then
        return
    end
    damageSrc = damageSrc or CONST_DAMAGE_SRC.unknown
    if (times == nil or times < 1) then
        times = 1
    end
    local diff = {}
    local diffPlayer = {}
    for _, arr in ipairs(table.obj2arr(attr, CONST_ATTR_KEYS)) do
        local k = arr.key
        local v = arr.value
        local typev = type(v)
        local tempDiff
        if (typev == "string") then
            local opt = string.sub(v, 1, 1)
            local nv = times * tonumber(string.sub(v, 2))
            if (isAdd == false) then
                if (opt == "+") then
                    opt = "-"
                else
                    opt = "+"
                end
            end
            tempDiff = opt .. nv
        elseif (typev == "number") then
            if ((v > 0 and isAdd == true) or (v < 0 and isAdd == false)) then
                tempDiff = "+" .. (v * times)
            elseif (v < 0) then
                tempDiff = "-" .. (v * times)
            end
        elseif (typev == "table") then
            local tempTable = {}
            for _ = 1, times do
                for _, vv in ipairs(v) do
                    vv.damageSrc = damageSrc
                    table.insert(tempTable, vv)
                end
            end
            local opt = "add"
            if (isAdd == false) then
                opt = "sub"
            end
            tempDiff = {
                [opt] = tempTable
            }
        end
        if (hattribute.isValType(k, hattribute.VAL_TYPE.PLAYER)) then
            table.insert(diffPlayer, { k, tonumber(tempDiff) })
        else
            diff[k] = tempDiff
        end
    end
    hattribute.set(whichUnit, 0, diff)
    if (#diffPlayer > 0) then
        local p = hunit.getOwner(whichUnit)
        for _, dp in ipairs(diffPlayer) do
            local pk = dp[1]
            local pv = dp[2]
            if (pv ~= 0) then
                if (pk == "gold_ratio") then
                    hplayer.addGoldRatio(p, pv, 0)
                elseif (pk == "lumber_ratio") then
                    hplayer.addLumberRatio(p, pv, 0)
                elseif (pk == "exp_ratio") then
                    hplayer.addExpRatio(p, pv, 0)
                elseif (pk == "sell_ratio") then
                    hplayer.addSellRatio(p, pv, 0)
                end
            end
        end
    end
end

--- 根据一个护甲值，获得护甲的减伤程度（不考虑克制）
---@param defend number
---@return number
hattribute.getArmorReducePercent = function(defend)
    if (defend <= 0) then
        return 0
    end
    local defenseArmor = math.round(hslk.misc("Misc", "DefenseArmor"), 2) or 0
    if (defenseArmor <= 0) then
        return 0
    end
    return (defend * defenseArmor) / (1 + defend * defenseArmor)
end