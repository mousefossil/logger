**Mouse's Logger**
==============
_A Lua library to replace the `log(...)` function in [Advanced Macros](https://github.com/AdvancedMacros/AdvancedMacros) with a seperate GUI from the Minecraft chat._

# Features
* Call `logger.log(...)` exactly like `log(...)` (you can even set `log = logger.log` in the beginning of your file)
* Configurable (see top of logger.lua)
    * Fixed width with line-wrap or adaptive width without line-wrap
    * Position
    * Number of lines
    * Colors
    * Scroll speed
    * etc.
* `logger.warn(...)`, `logger.error(...)`
* logger.logEntering(), logger.logExiting() (for when you want to log that entered/exited a script), 
* Pretty table printing
* Full color/textface support
* Fast (100 logger.log(...) calls in 36 ms)
* Save logs to local files

# How to use
1. Get all above files
2. Reorganize to fit your project structure (fix `require`s in files)
3. Create AM key binding to `loggerFullShow.lua`
4. `require "logger"` in your scripts

# Showcase

![demo](/demo.png)

# Known issues
* Bold text (prefixed with &B) can overflow the chat background (bug in AM)
* Scroll bar looks a little out of place when you have only a few lines logged
