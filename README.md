**Mouse's Logger**
==============
_A Lua library to replace the `log(...)` and `logdel(...)` functions in [Advanced Macros](https://github.com/AdvancedMacros/AdvancedMacros) with a seperate GUI from the Minecraft chat._

## Features
* Call `logger.log(...)` and `logger.logdel(...)` exactly like `log(...)` and `logdel(...)` (you can even set `log = logger.log` in the beginning of your file)
* Configurable (see top of logger.lua)
    * Fixed width with line-wrap or adaptive width without line-wrap
    * Position
    * Number of lines
    * Colors
    * Scroll speed
    * etc.
* `logger.warn(...)`, `logger.error(...)` to log a warning or error out with traceback
* `logger.logEntering()`, `logger.logExiting()` to log you entered/exited a script
* Pretty table printing in all log functions
* Full color/textface support
* Fast (100 logger.log(...) calls in 36 ms)
* Save logs to local files

## How to use
1. Get all above files and put in /macros/libs or adapt to your own directory structure
2. Create AM key binding to `loggerFullShow.lua`
3. `require "logger"` in your scripts

## Showcase

![demo](/demo.png)

## Known issues
* Bold text (prefixed with &B) can overflow the chat background (bug in AM)
* Scroll bar looks a little out of place when you have only a few lines logged
