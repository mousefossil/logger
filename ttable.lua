require"sstring"

ttable = {}
local INDENT_SIZ = 4

function ttable.len(t)
    local res = 0
    for k, _ in pairs(t) do
        res = res + 1
    end
    return res
end

function ttable.contains(list, x)
    for _, v in pairs(list) do
        if v == x then return true end
    end
    return false
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



function ttable.equals(one, two)
    if type(one) ~= "table" or type(two) ~= "table" then return false end
    if #one ~= #two then return false end
    for i, v in ipairs(one) do
        if two[i] ~= v then log(i, ", ", v); return false end
    end
    return true
end

function ttable.tostr(t, prefix)
    if prefix == nil then prefix = "" end
    
    if t == nil             then return "&bnil" end
    if type(t) == "boolean" then return "&b"..tostring(t) end
    if type(t) == "string"  then return "&b\""..t.."\"" end
    if type(t) == "number"  then return "&b"..tostring(t) end
  
  
    if isClass(t) then
        lines = sstring.split(tostring(t), "\n")
        if #lines <= 1 then
            return "nil" and #lines == 0 or tostring(lines[1])
        end
    
        for i = 2, #lines-1 do
            lines[i] = prefix..string.rep(" ", INDENT_SIZ).."&7⎹".." "..sstring.trim(lines[i])
        end
        lines[#lines] = prefix..string.rep(" ", INDENT_SIZ).."&7ᒫ".." "..sstring.trim(lines[#lines])
    
        return sstring.join(lines, "\n")
    end
  
    local result = {"&e"..tostring(t).." &f{"}
    for k, v in pairs(t) do
        local key_prefix = "&7⎹"..string.rep(" ", INDENT_SIZ-1)
        local key_str = "&c"..k
        local sep_str = "&f = "
        local val_str = ttable.tostr(v, prefix..key_prefix)
        table.insert(result, prefix..key_prefix..key_str..sep_str..val_str.."&f,")
    end
    result[#result] = result[#result]:sub(1, #(result[#result])-1)
    result[#result+1] = prefix.."&f}"
    result = sstring.join(result, "\n")
    return result
end

local function stringTest()
    ar = {10, 20, 30}
    br = {a="bonk", b=5, c={10, 20, 30}, d=false, e=Ray:new{Vec3:new{0, 0, 0}, Vec3:new{1, 2, 3}}}
    cr = {a="bonk", d=ar}
    
    log(ttable.tostr(ar))
    log(ttable.tostr(br))
    log(ttable.tostr(cr))
end

return ttable


