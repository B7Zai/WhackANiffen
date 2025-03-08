local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init data
local abilityActive = false
local nCallOfTheWild, nCallOfTheWildMaxRange = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.CheckUnitBuff(nil, wan.spellData.CalloftheWild.formattedName)
        or not wan.IsSpellUsable(wan.spellData.CalloftheWild.id)
    then
        wan.UpdateAbilityData(wan.spellData.CalloftheWild.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nCallOfTheWildMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.CalloftheWild.basename)
        return
    end

    -- Base value
    local cCallOfTheWild = nCallOfTheWild
    local cdPotency = wan.CheckOffensiveCooldownPotency(cCallOfTheWild, isValidUnit, idValidUnit)


    -- Update ability data
    local abilityValue = cdPotency and math.floor(cCallOfTheWild) or 0
    wan.UpdateAbilityData(wan.spellData.CalloftheWild.basename, abilityValue, wan.spellData.CalloftheWild.icon, wan.spellData.CalloftheWild.name)
end

-- Init frame 
local frameCallOfTheWild = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nCallOfTheWild = wan.OffensiveCooldownToValue(wan.spellData.CalloftheWild.id)
            nCallOfTheWildMaxRange = wan.spellData.CalloftheWild.maxRange > 0 and wan.spellData.CalloftheWild.maxRange or 40
        end
    end)
end
frameCallOfTheWild:RegisterEvent("ADDON_LOADED")
frameCallOfTheWild:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.CalloftheWild.known and wan.spellData.CalloftheWild.id
        wan.SetUpdateRate(frameCallOfTheWild, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameCallOfTheWild, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameCallOfTheWild, CheckAbilityValue, abilityActive)
    end
end)
