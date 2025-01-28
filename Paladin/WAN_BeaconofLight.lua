local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nBeaconofLight = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.InGroup or not wan.PlayerState.InHealerMode
        or not wan.IsSpellUsable(wan.spellData.BeaconofLight.id)
    then
        wan.UpdateSupportData(nil, wan.spellData.BeaconofLight.basename)
        return
    end

    for groupUnitToken, _ in pairs(wan.GroupUnitID) do
        local checkBeaconofLightBuff = wan.CheckUnitBuff(groupUnitToken, wan.spellData.BeaconofLight.basename)
        if checkBeaconofLightBuff then
            wan.UpdateSupportData(nil, wan.spellData.BeaconofLight.basename)
            return
        end
    end

    local _, _, idValidGroupUnit = wan.ValidGroupMembers()
    local roleValue = {}

    for groupUnitToken, _ in pairs(wan.GroupUnitID) do
        if idValidGroupUnit[groupUnitToken] then
            if wan.UnitState.Role[groupUnitToken] == "TANK" then
                roleValue[groupUnitToken] = nBeaconofLight * 2
            elseif wan.UnitState.Role[groupUnitToken] == "HEALER" then
                roleValue[groupUnitToken] = nBeaconofLight * 1.5
            elseif wan.UnitState.Role[groupUnitToken] == "DAMAGER" then
                roleValue[groupUnitToken] = nBeaconofLight * 1
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
    wan.UpdateSupportData(unit, wan.spellData.BeaconofLight.basename, abilityValue, wan.spellData.BeaconofLight.icon, wan.spellData.BeaconofLight.name)
end

-- Init frame 
local frameBeaconofLight = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local nBeaconofLightValues = wan.GetSpellDescriptionNumbers(wan.spellData.BeaconofLight.id, { 1 })
            
            nBeaconofLight = wan.AbilityPercentageToValue(nBeaconofLightValues)
        end
    end)
end
frameBeaconofLight:RegisterEvent("ADDON_LOADED")
frameBeaconofLight:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BeaconofLight.name == "Beacon of Light" and wan.spellData.BeaconofLight.known and wan.spellData.BeaconofLight.id
        wan.BlizzardEventHandler(frameBeaconofLight, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameBeaconofLight, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.BeaconofLight.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.BeaconofLight.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBeaconofLight, CheckAbilityValue, abilityActive)
    end
end)