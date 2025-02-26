local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nSymbioticRelationship = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.InGroup or not wan.PlayerState.InHealerMode
        or not wan.IsSpellUsable(wan.spellData.SymbioticRelationship.id)
    then
        wan.UpdateSupportData(nil, wan.spellData.SymbioticRelationship.basename)
        return
    end

    for groupUnitToken, _ in pairs(wan.GroupUnitID) do
        local checkSymbioticRelationshipBuff = wan.CheckUnitBuff(groupUnitToken, wan.spellData.SymbioticRelationship.formattedName)
        if checkSymbioticRelationshipBuff then
            wan.UpdateSupportData(nil, wan.spellData.SymbioticRelationship.basename)
            return
        end
    end

    local _, _, idValidGroupUnit = wan.ValidGroupMembers()
    local roleValue = {}

    for groupUnitToken, _ in pairs(wan.GroupUnitID) do
        if idValidGroupUnit[groupUnitToken] then
            if wan.UnitState.Role[groupUnitToken] == "TANK" then
                roleValue[groupUnitToken] = nSymbioticRelationship * 2
            elseif wan.UnitState.Role[groupUnitToken] == "HEALER" then
                roleValue[groupUnitToken] = nSymbioticRelationship * 1.5
            elseif wan.UnitState.Role[groupUnitToken] == "DAMAGER" then
                roleValue[groupUnitToken] = nSymbioticRelationship * 1
            end
        end
    end

    local highestValue = 0
    local unit = nil
    for groupUnitToken, value in pairs(roleValue) do
        if value > highestValue then
            highestValue = value
            unit = groupUnitToken
        end
    end

    local abilityValue = math.floor(highestValue)
    wan.UpdateSupportData(unit, wan.spellData.SymbioticRelationship.basename, abilityValue, wan.spellData.SymbioticRelationship.icon, wan.spellData.SymbioticRelationship.name)
end

-- Init frame 
local frameSymbioticRelationship = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local nSymbioticRelationshipValues = wan.GetSpellDescriptionNumbers(wan.spellData.SymbioticRelationship.id, { 1 })
            
            nSymbioticRelationship = wan.AbilityPercentageToValue(nSymbioticRelationshipValues)
        end
    end)
end
frameSymbioticRelationship:RegisterEvent("ADDON_LOADED")
frameSymbioticRelationship:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.SymbioticRelationship.known and wan.spellData.SymbioticRelationship.id
        wan.BlizzardEventHandler(frameSymbioticRelationship, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameSymbioticRelationship, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.SymbioticRelationship.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.SymbioticRelationship.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSymbioticRelationship, CheckAbilityValue, abilityActive)
    end
end)