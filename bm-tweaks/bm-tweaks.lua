-- bm-tweaks: restyles the stack count on the Cobra Fang buff in Blizzard's
-- Cooldown Manager as large bright blue text.
--
-- Only the stack (applications) text is touched. The cooldown/duration text,
-- the icon and every other tracked spell keep Blizzard's styling. Item frames
-- are pooled and reused for different spells, so any stack text we restyled
-- is restored when its frame is handed a different spell.

local SPELL_NAME = "Cobra Fang"
local FONT_SIZE = 22
local FONT_FLAGS = "OUTLINE"
local COLOR_R, COLOR_G, COLOR_B = 0, 0.6, 1

local VIEWERS = {
	"BuffIconCooldownViewer",
	"BuffBarCooldownViewer",
	"EssentialCooldownViewer",
	"UtilityCooldownViewer",
}

local original = {}
local hookedItems = {}
local hookedViewers = {}

local function IsFontString(region)
	return type(region) == "table" and region.GetObjectType and region:GetObjectType() == "FontString"
end

-- Icon items keep the count at Applications.Applications, bar items at
-- Icon.Applications.
local function GetStackText(item)
	local apps = item.Applications
	if IsFontString(apps) then
		return apps
	end
	if apps and IsFontString(apps.Applications) then
		return apps.Applications
	end
	local icon = item.Icon
	if icon and IsFontString(icon.Applications) then
		return icon.Applications
	end
end

local function NameMatches(spellID)
	if type(spellID) ~= "number" or (issecretvalue and issecretvalue(spellID)) then
		return false
	end
	return C_Spell.GetSpellName(spellID) == SPELL_NAME
end

local function IsCobraFang(item)
	local cooldownID = item.GetCooldownID and item:GetCooldownID() or item.cooldownID
	if not cooldownID or (issecretvalue and issecretvalue(cooldownID)) then
		return false
	end

	local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
	if not ok or not info then
		return false
	end

	if NameMatches(info.spellID) or NameMatches(info.overrideSpellID) then
		return true
	end
	if info.linkedSpellIDs then
		for _, linked in ipairs(info.linkedSpellIDs) do
			if NameMatches(linked) then
				return true
			end
		end
	end
	return false
end

local function Restyle(text)
	if not original[text] then
		local font, size, flags = text:GetFont()
		original[text] = { font = font, size = size, flags = flags, color = { text:GetTextColor() } }
	end
	text:SetFont(original[text].font, FONT_SIZE, FONT_FLAGS)
	text:SetTextColor(COLOR_R, COLOR_G, COLOR_B)
end

local function Restore(text)
	local saved = original[text]
	if not saved then
		return
	end
	text:SetFont(saved.font, saved.size, saved.flags)
	text:SetTextColor(unpack(saved.color))
	original[text] = nil
end

local function UpdateItem(item)
	local text = GetStackText(item)
	if not text then
		return
	end
	if IsCobraFang(item) then
		Restyle(text)
	else
		Restore(text)
	end
end

local function HookItem(item)
	if hookedItems[item] then
		return
	end
	hookedItems[item] = true
	if item.SetCooldownID then
		hooksecurefunc(item, "SetCooldownID", UpdateItem)
	end
	if item.ClearCooldownID then
		hooksecurefunc(item, "ClearCooldownID", UpdateItem)
	end
end

local function UpdateViewer(viewer)
	local items = viewer.GetItemFrames and viewer:GetItemFrames() or { viewer:GetChildren() }
	for _, item in ipairs(items) do
		HookItem(item)
		UpdateItem(item)
	end
end

local function UpdateAll()
	for _, name in ipairs(VIEWERS) do
		local viewer = _G[name]
		if viewer then
			if not hookedViewers[viewer] and viewer.RefreshLayout then
				hookedViewers[viewer] = true
				hooksecurefunc(viewer, "RefreshLayout", UpdateViewer)
			end
			UpdateViewer(viewer)
		end
	end
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("PLAYER_LOGIN")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
listener:RegisterEvent("SPELLS_CHANGED")
listener:SetScript("OnEvent", function()
	-- Let the viewers build their item frames first.
	C_Timer.After(0, UpdateAll)
end)
