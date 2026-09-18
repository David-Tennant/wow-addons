-- onebag: strips the bag bar down to the main backpack button.
--
-- The four bag slots, the reagent bag slot and the expand/collapse arrow are
-- hidden, then BagsBar is shrunk to exactly the backpack button. Because
-- BagsBar is still the real Edit Mode system frame, Edit Mode keeps working --
-- it just gives you a one-button grab handle instead of a whole bar.
--
-- Nothing else is touched: no CVars, no bag frames, no Edit Mode layout data.

local SLOT_NAMES = {
	"CharacterBag0Slot",
	"CharacterBag1Slot",
	"CharacterBag2Slot",
	"CharacterBag3Slot",
	"CharacterReagentBag0Slot",
	"BagBarExpandToggle",
}

local hooked = {}
local originalPoints, originalWidth, originalHeight
local applying = false
local pending = false

local function IsEnabled()
	return not (OneBagDB and OneBagDB.disabled)
end

local function GetBar()
	return BagsBar
end

local function GetBackpack()
	local bar = GetBar()
	return MainMenuBarBackpackButton or (bar and bar.MainMenuBarBackpackButton)
end

-- Hidden buttons are re-shown by Blizzard whenever a bag is equipped or the
-- bar relayouts, so each one gets a one-time OnShow hook that hides it again.
local function Silence(button)
	if not button then
		return
	end

	if not hooked[button] then
		hooked[button] = true
		button:HookScript("OnShow", function(self)
			if IsEnabled() and not InCombatLockdown() then
				self:Hide()
			end
		end)
	end

	button:SetAlpha(0)
	button:EnableMouse(false)

	if button:IsShown() and not InCombatLockdown() then
		button:Hide()
	end
end

local function Restore(button)
	if not button then
		return
	end

	button:SetAlpha(1)
	button:EnableMouse(true)

	if not InCombatLockdown() then
		button:Show()
	end
end

local function Apply()
	if applying then
		return
	end

	local bar, backpack = GetBar(), GetBackpack()
	if not bar or not backpack then
		return
	end

	-- Bag buttons are protected, so never touch them mid-combat; redo the work
	-- once the lockdown lifts instead.
	if InCombatLockdown() then
		pending = true
		return
	end

	applying = true

	if not originalPoints then
		originalPoints = {}
		for i = 1, backpack:GetNumPoints() do
			originalPoints[i] = { backpack:GetPoint(i) }
		end
		originalWidth, originalHeight = bar:GetSize()
	end

	for _, name in ipairs(SLOT_NAMES) do
		Silence(_G[name])
	end

	-- Let the bar re-flow around the now-hidden children before pinning the
	-- backpack button, otherwise the layout overwrites our anchor.
	if bar.Layout then
		bar:Layout()
	end

	backpack:ClearAllPoints()
	backpack:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)

	local width, height = backpack:GetSize()
	if width > 0 and height > 0 then
		bar:SetSize(width, height)
	end

	applying = false
end

local function Unapply()
	local bar, backpack = GetBar(), GetBackpack()
	if not bar or not backpack or InCombatLockdown() then
		return
	end

	applying = true

	for _, name in ipairs(SLOT_NAMES) do
		Restore(_G[name])
	end

	if originalPoints then
		backpack:ClearAllPoints()
		for _, point in ipairs(originalPoints) do
			backpack:SetPoint(unpack(point))
		end
		bar:SetSize(originalWidth, originalHeight)
	end

	if bar.Layout then
		bar:Layout()
	end

	applying = false
end

local function Refresh()
	if IsEnabled() then
		Apply()
	else
		Unapply()
	end
end

-- Blizzard relayouts the bar on its own (Edit Mode, equipping a bag, the
-- backpack toggle), so re-pin after any of those.
local function InstallHooks()
	local bar = GetBar()
	if bar and not hooked[bar] then
		hooked[bar] = true

		if bar.Layout then
			hooksecurefunc(bar, "Layout", Refresh)
		end
		bar:HookScript("OnShow", Refresh)
	end

	local manager = EditModeManagerFrame
	if manager and not hooked[manager] then
		hooked[manager] = true

		if manager.EnterEditMode then
			hooksecurefunc(manager, "EnterEditMode", Refresh)
		end
		if manager.ExitEditMode then
			hooksecurefunc(manager, "ExitEditMode", Refresh)
		end
	end
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("PLAYER_LOGIN")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterEvent("PLAYER_REGEN_ENABLED")
listener:RegisterEvent("BAG_CONTAINER_UPDATE")
listener:RegisterEvent("BAG_UPDATE_DELAYED")
listener:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" and not pending then
		return
	end

	pending = false
	InstallHooks()
	Refresh()
end)

SLASH_ONEBAG1 = "/onebag"
SlashCmdList.ONEBAG = function(msg)
	local command = strtrim(strlower(msg or ""))

	if command == "on" or command == "off" or command == "toggle" or command == "" then
		OneBagDB = OneBagDB or {}

		if command == "on" then
			OneBagDB.disabled = false
		elseif command == "off" then
			OneBagDB.disabled = true
		else
			OneBagDB.disabled = not OneBagDB.disabled
		end

		Refresh()
		print(("onebag: %s. Bag bar %s."):format(
			IsEnabled() and "enabled" or "disabled",
			IsEnabled() and "reduced to the backpack button" or "restored"))
	else
		print("onebag: /onebag [on|off|toggle]")
	end
end

-- Blizzard's frames load before addons, so catch the common case immediately.
InstallHooks()
Refresh()
