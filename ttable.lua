require"sstring"

ttable = {}
local BASE_PREFIX = "⎹   "  -- default = "⎹   " // what to indent ttable.toStr with
local KEY_COL = "&b"        -- default = "&b"   // color of keys in ttable.toStr
local VAL_COL = "&e"        -- default = "&e"   // color of values in ttable.toStr
local TYPE_FORMAT = "&B"    -- default = "&B" // format for `table`, `function`, `MyClass` in ttable.toStr

-- Note: table is array if keys = 1, 2, 3, ..., N
function ttable.isArray(t)
    local i = 0
    for _ in pairs(t) do
      i = i + 1
      if t[i] == nil then return false end
    end
    return true
end

-- Note: use the faster `#my_table` for arrays
function ttable.len(t)
    local res = 0
    for k, _ in pairs(t) do
        res = res + 1
    end
    return res
end

function ttable.containsVal(t, x)
    for _, v in pairs(t) do
        if v == x then return true end
    end
    return false
end

function ttable.containsKey(t, x)
    return t[x] ~= nil
end

function ttable.deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[ttable.deepCopy(orig_key)] = ttable.deepCopy(orig_value)
        end
        setmetatable(copy, ttable.deepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- recursively compares table contents
function ttable.equalContent(one, two)
    if type(one) ~= type(two) then return false end

    if one == two then return true end

    if ttable.len(one) ~= ttable.len(two) then return false end

    for k, v in pairs(one) do
        if type(v) == "table" then
            if not ttable.equalContent(v, two[k]) then return false end
        else
            if two[k] ~= v then return false end
        end
    end
    return true
end

-- table to pretty print
function ttable.tostr(t, prefix)
    if not prefix then prefix = BASE_PREFIX end

    local res = ""
    if isClass(t) then
        res = res..VAL_COL..TYPE_FORMAT..getmetatable(t).__class..VAL_COL..": "
        local prev_tostring = getmetatable(t).__tostring
        getmetatable(t).__tostring = nil
        res = res.." "..tostring(t):sub(8)
        getmetatable(t).__tostring = prev_tostring
    else
        res = res..VAL_COL..TYPE_FORMAT.."table"..VAL_COL..": "..tostring(t):sub(8)
    end
    res = res.."&f {\n"

    for k, v in pairs(t) do
        res = res..prefix..KEY_COL
        if type(k) == "boolean" then
            res = res..tostring(k)
        elseif type(k) == "number" then
            res = res..tostring(k)
        elseif type(k) == "string" then
            res = res..sstring.showWhiteSpace(sstring.showformat(k))
        elseif type(k) == "function" then
            res = res..TYPE_FORMAT.."function"..KEY_COL..": "..tostring(v):gsub(".*\\macros\\", "")
        elseif isClass(k) then
            res = res..TYPE_FORMAT..getmetatable(k).__class..KEY_COL..": "
            local prev_tostring = getmetatable(k).__tostring
            getmetatable(k).__tostring = nil
            res = res..tostring(k):sub(8)
            getmetatable(k).__tostring = prev_tostring
        elseif type(k) == "table" then
            res = res..TYPE_FORMAT.."table"..KEY_COL..": "..tostring(k):sub(8)
        end

        res = res.."&f = "..VAL_COL

        if type(v) == "boolean" then
            res = res..tostring(v)
        elseif type(v) == "number" then
            res = res..tostring(v)
        elseif type(v) == "string" then
            res = res..[[&f"]]..VAL_COL..sstring.showformat(v)..[[&f"]]
            if #v ~= #sstring.showformat(v) then
                res = res..[[ = "]]..v..[[&f"]]
            end
        elseif type(v) == "function" then
            res = res..TYPE_FORMAT.."function"..VAL_COL..": "..tostring(v):gsub(".*\\macros\\", "")
        elseif type(v) == "table" then
            res = res..ttable.tostr(v, prefix..BASE_PREFIX)
        end
        res = res.."\n&f"
    end

    prefix = prefix:sub(1, #prefix-#BASE_PREFIX)
    return res..prefix.."}"

end


return ttable


