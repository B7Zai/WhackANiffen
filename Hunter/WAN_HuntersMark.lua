local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init data
local abilityActive = false
local nHuntersMark = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.HuntersMark.id)
    then
        wan.UpdateMechanicData(wan.spellData.HuntersMark.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, _, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.HuntersMark.id)
    if not isValidUnit then
        wan.UpdateMechanicData(wan.spellData.HuntersMark.basename)
        return
    end

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local formattedDebuffName = wan.spellData.HuntersMark.basename
    local checkHuntersMarkDebuff = wan.CheckUnitDebuff(targetUnitToken, formattedDebuffName)
    if checkHuntersMarkDebuff then
        wan.UpdateMechanicData(wan.spellData.HuntersMark.basename)
        return
    end

    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkUnitHuntersMarkDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)
        if checkUnitHuntersMarkDebuff then
            wan.UpdateMechanicData(wan.spellData.HuntersMark.basename)
            return
        end
    end

    local checkClass = wan.UnitState.Class[targetUnitToken]
    local checkClassification = UnitIsBossMob(targetUnitToken)
    local checkHuntersMark = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.spellData.HuntersMark.basename]
    local enablerHuntersMark = (not wan.PlayerState.Combat and checkClassification) or checkClass == "ROGUE" or checkClass == "DRUID"

    if checkHuntersMark or not enablerHuntersMark then
        wan.UpdateAbilityData(wan.spellData.HuntersMark.basename)
        return
    end

    -- Base value
    local cHuntersMark = nHuntersMark

    -- Update ability data
    local abilityValue = cHuntersMark
    wan.UpdateMechanicData(wan.spellData.HuntersMark.basename, abilityValue, wan.spellData.HuntersMark.icon, wan.spellData.HuntersMark.name)
end

-- Local frame and event handler
local frameHuntersMark = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    self:SetScript("OnEvent", function(self, event, ...)
        if abilityActive and event == "PLAYER_SOFT_ENEMY_CHANGED" then
            CheckAbilityValue()
        end
    end)
end
frameHuntersMark:RegisterEvent("ADDON_LOADED")
frameHuntersMark:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.HuntersMark.known and wan.spellData.HuntersMark.id
        wan.BlizzardEventHandler(frameHuntersMark, abilityActive, "PLAYER_SOFT_ENEMY_CHANGED")
    end

    if event == "TRAIT_DATA_READY" then
        local nHuntersMarkValue = wan.GetSpellDescriptionNumbers(wan.spellData.HuntersMark.id, { 2 })
        nHuntersMark = wan.AbilityPercentageToValue(nHuntersMarkValue)
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameHuntersMark, CheckAbilityValue, abilityActive)
    end
end)
