local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nLunarBeamDmg, nLunarBeamHeal, nLunarBeamMaxRange = 0, 0, 10


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or not wan.CheckUnitBuff(nil, wan.spellData.BearForm.formattedName)
        or not wan.IsSpellUsable(wan.spellData.LunarBeam.id)
    then
        wan.UpdateAbilityData(wan.spellData.LunarBeam.basename)
        wan.UpdateMechanicData(wan.spellData.LunarBeam.basename)
        return
    end

    -- Check for valid unit
    local _, countValidUnit = wan.ValidUnitBoolCounter(nil, nLunarBeamMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.LunarBeam.basename)
        wan.UpdateMechanicData(wan.spellData.LunarBeam.basename)
        return
    end

    local cLunarBeamDmg = nLunarBeamDmg * countValidUnit
    local cLunarBeamHeal = nLunarBeamHeal

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1

    -- Crit layer
    cLunarBeamDmg = cLunarBeamDmg * wan.ValueFromCritical(wan.CritChance)

    -- Threat situation
    local isTanking = wan.IsTanking()

    -- Update ability data
    local damageValue = not isTanking and math.floor(cLunarBeamDmg) or 0 -- Update Ability Data
    local healValue = wan.UnitAbilityHealValue(playerUnitToken, cLunarBeamHeal, currentPercentHealth) -- Update Mechanic Data

    wan.UpdateMechanicData(wan.spellData.LunarBeam.basename, healValue, wan.spellData.LunarBeam.icon, wan.spellData.LunarBeam.name)
    wan.UpdateAbilityData(wan.spellData.LunarBeam.basename, damageValue, wan.spellData.LunarBeam.icon, wan.spellData.LunarBeam.name)
end

-- Init frame 
local frameLunarBeam = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nLunarBeamValues = wan.GetSpellDescriptionNumbers(wan.spellData.LunarBeam.id, { 2, 3 })
            nLunarBeamDmg = nLunarBeamValues[1]
            nLunarBeamHeal = nLunarBeamValues[2]
        end
    end)
end
frameLunarBeam:RegisterEvent("ADDON_LOADED")
frameLunarBeam:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.LunarBeam.known and wan.spellData.LunarBeam.id
        wan.BlizzardEventHandler(frameLunarBeam, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameLunarBeam, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameLunarBeam, CheckAbilityValue, abilityActive)
    end
end)
