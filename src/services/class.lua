--[=[
	Builds classes backed by reactive [Aria](https://github.com/the-unnamed-goose/aria) interfaces.
	Declared properties behave like fields and invoke their handlers when changed.

	@class Class
	@location internals/services
]=]
local Interface = require("@aria/interface")

local Class = {}

--[=[
	Turns a table into a reactive class, optionally inheriting methods from another reactive class.

	@param class { [string]: any } -- The class table
	@param base { [string]: any }? -- The parent class
	@return { [string]: any } -- The same class table
]=]
function Class.Extend(class: { [string]: any }, base: { [string]: any }?): { [string]: any }
	if base then
		setmetatable(class, {__index = base})
	end

	class.__index = function(self, key)
		local method = class[key]
		if method ~= nil then
			return method
		end
		return Interface.__index(self, key)
	end
	class.__newindex = function(self, key, value)
		if type(key) == "string" and string.sub(key, 1, 1) == "_" then
			rawset(self, key, value)
		else
			Interface.__newindex(self, key, value)
		end
	end
	return class
end

--[=[
	Creates an instance of a reactive class. Fields whose name starts with `_` are private and are stored as they are;
	every other write must go to a declared property.

	@param class { [string]: any } -- A class made with `Class.Extend`
	@param fields { [string]: any }? -- Raw fields to store on the instance
	@return any -- A new reactive instance of the supplied class, initialized with the provided fields.
]=]
function Class.New(class: { [string]: any }, fields: { [string]: any }?): any
	local self = Interface.New()
	for key, value in fields or {} do
		rawset(self, key, value)
	end
	return setmetatable(self, class)
end

--[=[
	Declares reactive properties whose handlers receive the instance and the new value.

	@param self any -- The instance
	@param properties { [string]: (self: any, value: any) -> () } -- The property handlers
]=]
function Class.Define(self: any, properties: { [string]: (self: any, value: any) -> () })
	for name, handler in properties do
		self:Define(name, function(value)
			handler(self, value)
		end)
	end
end

return Class
