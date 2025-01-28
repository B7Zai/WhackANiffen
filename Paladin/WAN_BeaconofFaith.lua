local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local percentValue = 10
local nBeaconofFaith = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.InGroup or not wan.PlayerState.InHealerMode
        or not wan.IsSpellUsable(wan.spellData.BeaconofFaith.id)
    then
        wan.UpdateSupportData(nil, wan.spellData.BeaconofFaith.basename)
        return
    end
    

    for groupUnitToken, _ in pairs(wan.GroupUnitID) do
        local checkBeaconofFaithBuff = wan.auraData[groupUnitToken]["buff_" .. wan.spellData.BeaconofFaith.basename]
        if checkBeaconofFaithBuff then
            wan.UpdateSupportData(nil, wan.spellData.BeaconofFaith.basename)
            return
        end
    end

    local _, _, idValidGroupUnit = wan.ValidGroupMembers()
    local roleValue = {}

    for groupUnitToken, _ in pairs(wan.GroupUnitID) do
        if idValidGroupUnit[groupUnitToken] then
            local checkBeaconofLightBuff = wan.auraData[groupUnitToken]["buff_" .. wan.spellData.BeaconofLight.basename]
            if not checkBeaconofLightBuff then
                if wan.UnitState.Role[groupUnitToken] == "TANK" then
                    roleValue[groupUnitToken] = 2
                elseif wan.UnitState.Role[groupUnitToken] == "HEALER" then
                    roleValue[groupUnitToken] = 1.5
                elseif wan.UnitState.Role[groupUnitToken] == "DAMAGER" then
                    roleValue[groupUnitToken] = 1
                end
            else
                roleValue[groupUnitToken] = 0
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

    local abilityValue = math.floor(nBeaconofFaith)
    wan.UpdateSupportData(nil, wan.spellData.BeaconofFaith.basename)
    wan.UpdateSupportData(unit, wan.spellData.BeaconofFaith.basename, abilityValue, wan.spellData.BeaconofFaith.icon, wan.spellData.BeaconofFaith.name)
end

-- Init frame 
local frameBeaconofFaith = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local nBeaconofLightValues = wan.GetSpellDescriptionNumbers(wan.spellData.BeaconofLight.id, { 1 })
            local nBeaconofFaithValues = wan.GetTraitDescriptionNumbers(wan.traitData.BeaconofFaith.entryid, { 1 }) * 0.01

            nBeaconofLightValues = nBeaconofLightValues * nBeaconofFaithValues
            
            nBeaconofFaith = wan.AbilityPercentageToValue(nBeaconofLightValues)
        end
    end)
end
frameBeaconofFaith:RegisterEvent("ADDON_LOADED")
frameBeaconofFaith:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BeaconofFaith.known and wan.spellData.BeaconofFaith.id
        wan.BlizzardEventHandler(frameBeaconofFaith, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameBeaconofFaith, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.BeaconofFaith.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.BeaconofFaith.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBeaconofFaith, CheckAbilityValue, abilityActive)
    end
end)