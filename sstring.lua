
sstring = {}

function sstring.split(str, sep)
  if sep == nil then
    sep = "%s"
  end
  local atoms = {}
  for s in string.gmatch(str, "([^"..sep.."]+)") do
    table.insert(atoms, s)
  end
  return atoms
end

function sstring.join(arr, sep)
  local res = ""
  for _, atom in ipairs(arr) do
    res = res..atom..sep
  end
  return res:sub(1, #res-#sep)
end

function sstring.setChar(str, i, rep)
  return str:sub(1, i-1)..rep..str:sub(i+1, #str)
end

function sstring.deformat(input)
  new_str = ""
  for i = 1, #input do
    char = input:sub(i, i)
    if char == "&" then
      input = input:sub(1, i-1)..input:sub(i+1, #input)
      goto continue
    elseif string.byte(char) == 194 then
      input = input:sub(1, i-1)..input:sub(i+2, #input)
      goto continue
    else
      new_str = new_str..char
    end
    ::continue::
  end
  return new_str
end

function sstring.trim (str)
  if str == "" then
    return str
  else  
    local startPos = 1
    local endPos   = #str

    while (startPos < endPos and str:byte(startPos) <= 32) do
      startPos = startPos + 1
    end

    if startPos >= endPos then
      return ""
    else
      while (endPos > 0 and str:byte(endPos) <= 32) do
        endPos = endPos - 1
      end

      return str:sub(startPos, endPos)
    end
  end
end



return sstring
