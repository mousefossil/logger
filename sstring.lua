
sstring = {}

-- split string `str` into array of strings at seperator `sep`
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

-- join array of strings àrr` with seperator `sep` to string (faster then string.joinTable for arrays)
function sstring.join(arr, sep)
  local res = ""
  for _, atom in ipairs(arr) do
    res = res..atom..sep
  end
  return res:sub(1, #res-#sep)
end

-- join any table (keys must not be 1, 2, ...N) `arr` with seperator `sep` to string
function sstring.joinTable(arr, sep)
  local res = ""
  for _, atom in pairs(arr) do
    res = res..atom..sep
  end
  return res:sub(1, #res-#sep)
end

-- set char `i`of string `str` to character `char`
function sstring.setChar(str, i, char)
  return str:sub(1, i-1)..char..str:sub(i+1, #str)
end

-- replace "&x" with "" for all chars x not equal to "&"
function sstring.deformat(s)
  s, _ = s:gsub("&&", "²²"):gsub("&.", ""):gsub("²²", "&&")
  return s
end

-- replace whitespace characters with "\t" character which is shown when logged
function sstring.showWhiteSpace(s)
  s, _ = s:gsub("%s", "\t")
  return s
end

-- insert NULL chars after every "&" in string so the string is not formatted when printed
function sstring.showformat(s)
  s, _ = s:gsub("&", "&&"..string.char(0))
  return s
end

-- trim whitespace from front and end of string
function sstring.trim (str)
  -- SOURCE: https://stackoverflow.com/users/7875310/alexander-shostak
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
