-- 大部分方法不支持pairs，会引起异步

--- 随机在数组内取一个
---@param arr table
---@return any
table.random = function(arr)
    local val
    if (#arr > 0) then
        val = arr[math.random(1, #arr)]
    end
    return val
end

--- 洗牌
---@param arr table
---@return table
table.shuffle = function(arr)
    local shuffle = table.clone(arr)
    local length = #shuffle
    local temp
    local random
    while (length > 1) do
        random = math.random(1, length)
        temp = shuffle[length]
        shuffle[length] = shuffle[random]
        shuffle[random] = temp
        length = length - 1
    end
    return shuffle
end

--- 克隆table
---@param org table
---@return table
table.clone = function(org)
    local function copy(org1, res)
        for _, v in ipairs(org1) do
            if type(v) ~= "table" then
                table.insert(res, v)
            else
                local rl = #res + 1
                res[rl] = {}
                copy(v, res[rl])
            end
        end
    end
    local res = {}
    copy(org, res)
    return res
end

--- 合并table
---@vararg table
---@return table
table.merge = function(...)
    local tempTable = {}
    local tables = { ... }
    if (tables == nil) then
        return {}
    end
    for _, tn in ipairs(tables) do
        if (type(tn) == "table") then
            for _, v in ipairs(tn) do
                table.insert(tempTable, v)
            end
        end
    end
    return tempTable
end

--- 在数组内
---@param arr table
---@param val any
---@return boolean
table.includes = function(arr, val)
    local isIn = false
    if (val == nil or #arr <= 0) then
        return isIn
    end
    for _, v in ipairs(arr) do
        if (v == val) then
            isIn = true
            break
        end
    end
    return isIn
end

--- 删除数组一次某个值(qty次,默认删除全部)
---@param arr table
---@param val any
---@param qty number
table.delete = function(arr, val, qty)
    qty = qty or -1
    local q = 0
    for k, v in ipairs(arr) do
        if (v == val) then
            q = q + 1
            table.remove(arr, k)
            k = k - 1
            if (qty ~= -1 and q >= qty) then
                break
            end
        end
    end
end

--- 根据key从数组table返回一个对应值的数组
---@param arr table
---@param key string
---@return table
table.value = function(arr, key)
    local values = {}
    if (arr ~= nil and key ~= nil and #arr > 0) then
        for _, v in ipairs(arr) do
            if (v[key] ~= nil) then
                table.insert(values, v[key])
            end
        end
    end
    return values
end

--- 将obj形式的attr数据转为有序数组{key=[key],value=[value]}
---@param obj table
---@param keyMap table
---@return table
table.obj2arr = function(obj, keyMap)
    if (keyMap == nil or type(keyMap) ~= "table" or #keyMap <= 0) then
        return {}
    end
    local arr = {}
    for _, a in ipairs(keyMap) do
        if (obj[a] ~= nil) then
            table.insert(arr, { key = a, value = obj[a] })
        end
    end
    return arr
end