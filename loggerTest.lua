require"./logger"
require"./sstring"

--require this file and run demo() or perf()

function demo()
  logger.clear()
  logger.logEntering()
  logger.logTime("&8@")
  logger.logRelativePath()

  MyClass = newClass"MyClass"
  local _new = MyClass.new
  function MyClass:new(bo, nu, st, ta)
      local obj = _new( self )
      obj.bo, obj.nu, obj.st, obj.ta = bo, nu, st, ta
      getmetatable(obj).__tostring = function()
          return "&eMyClass:"..
            "\n  &cbo: &b"..tostring(obj.bo)..
            "\n  &cnu: &b"..tostring(obj.nu)..
            "\n  &cst: &b"..tostring(obj.st)..
            "\n  &cta: &b"..tostring(obj.ta)
      end
      return obj
  end

  my_obj = MyClass:new(true, 42, "bonk", {"b", "c", "c"})


  a = {
    bonk = "BONK!",
    magicnumber = 42,
    todo = {
      "go",
      "return",
      "buy",
      "work",
      "wopper",
      false,
      999
    },
    my_obj,
    dinos = {
      big = "trex",
      fly = "ptero",
      now = "turtle",
      invalid = false,
      numberofdinos = 987645
    }
  }

  logger.log(a)
  logger.log("amazing: you give multiple items to a log command like ", 42, ", ", {"a", "b"})
  for i = 1, 9 do
    logger.log("&"..i..string.rep("##", i))
  end
  logger.warn("This is sketchy! ", "woosh ", 5, ", ", false, " = bad", {4, 5, 6})
  
  logger.logExiting()
  logger.error("Error after exiting? That's strange! but num = ", 5, " ", false, " = bad ", {4, 5, 6})
end

function perf()
  chars = "0123456789"
  strings = {}
  times_logger = {}
  times_log = {}
  sum_logger = 0
  sum_log = 0
  max_logger = 0
  max_log = 0

  for i = 1, 10 do
    for j = 1, 10 do
      table.insert(strings, "&"..(i%10)..string.rep(chars:sub(j, j), 38))
    end
  end

  local t0, t1, d = 0, 0, d

  function perfLogger()
    logger.clear() -- clearing log beforehand because otherwise saves to file every 500 lines 
    t0 = os.millis()
    for _, s in ipairs(strings) do
      logger.log(s)
    end
    t1 = os.millis()

    d = t1 - t0
    logger.log("&a===============================")
    logger.log("&a==== LOGGED ", #strings, " LINES IN ", t1-t0, "ms ====")
    logger.log("&a===============================")
    if d > max_logger then
      max_logger = d
    end
    table.insert(times_logger, d)
    sum_logger = sum_logger + d
  end

  function perfLog()
    t0 = os.millis()
    for _, s in ipairs(strings) do
      log(s)
    end
    t1 = os.millis()
    d = t1 - t0

    log("&a===============================")
    log("&a==== LOGGED "..#strings.." LINES IN "..(t1-t0).."&ams ====")
    log("&a===============================")
    if d > max_log then
      max_log = d
    end
    table.insert(times_log, d)
    sum_log = sum_log + d
  end

  num_trials = 12
  for i = 1, num_trials do
    perfLog()
    perfLogger()
  end

  logger.clear()



  logger.log("&dTime to log ", #strings, " lines in ms (", num_trials, " trials):")
  logger.log("&6LOGGER:")
  logger.log("&6  avg = ", sum_logger/num_trials)
  logger.log("&6  max = ", max_logger)
  logger.log("&6LOG:")
  logger.log("&6  avg = ", sum_log/num_trials)
  logger.log("&6  max = ", max_log)
end

