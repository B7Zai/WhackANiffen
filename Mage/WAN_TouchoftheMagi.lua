local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nTouchoftheMagi = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.TouchoftheMagi.id)
    then
        wan.UpdateMechanicData(wan.spellData.TouchoftheMagi.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.TouchoftheMagi.maxRange)
    if countValidUnit == 0 then
        wan.UpdateMechanicData(wan.spellData.TouchoftheMagi.basename)
        return
    end

    -- Base value
    local cTouchoftheMagi = nTouchoftheMagi
    local cdPotency = wan.CheckOffensiveCooldownPotency(cTouchoftheMagi, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cTouchoftheMagi) or 0
    wan.UpdateMechanicData(wan.spellData.TouchoftheMagi.basename, abilityValue, wan.spellData.TouchoftheMagi.icon, wan.spellData.TouchoftheMagi.name)
end

-- Init frame 
local frameTouchoftheMagi = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nTouchoftheMagi = wan.OffensiveCooldownToValue(wan.spellData.TouchoftheMagi.id)
        end
    end)
end
frameTouchoftheMagi:RegisterEvent("ADDON_LOADED")
frameTouchoftheMagi:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.TouchoftheMagi.known and wan.spellData.TouchoftheMagi.id
        wan.BlizzardEventHandler(frameTouchoftheMagi, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameTouchoftheMagi, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameTouchoftheMagi, CheckAbilityValue, abilityActive)
    end
end)