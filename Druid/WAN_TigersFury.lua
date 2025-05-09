local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nTigersFury, eTigersFury, eTigersFuryPercentage = 0, 0, 0
local currentEnergy, energyMax, energyPercentage = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.CheckUnitBuff(nil, wan.spellData.CatForm.formattedName)
        or not wan.IsSpellUsable(wan.spellData.TigersFury.id)
    then
        wan.UpdateMechanicData(wan.spellData.TigersFury.basename)
        return
    end

    -- Energy check and early exit
    currentEnergy = UnitPower("player", 3) or 0
    energyPercentage = (currentEnergy / energyMax) * 100
    if energyPercentage >= (100 - eTigersFuryPercentage)
    then
        wan.UpdateMechanicData(wan.spellData.TigersFury.basename)
        return
    end

    -- Base value
    local cTigersFury = nTigersFury

     -- Update AbilityData
    local abilityValue = math.floor(cTigersFury)
    wan.UpdateMechanicData(wan.spellData.TigersFury.basename, abilityValue, wan.spellData.TigersFury.icon, wan.spellData.TigersFury.name)
end

-- Init frame 
local frameTigersFury = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        
        if event == "SPELLS_CHANGED" then
            energyMax = UnitPowerMax("player", 3) or 100
        end

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local valuesTigersFury = wan.GetSpellDescriptionNumbers(wan.spellData.TigersFury.id, { 1, 2 })
            eTigersFury = valuesTigersFury[1]
            eTigersFuryPercentage = (eTigersFury / energyMax) * 100
            nTigersFury = wan.AbilityPercentageToValue(valuesTigersFury[2])
        end
    end)
end
frameTigersFury:RegisterEvent("ADDON_LOADED")
frameTigersFury:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.TigersFury.known and wan.spellData.TigersFury.id
        wan.BlizzardEventHandler(frameTigersFury, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameTigersFury, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameTigersFury, CheckAbilityValue, abilityActive)
    end
end)