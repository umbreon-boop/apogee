--[=[
	Translates text created through Creator and keeps it in sync when the locale changes.
	@class Localization
	@location internals/services
]=]
local Creator = require("./creator")

local Localization = {
	Locale = "en",
	Translations = {},
	_entries = setmetatable({}, {__mode = "k"})
}

local PROPERTIES = {"Text", "PlaceholderText"}
--@inline
local function apply(self, instance, entry, property)
	local source = entry[property]
	if source ~= nil then
		local translated = self:Translate(source)
		entry[property .. "Applied"] = translated
		if (instance :: any)[property] ~= translated then
			entry.applying = true
			(instance :: any)[property] = translated
			entry.applying = false
		end
	end
end

function Localization:Translate(text: any): any
	if type(text) ~= "string" then
		return text
	end
	local locale = self.Translations[self.Locale]
	if locale and locale[text] ~= nil then
		return locale[text]
	end
	return text
end

function Localization:SetLocale(locale: string, translations: {[string]: string}?)
	assert(type(locale) == "string" and locale ~= "", "Localization:SetLocale expects a locale name")
	if translations then
		self.Translations[locale] = translations
	end
	self.Locale = locale
	for instance, entry in self._entries do
		for _, property in PROPERTIES do
			apply(self, instance, entry, property)
		end
	end
end

function Localization:SetTranslations(locale: string, translations: {[string]: string})
	self.Translations[locale] = translations
	if locale == self.Locale then
		self:SetLocale(locale)
	end
end

function Localization:Hook(instance: Instance, class: string, props: {[string]: any})
	if class ~= "TextLabel" and class ~= "TextButton" and class ~= "TextBox" then
		return
	end
	local entry = {applying = false}
	self._entries[instance] = entry
	for _, property in PROPERTIES do
		local source = props[property]
		-- the text of a text box is user input, only its placeholder is interface text
		if source ~= nil and not (class == "TextBox" and property == "Text") then
			entry[property] = source
			apply(self, instance, entry, property)
			instance:GetPropertyChangedSignal(property):Connect(function()
				if entry.applying then
					return
				end
				local current = (instance :: any)[property]
				if current == entry[property .. "Applied"] then
					return
				end
				entry[property] = current
				apply(self, instance, entry, property)
			end)
		end
	end
	instance.Destroying:Connect(function()
		self._entries[instance] = nil
	end)
end

Creator:Register(function(instance, class, props)
	Localization:Hook(instance, class, props)
end)

return Localization
