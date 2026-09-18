-- notext: hides the combat feedback text (damage, healing, misses, blocks, ...)
-- that Blizzard prints over the player and pet unit frames.
--
-- Nothing else is touched: no CVars, no floating/world combat text, no other
-- unit frames, and no other text on the player or pet frames.

local silenced = {}

-- Guarded so the SetText hook does not recurse into itself.
local function BlankText(region)
	if region.notextBlanking then
		return
	end

	region.notextBlanking = true
	region:SetText("")
	region.notextBlanking = nil
end

-- Keeps a single combat feedback region permanently empty and hidden.
local function Silence(region)
	if not region or silenced[region] then
		return
	end

	silenced[region] = true

	if region.SetText then
		region:SetText("")
	end
	region:Hide()

	hooksecurefunc(region, "Show", function(self)
		self:Hide()
	end)

	if region.SetText then
		hooksecurefunc(region, "SetText", BlankText)
	end

	if region.SetFormattedText then
		hooksecurefunc(region, "SetFormattedText", BlankText)
	end
end

-- CombatFeedback_OnCombatEvent writes into frame.feedbackText, so that is the
-- authoritative reference; the named regions are fallbacks in case a frame has
-- not run its OnLoad yet.
local function GetPlayerFeedbackText()
	if PlayerFrame then
		if PlayerFrame.feedbackText then
			return PlayerFrame.feedbackText
		end

		local content = PlayerFrame.PlayerFrameContent
		local contextual = content and content.PlayerFrameContentContextual
		if contextual and contextual.PlayerHitIndicator then
			return contextual.PlayerHitIndicator
		end
	end

	return PlayerHitIndicator
end

local function GetPetFeedbackText()
	if PetFrame then
		if PetFrame.feedbackText then
			return PetFrame.feedbackText
		end

		if PetFrame.PetFrameHitIndicator then
			return PetFrame.PetFrameHitIndicator
		end
	end

	return PetHitIndicator
end

local function ApplyAll()
	Silence(GetPlayerFeedbackText())
	Silence(GetPetFeedbackText())
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("PLAYER_LOGIN")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterUnitEvent("UNIT_PET", "player")
listener:SetScript("OnEvent", ApplyAll)

-- Blizzard's frames load before addons, so catch the common case immediately.
ApplyAll()
