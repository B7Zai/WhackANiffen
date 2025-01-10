local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init data
local abilityActive = false
local nBestialWrath, nBestialWrathMaxRange = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player["buff_" .. wan.spellData.BestialWrath.basename]
     or not wan.IsSpellUsable(wan.spellData.BestialWrath.id)
    then
        wan.UpdateAbilityData(wan.spellData.BestialWrath.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nBestialWrathMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.BestialWrath.basename)
        return
    end

    -- Base value
    local cBestialWrath = nBestialWrath
    local cdPotency = wan.CheckOffensiveCooldownPotency(cBestialWrath, isValidUnit, idValidUnit)


    -- Update ability data
    local abilityValue = cdPotency and math.floor(cBestialWrath) or 0
    wan.UpdateAbilityData(wan.spellData.BestialWrath.basename, abilityValue, wan.spellData.BestialWrath.icon, wan.spellData.BestialWrath.name)
end

-- Init frame 
local frameBestialWrath = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBestialWrath = wan.OffensiveCooldownToValue(wan.spellData.BestialWrath.id)
            nBestialWrathMaxRange = wan.spellData.BestialWrath.maxRange > 0 and wan.spellData.BestialWrath.maxRange or 40
        end
    end)
end
frameBestialWrath:RegisterEvent("ADDON_LOADED")
frameBestialWrath:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BestialWrath.known and wan.spellData.BestialWrath.id
        wan.SetUpdateRate(frameBestialWrath, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameBestialWrath, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBestialWrath, CheckAbilityValue, abilityActive)
    end
end)
