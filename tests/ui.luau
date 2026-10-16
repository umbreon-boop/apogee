--[[
	Runs the showcase and every built example against a mocked Roblox environment. Each area runs in order and shares
	the table `t`; an area that errors is reported and the next one still runs.

	Run `mise run test` to build every example and run this suite.
]]
local t = require("./ui/mock")

local AREAS = {
	{"example", require("./ui/example")},
	{"widgets", require("./ui/widgets")},
	{"layout", require("./ui/layout")},
	{"dialogs", require("./ui/dialogs")},
	{"themes", require("./ui/themes")},
	{"popup", require("./ui/popup")},
	{"window", require("./ui/window")},
	{"api", require("./ui/api")},
	{"regressions", require("./ui/regressions")},
	{"unload", require("./ui/unload")},
	{"examples", require("./ui/examples")}
}

local crashed = {}
for _, area in AREAS do
	local ok, err = pcall(area[2], t)
	if not ok then
		table.insert(crashed, area[1] .. ": " .. tostring(err))
		print("CRASH  " .. area[1] .. ": " .. tostring(err))
	end
end

local results = t.results
print(string.format("\n%d passed, %d failed, %d areas crashed", results.passed, #results.failed, #crashed))
for _, message in results.failed do
	print("  failed: " .. message)
end
for _, message in crashed do
	print("  crashed: " .. message)
end
t.process.exit(if #results.failed == 0 and #crashed == 0 then 0 else 1)
