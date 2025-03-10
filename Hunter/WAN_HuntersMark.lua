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

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]
    local formattedDebuffName = wan.spellData.HuntersMark.formattedName

    -- Check for valid unit
    local isValidUnit, _, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.HuntersMark.id)
    if not targetGUID or not isValidUnit then
        wan.UpdateMechanicData(wan.spellData.HuntersMark.basename)
        return
    end

    local checkHuntersMarkDebuff = wan.CheckUnitDebuff(nil, formattedDebuffName)
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
    local checkClassification = UnitIsBossMob(targetUnitToken) or false
    if (wan.PlayerState.Combat or not checkClassification) or checkClass == "ROGUE" or checkClass == "DRUID"then
        wan.UpdateMechanicData(wan.spellData.HuntersMark.basename)
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

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nHuntersMarkValue = wan.GetSpellDescriptionNumbers(wan.spellData.HuntersMark.id, { 2 })
            nHuntersMark = wan.AbilityPercentageToValue(nHuntersMarkValue)
        end
    end)
end
frameHuntersMark:RegisterEvent("ADDON_LOADED")
frameHuntersMark:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.HuntersMark.known and wan.spellData.HuntersMark.id
        wan.BlizzardEventHandler(frameHuntersMark, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameHuntersMark, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameHuntersMark, CheckAbilityValue, abilityActive)
    end
end)
