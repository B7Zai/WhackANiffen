local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local abilityActive = false
local nCelestialAlignment, nCelestialAlignmentMaxRange = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or wan.CheckUnitBuff(nil, wan.spellData.CatForm.formattedName)
        or wan.CheckUnitBuff(nil, wan.spellData.BearForm.formattedName)
        or not wan.IsSpellUsable(wan.spellData.CelestialAlignment.id)
    then
        wan.UpdateAbilityData(wan.spellData.CelestialAlignment.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nCelestialAlignmentMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.CelestialAlignment.basename)
        return
    end

    -- Base value
    local cCelestialAlignment = nCelestialAlignment
    local cdPotency = wan.CheckOffensiveCooldownPotency(cCelestialAlignment, isValidUnit, idValidUnit)


    -- Update ability data
    local abilityValue = cdPotency and math.floor(cCelestialAlignment) or 0
    wan.UpdateAbilityData(wan.spellData.CelestialAlignment.basename, abilityValue, wan.spellData.CelestialAlignment.icon, wan.spellData.CelestialAlignment.name)
end

-- Init frame 
local frameCelestialAlignment = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nCelestialAlignment = wan.OffensiveCooldownToValue(wan.spellData.CelestialAlignment.id)
            nCelestialAlignmentMaxRange = wan.spellData.CelestialAlignment.maxRange > 0 and wan.spellData.CelestialAlignment.maxRange or 40
        end
    end)
end
frameCelestialAlignment:RegisterEvent("ADDON_LOADED")
frameCelestialAlignment:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.CelestialAlignment.known and wan.spellData.CelestialAlignment.id
        wan.SetUpdateRate(frameCelestialAlignment, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameCelestialAlignment, abilityActive, "SPELLS_CHANGED", "UNIT_AURA",
            "PLAYER_EQUIPMENT_CHANGED")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameCelestialAlignment, CheckAbilityValue, abilityActive)
    end
end)
