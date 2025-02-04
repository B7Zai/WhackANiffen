local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init data
local abilityActive = false
local nTrueshot, nTrueShotMaxRange = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.auraData.player["buff_" .. wan.spellData.Trueshot.basename]
        or not wan.IsSpellUsable(wan.spellData.Trueshot.id)
    then
        wan.UpdateAbilityData(wan.spellData.Trueshot.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nTrueShotMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.Trueshot.basename)
        return
    end

    -- Base value
    local cTrueshot = nTrueshot
    local cdPotency = wan.CheckOffensiveCooldownPotency(cTrueshot, isValidUnit, idValidUnit)


    -- Update ability data
    local abilityValue = cdPotency and math.floor(cTrueshot) or 0
    wan.UpdateAbilityData(wan.spellData.Trueshot.basename, abilityValue, wan.spellData.Trueshot.icon, wan.spellData.Trueshot.name)
end

-- Init frame 
local frameTrueshot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nTrueshot = wan.OffensiveCooldownToValue(wan.spellData.Trueshot.id)
            nTrueShotMaxRange = wan.spellData.Trueshot.maxRange > 0 and wan.spellData.Trueshot.maxRange or 40
        end
    end)
end
frameTrueshot:RegisterEvent("ADDON_LOADED")
frameTrueshot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Trueshot.known and wan.spellData.Trueshot.id
        wan.SetUpdateRate(frameTrueshot, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameTrueshot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameTrueshot, CheckAbilityValue, abilityActive)
    end
end)
