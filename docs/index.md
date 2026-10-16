Apogee
======

A flexible UI library for Roblox, heavily inspired by the design language of libcosmic.

See the [examples](examples/README.md) for a runnable example of every primitive and larger samples.

Importing
---------

We recommend that you import it using `umbra add apogee https://github.com/umbreon-boop/apogee`, after which you can use it with:
```lua
local Apogee = require("@apogee")
```

but you can also fetch it directly from the web:
```lua
local Apogee = loadstring(isfile("yourProject/apogee.lua") and readfile("yourProject/apogee.lua") or (function()
    local s = game:HttpGet("https://github.com/umbreon-boop/apogee/releases/latest/download/artifact.lua")
    makefolder("yourProject") writefile("yourProject/apogee.lua", s) return s
end)())()
```
