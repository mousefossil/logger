require "debug"
require "ttable"
require "sstring"

logger = {}

-- made by Mouse (github.com/mousefossil)

--///////////////////////////////// --
--//////////// TO KNOW //////////// --
--///////////////////////////////// --

-- full show means the scrollable log gui you get by pressing a key
-- temp show means the temporary pop-in log gui you get when something is logged
-- color format : 0xAARRGGBB
-- config comments format = :type // default // explanation

--//////////////////////////////////// --
--/////////// KNOWN ISSUES /////////// --
--//////////////////////////////////// --

-- Bold text (prefixed with &B can overflow the background due to an AM bug)
-- When only a few lines are logged, the scroll bar looks a little out of place.
-- hud2D.newText("&&a", ...) does no escape the & properly (text afterwards is still colored), this has been worked around
-- Muteces stay locked when calling stopAllScripts() on a script that has a lock on a mutex

--///////////////////////////////// --
--///////////// CONFIG //////////// --
--///////////////////////////////// --

-- call logger.reload() after making changes to the config!

-- FUNCTIONAL
LOGGER_LINE_COUNT = 500         -- int    // 500       // #lines displayed in the gui, and #lines saved per log file
LOGGER_LOGS_DIR_PATH = "logs\\" -- string // "logs\\"  // must start in same directory as this file (no ./), must end in \\ (or maybe / on linux)
LOGGER_MAX_FILE_COUNT = 16      -- int    // 16        // maximum number of log files to keep
LOGGER_SCROLL_SENSITIVITY = 1   -- float  // 1         // mouse scroll sensitivity

-- GRAPHICAL
LOGGER_POS = {0, 0}               -- {float, float} // {0, 0}    // {left, top} position top left corner of logger gui
LOGGER_FONT_SIZ = 8               -- int            // 8          // logger font size
LOGGER_WID = false                -- false or float // false      // false for no line-wrap, number for fixed logger width
LOGGER_FULL_SHOW_LINE_COUNT = 32  -- int            // 32         // number lines shown when opening logger
LOGGER_TEMP_SHOW_MAX_LINES = 20   -- int            // 20         // maximum number lines shown when new item is logged
LOGGER_TEXT_MARGIN = 2            -- int            // 2          // margin left and right of text
LOGGER_BACK_COL = 0x55000000      -- int            // 0x55000000 // logger background color
LOGGER_SBAR_WID = 4               -- float          // 4          // logger scroll bar width
LOGGER_SBAR_MIN_HEI = 8           -- float          // 8          // logger scroll bar minimum height
LOGGER_SBAR_COL = 0x77FFFFFF      -- int            // 0x77FFFFFF // scroll bar color

-- TEMPORAL
LOGGER_TEMP_SHOW_DURATION = 6000      -- int // 6000 // time in ms that newly logged item is shown
LOGGER_FULL_SHOW_TICK = 50            -- int // 50   // tick time in ms for the user input polling loop when logger opened
LOGGER_FULL_SHOW_SCROLLING_TICK = 16  -- int // 16   // ^above when is scrolling, also affects scrolling speed (lower=faster), too low and it will jank

--///////////////////////////////// --
--/////////// CONSTANTS /////////// --
--///////////////////////////////// --

LOGGER_FULL_SHOW_ACTIVE = nil
LOGGER_POS_X, LOGGER_POS_Y = table.unpack(LOGGER_POS)
MOUSE = luajava.bindClass("org.lwjgl.input.Mouse")
LOGGER_SCROLL_FACTOR = math.floor(1000/LOGGER_SCROLL_SENSITIVITY)

--//////////////////////////////////// --
--/////////// LOGGER STATE /////////// --
--//////////////////////////////////// --

if not LOGGER_LOG  then
  LOGGER_LOG = {"///"} -- {string1, string2, ...}
end

if not LOGGER_LOGDEL_LINES then
  LOGGER_LOGDEL_LINES = {} -- {abs_entry_index = {lines_deleted_before, line_count}, ...}
end

if not LOGGER_TEMP_SHOW_CALLS then
  LOGGER_TEMP_SHOW_CALLS = {} -- {{time1, linecount1}, {time2, linecount2}}
end

if not LOGGER_LINES_LOGGED then
  LOGGER_LINES_LOGGED = 0
end

if not LOGGER_LINES_DELETED then
  LOGGER_LINES_DELETED = 0
end

if not LOGGER_TEMP_HIDER then
  LOGGER_TEMP_HIDER = runThread(function () end)
end

if not LOGGER_TEXT then
  LOGGER_TEXT = hud2D.newText(
    "",
    LOGGER_POS_X + LOGGER_SBAR_WID + LOGGER_TEXT_MARGIN, 
    LOGGER_POS_Y,
    LOGGER_FONT_SIZ
  )
end

if not LOGGER_BACK then
  LOGGER_BACK = hud2D.newRectangle(
    LOGGER_POS_X,
    LOGGER_POS_Y,
    0,
    0
  )
  LOGGER_BACK.setColor(LOGGER_BACK_COL)
end

if not LOGGER_SBAR then
  LOGGER_SBAR = hud2D.newRectangle(
    LOGGER_POS_X,
    0,
    LOGGER_SBAR_WID,
    0
  )
  LOGGER_SBAR.setColor(LOGGER_SBAR_COL)
end


--///////////////////////////////// --
--/////////// FUNCTIONS /////////// --
--///////////////////////////////// --

---------------------------
-- //// UPDATING UI //// --
---------------------------

-- update LOGGER_TEXT: set text to LOGGER_LOG[line_start - lines_count .. line_start]
function logger.updateText(lines_count, line_start)
  --LOGGER_MUTEX.lock()
  local line_i = math.max(1, line_start - lines_count + 1)
  local res_str = ""

  while line_i <= line_start do
    res_str = res_str..LOGGER_LOG[line_i].."\n"
    line_i = line_i + 1
  end
  res_str = res_str:sub(1, #res_str-1)
  --LOGGER_MUTEX.unlock()
  LOGGER_TEXT.setText(res_str)
end

-- update LOGGER_BACK: set width to fixed width or text width, depending on config
function logger.updateBack()
  if LOGGER_WID == false then
    LOGGER_BACK.setWidth(LOGGER_SBAR_WID + LOGGER_TEXT.getWidth()+2*LOGGER_TEXT_MARGIN)
  else
    LOGGER_BACK.setWidth(LOGGER_WID)
  end
  LOGGER_BACK.setHeight(LOGGER_TEXT.getHeight())
end

-- update LOGGER_SBAR (scrollbar): set to correct height and position
function logger.updateSbar(lines_count, curr_line)
  local sbar_area_hei = lines_count*LOGGER_FONT_SIZ
  local sbar_hei = math.max(LOGGER_SBAR_MIN_HEI, sbar_area_hei*lines_count/#LOGGER_LOG)
  
  local scroll_pos_fac = ((curr_line-lines_count)/(#LOGGER_LOG-lines_count))
  local logger_sbar_rel_pos = scroll_pos_fac * (sbar_area_hei-sbar_hei)

  LOGGER_SBAR.setY(LOGGER_POS_Y + logger_sbar_rel_pos)
  LOGGER_SBAR.setHeight(sbar_hei)
end

---------------------------------
-- //// SHOWING/HIDING UI //// --
---------------------------------

-- get the number of lines to be temporarily displayed from LOGGER_TEMP_SHOW_CALLS
local function getTempShowLineCount()
  local res = 0
  for i, v in ipairs(LOGGER_TEMP_SHOW_CALLS) do
    res = res + v[2]
  end
  return math.min(res, LOGGER_TEMP_SHOW_MAX_LINES)
end

-- remove calls older than set duration from LOGGER_TEMP_SHOW_CALLS
local function removeOldTemps()
  local curr_time = os.millis()
  while #LOGGER_TEMP_SHOW_CALLS > 0 and LOGGER_TEMP_SHOW_CALLS[1][1] + LOGGER_TEMP_SHOW_DURATION - 10 < curr_time do
    table.remove(LOGGER_TEMP_SHOW_CALLS, 1)
  end
end

-- runs in new thread: sleeps, removes entries from LOGGER_TEMP_SHOW_CALLS, updates UI, exits when no more entries
local function tempHide()
  local int
  removeOldTemps()
  while 0 < #LOGGER_TEMP_SHOW_CALLS do
    int = LOGGER_TEMP_SHOW_CALLS[1][1]-os.millis() + LOGGER_TEMP_SHOW_DURATION
    if int > 10 then sleep(int) end
    removeOldTemps()
    if LOGGER_FULL_SHOW_ACTIVE then break end
    logger.updateText(getTempShowLineCount(), #LOGGER_LOG)
    logger.updateBack()
  end

  if not LOGGER_FULL_SHOW_ACTIVE then
    LOGGER_BACK.disableDraw()
    LOGGER_TEXT.disableDraw()
  end
end

-- show temporary logger UI, add entry with current time and line_count lines to LOGGER_TEMP_SHOW_CALLS
function logger.tempShow(line_count)
  table.insert(LOGGER_TEMP_SHOW_CALLS, {os.millis(), line_count})
  logger.updateText(getTempShowLineCount(), #LOGGER_LOG)
  logger.updateBack()
  LOGGER_BACK.enableDraw()
  LOGGER_TEXT.enableDraw()

  if LOGGER_TEMP_HIDER.getStatus() ~= "running" and LOGGER_TEMP_HIDER.getStatus() ~= "new" then
    LOGGER_TEMP_HIDER = runThread(tempHide)
  end
end

-- toggle full logger UI, including scrollbar, poll for scroll input and update accordingly
function logger.fullShow()
  LOGGER_FULL_SHOW_ACTIVE = not LOGGER_FULL_SHOW_ACTIVE
  if not LOGGER_FULL_SHOW_ACTIVE then return end -- returns if toggling full show off
  local curr_line = #LOGGER_LOG
  logger.updateText(LOGGER_FULL_SHOW_LINE_COUNT, curr_line)
  logger.updateBack()
  logger.updateSbar(LOGGER_FULL_SHOW_LINE_COUNT, curr_line)
  LOGGER_BACK.enableDraw()
  LOGGER_TEXT.enableDraw()
  LOGGER_SBAR.enableDraw()
  local scroll = 0
  
  while LOGGER_FULL_SHOW_ACTIVE do
    scroll = MOUSE:getDWheel()
    if isKeyDown("ESCAPE") then
      LOGGER_FULL_SHOW_ACTIVE = false
    elseif curr_line > LOGGER_FULL_SHOW_LINE_COUNT and scroll > 0 then
      curr_line = math.max(LOGGER_FULL_SHOW_LINE_COUNT, curr_line - math.ceil(scroll*LOGGER_SCROLL_SENSITIVITY/120))
      logger.updateSbar(LOGGER_FULL_SHOW_LINE_COUNT, curr_line)
      logger.updateText(LOGGER_FULL_SHOW_LINE_COUNT, curr_line)
      logger.updateBack()
      sleep(LOGGER_FULL_SHOW_SCROLLING_TICK)
    elseif curr_line < #LOGGER_LOG and scroll < 0 then
      curr_line = math.min(#LOGGER_LOG, curr_line + math.ceil(math.abs(scroll*LOGGER_SCROLL_SENSITIVITY/120)))
      logger.updateSbar(LOGGER_FULL_SHOW_LINE_COUNT, curr_line)
      logger.updateText(LOGGER_FULL_SHOW_LINE_COUNT, curr_line)
      logger.updateBack()
      sleep(LOGGER_FULL_SHOW_SCROLLING_TICK)
    else
      -- logger.log updates text and back
      sleep(LOGGER_FULL_SHOW_TICK)
    end
  end
  hud2D.clearAll()
end

-----------------------
-- //// ACTIONS //// --
-----------------------

-- reload's logger package to refresh logger state, config, ...
function logger.reload()
  for k, v in pairs(package.loaded) do
    log(k, v)
    if k:find("logger") then
        package.loaded[k] = nil
    end
  end
end

-- delete all log entries
function logger.clear()
  hud2D.clearAll()
  --LOGGER_MUTEX.lock()
  LOGGER_LOG = {}
  LOGGER_LINES_LOGGED = 0
  LOGGER_LINES_DELETED = 0
  LOGGER_TEMP_SHOW_CALLS = {}
  LOGGER_LOGDEL_LINES = {}
  --LOGGER_MUTEX.unlock()
  logger.log("///")
end

-- get file paths of the log files, in alphabetical order
local function getLogSortedAbsPaths(rel_dir_path)
  -- only works on windows, parsing ls instead of dir command possible on linux
  local this_file_path = debug.getinfo(1).short_src:gsub("\\.\\", "\\")
  this_dir_path = this_file_path:sub(1, #this_file_path - this_file_path:reverse():find("\\")+1)
  local rel_dirs = {}
  local abs_files = {}
  dir_path = this_dir_path..rel_dir_path:gsub("/", "\\")
  for dir_name in io.popen([[cmd.exe /c dir "]]..dir_path..[[" /b /ad]]):lines() do
    table.insert(rel_dirs, dir_name)
  end
  for item_name in io.popen([[cmd.exe /c dir "]]..dir_path..[[" /b]]):lines() do
    if not ttable.containsVal(rel_dirs, item_name) then
      table.insert(abs_files, dir_path.."\\"..item_name)
    end
  end
  return abs_files
end

-- save LOGGER_LOG to file and delete oldest files over the set file count limit
function logger.save()
  local path = LOGGER_LOGS_DIR_PATH.."log_"..os.date("%Y-%m-%d_%H-%M-%S")..".txt"
  local file = io.open(path, "w")
  --LOGGER_MUTEX.lock()
  table.insert(LOGGER_LOG, "saved log to "..path)
  local text = sstring.join(LOGGER_LOG, "\n")
  file:write(text)
  file:close()
  --LOGGER_MUTEX.unlock()
  local log_files = getLogSortedAbsPaths(LOGGER_LOGS_DIR_PATH)
  if #log_files > LOGGER_MAX_FILE_COUNT then
    for i = 1, #log_files - LOGGER_MAX_FILE_COUNT do
      io.popen([[cmd.exe /c del "]]..log_files[i]..[["]])
    end
  end
end

-----------------------
-- //// LOGGING //// --
-----------------------

-- add one line to LOGGER_LOG
function logger.addLine(str)
  --LOGGER_MUTEX.lock()
  table.insert(LOGGER_LOG, str)
  for i =  1, #LOGGER_LOG - LOGGER_LINE_COUNT do
    table.remove(LOGGER_LOG, 1)
  end
  --LOGGER_MUTEX.unlock()

  LOGGER_LINES_LOGGED = LOGGER_LINES_LOGGED + 1
  if LOGGER_LINES_LOGGED % LOGGER_LINE_COUNT == 0 then
    logger.save()
  end
end

-- get formatstring with which the given string ends (e.g. "&e&B wopwop" -> "&e&B")
local function getEndFormat(str)
  -- return string of the formatting that is active in end of string
  color_format_chars = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"}
  non_color_format_chars = {"B", "I", "O", "S", "U"}

  r = str:reverse()
  res = ""
  
  while true do
    amper_last = r:find("&")
    if amper_last == nil or amper_last == 1 then return res end -- dont work if amper on last char of input str
    format_last = r:sub(amper_last-1, amper_last-1)
    res = "&"..format_last..res
    if ttable.containsVal(color_format_chars, format_last) then  
      return res
    else
      res = "&"..format_last..res
    end
    r = r:sub(amper_last+1)
  end
end

-- wrap str according to LOGGER_WID
local function wrapLine(str)
  local res = ""
  local i = 1
  local temp_text = hud2D.newText("", 0, 0, LOGGER_FONT_SIZ)
  while i < #str do
    temp_text.setText(str:sub(1, i))
    if temp_text.getWidth() > LOGGER_WID - 2*LOGGER_TEXT_MARGIN then
      res = res..str:sub(1, i-1).."\n"
      res = res..getEndFormat(res)
      str = str:sub(i)
      i = 1
    else
      i = i + 1
    end
  end
  res = res..str
  temp_text.destroy()
  return res
end

-- log entry 
function logger.log(...)
  local concat_str = ""
  for i, item in ipairs({...}) do

    if type(item) == "table" then
      item = ttable.tostr(item)
    end

    if LOGGER_WID ~= false then
      item = wrapLine(item)
    end

    concat_str = concat_str..tostring(item)
  end

  local line_count = 0
  for _, line in ipairs(sstring.split(concat_str, "\n")) do
    logger.addLine(line:gsub("&&", "&&"..string.char(0))) -- &&x is not properly rendered in newText
    line_count = line_count + 1
  end

  if LOGGER_FULL_SHOW_ACTIVE then
    logger.updateText(LOGGER_FULL_SHOW_LINE_COUNT, #LOGGER_LOG)
    logger.updateSbar(LOGGER_FULL_SHOW_LINE_COUNT, #LOGGER_LOG)
    logger.updateBack()
  else
    logger.tempShow(line_count)
  end
end

-- delete logdel entry
local function deleteEntry(entry_hi_abs_i)
  -- absolute indices : (1.....log_lo_abs_i.....entry_lo_abs_i.....entry_hi_abs_i.....log_hi_abs_i.....LOGGER_LINES_LOGGED)
  -- relative indices :        1................entry_lo_rel_i.....entry_hi_rel_i.....#LOGGER_LOG
  --            oldest entry-->////////////////////////LOGGER_LOG////////////////////////////////<--newest entry
  -- entry_lo_abs_i and entry_hi_abs_i may be < log_lo_abs_i : were pushed out of LOGGER_LOG before deletion see (1)
  -- #lines with lower index deleted = LOGGER_LOGDEL_LINES[entry_hi_abs_i][1] see (2)
  -- #lines this entry consists off = LOGGER_LOGDEL_LINES[entry_hi_abs_i][2]

  local log_lo_abs_i = LOGGER_LINES_LOGGED - #LOGGER_LOG - LOGGER_LINES_DELETED 
  local entry_hi_rel_i = entry_hi_abs_i - log_lo_abs_i - LOGGER_LOGDEL_LINES[entry_hi_abs_i][1] 
  local entry_lo_rel_i = entry_hi_rel_i - LOGGER_LOGDEL_LINES[entry_hi_abs_i][2] + 1
  local lines_deleted = 0
  for line_rel_i = entry_hi_rel_i, entry_lo_rel_i, -1 do
    if line_rel_i < 1 then break end
    lines_deleted = lines_deleted + 1
    table.remove(LOGGER_LOG, line_rel_i)
  end

  LOGGER_LINES_DELETED = lines_deleted + LOGGER_LINES_DELETED
  LOGGER_LOGDEL_LINES[entry_hi_abs_i] = nil

  -- delete already pushed out logdel entries and increase the offset of later ones
  for other_hi_abs_i, v in pairs(LOGGER_LOGDEL_LINES) do
    if other_hi_abs_i < log_lo_abs_i then
      -- entry has been pushed entirely out of LOGGER_LOG (1)
      LOGGER_LOGDEL_LINES[entry_hi_abs_i] = nil
    elseif other_hi_abs_i > entry_hi_abs_i then
      -- adjust the #lines deleted before of later entries (2)
      LOGGER_LOGDEL_LINES[other_hi_abs_i][1] = LOGGER_LOGDEL_LINES[other_hi_abs_i][1] + lines_deleted 
    end
  end
end

-- delete and/or add logdel entry
function logger.logdel(...)
  items = {...}
  if type(items[1]) == "number" and ttable.containsKey(LOGGER_LOGDEL_LINES, items[1]) then
    deleteEntry(items[1])
    table.remove(items, 1)
  end
  if ttable.len(items) > 0 then
    local first_line_num = LOGGER_LINES_LOGGED
    logger.log(table.unpack(items))
    LOGGER_LOGDEL_LINES[LOGGER_LINES_LOGGED] = {LOGGER_LINES_DELETED, LOGGER_LINES_LOGGED - first_line_num}
  end
  return LOGGER_LINES_LOGGED
end

--------------------------------
-- //// LOGGING FEATURES //// --
--------------------------------

-- log a warning
function logger.warn(...)
  logger.log("&c&BWARNING:&c ", ...)
end

-- log an error message, stacktrace and error() out
function logger.error(...)
  logger.log("&4&BERROR:&4 ", ...)
  local i = 2
  while true do
    info = debug.getinfo(i)

    if not info then break end
    path = info.source:gsub(".*\\macros\\", ""):gsub(".lua", "")

    if info.name ~= "?" then
      if i == 2 then
        logger.log("&c  in &6function&c&B&U "..path.."."..info.name.."()".." on line "..info.currentline)
      else
        logger.log("&c  in &6function&c "..path.."."..info.name.."()".." on line "..info.currentline)
      end
    else
      logger.log("&c  in &efile       &c"..path..".lua".." on line "..info.currentline)
    end

    i = i+1
  end
  error("\n&5&OOOO&e&B SEE ERROR IN LOGGER &5&OOOO&f")

end

-- get relative path of script calling logger
local function getCallerRelativePath()
  local i = 2
  while true do
    local path = debug.getinfo(i).source
    i = i + 1
    if not path then
      return "func not found"
    elseif path:find("logger") == nil then
      return path:gsub(".*\\macros\\", "")
    end
  end
end

-- logs relative path of script calling logger
function logger.logRelativePath()
  logger.log(getCallerRelativePath())
end

-- log that the callee is being entered 
function logger.logEntering()
  local rel_path = getCallerRelativePath()
  if rel_path == nil then error("hahah gotcha") end
  logger.log("&2&Bentering &2"..rel_path.." ")
end

-- log that the callee is exiting
function logger.logExiting()
  local rel_path = getCallerRelativePath()
  if rel_path == nil then error("hahah gotcha") end
  logger.log("&4&Bexiting &4"..rel_path.." ")
end

-- log the date-time
function logger.logTime(prefix)
  if not prefix then prefix = "" end
  logger.log(prefix..os.date("%c"))
end

-----------------------
-- ////  OTHER  //// --
-----------------------

-- tell user to not call this script directly
if not debug.getinfo(2) then
-- this script was directly called with an AM binding (e.g. not `require`d by another script)
logger.log([[
This script cannot be directly called with a binding.
Make a new file named for example "loggerFullShow.lua" with the following 2 lines of code:
&erequire "<your path to logger.lua>"
&elogger.fullShow()
]])
end



return logger




