local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nBlessingofSummer = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.BlessingofSummer.id)
    then
        wan.UpdateMechanicData(wan.spellData.BlessingofSummer.basename)
        wan.UpdateSupportData(nil, wan.spellData.BlessingofSummer.basename)
        return
    end

    local _, _, idValidGroupUnit = wan.ValidGroupMembers()
    local checkName = wan.spellData.BlessingofSummer.name

    if wan.PlayerState.InGroup then
        local roleValue = {}

        for groupUnitToken, _ in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then

                if checkName == "Blessing of Summer" then
                    if wan.UnitState.Role[groupUnitToken] == "TANK" then
                        roleValue[groupUnitToken] = nBlessingofSummer * 2
                    elseif wan.UnitState.Role[groupUnitToken] == "HEALER" then
                        roleValue[groupUnitToken] = nBlessingofSummer * 1
                    elseif wan.UnitState.Role[groupUnitToken] == "DAMAGER" then
                        roleValue[groupUnitToken] = nBlessingofSummer * 1.5
                    end
                elseif checkName == "Blessing of Autumn" then
                    if wan.UnitState.Role[groupUnitToken] == "TANK" then
                        roleValue[groupUnitToken] = nBlessingofSummer * 1
                    elseif wan.UnitState.Role[groupUnitToken] == "HEALER" then
                        roleValue[groupUnitToken] = nBlessingofSummer * 1.5
                    elseif wan.UnitState.Role[groupUnitToken] == "DAMAGER" then
                        roleValue[groupUnitToken] = nBlessingofSummer * 2
                    end
                elseif checkName == "Blessing of Winter" then
                    if wan.UnitState.Role[groupUnitToken] == "TANK" then
                        roleValue[groupUnitToken] = nBlessingofSummer * 0
                    elseif wan.UnitState.Role[groupUnitToken] == "HEALER" then
                        roleValue[groupUnitToken] = nBlessingofSummer * 1
                    elseif wan.UnitState.Role[groupUnitToken] == "DAMAGER" then
                        roleValue[groupUnitToken] = nBlessingofSummer * 0
                    end
                elseif checkName == "Blessing of Spring" then
                    if wan.UnitState.Role[groupUnitToken] == "TANK" then
                        roleValue[groupUnitToken] = nBlessingofSummer * 2
                    elseif wan.UnitState.Role[groupUnitToken] == "HEALER" then
                        roleValue[groupUnitToken] = nBlessingofSummer * 1.5
                    elseif wan.UnitState.Role[groupUnitToken] == "DAMAGER" then
                        roleValue[groupUnitToken] = nBlessingofSummer * 1
                    end
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
        wan.UpdateSupportData(unit, wan.spellData.BlessingofSummer.basename, abilityValue, wan.spellData.BlessingofSummer.icon, wan.spellData.BlessingofSummer.name)
    else

        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.BlessingofSummer.maxRange)
        if countValidUnit == 0 then
            wan.UpdateMechanicData(wan.spellData.BlessingofSummer.basename)
            return
        end

        local cBlessingofSummer = nBlessingofSummer      
        local cdPotency = wan.CheckOffensiveCooldownPotency(cBlessingofSummer, isValidUnit, idValidUnit)

        -- Update ability data
        local abilityValue = cdPotency and math.floor(cBlessingofSummer) or 0
        wan.UpdateMechanicData(wan.spellData.BlessingofSummer.basename, abilityValue, wan.spellData.BlessingofSummer.icon, wan.spellData.BlessingofSummer.name)
    end
end

-- Init frame 
local frameBeaconofLight = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nBlessingofSummer = wan.OffensiveCooldownToValue(wan.spellData.BlessingofSummer.id)
        end
    end)
end
frameBeaconofLight:RegisterEvent("ADDON_LOADED")
frameBeaconofLight:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BlessingofSummer.known and wan.spellData.BlessingofSummer.id
        wan.BlizzardEventHandler(frameBeaconofLight, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameBeaconofLight, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.BlessingofSummer.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.BlessingofSummer.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBeaconofLight, CheckAbilityValue, abilityActive)
    end
end)