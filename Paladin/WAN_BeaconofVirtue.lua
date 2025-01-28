local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nBeaconofVirtue, nBeaconofVirtueUnitCap = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status  or not wan.PlayerState.Combat
     or not wan.IsSpellUsable(wan.spellData.BeaconofLight.id)
    then
        wan.UpdateSupportData(nil, wan.spellData.BeaconofLight.basename)
        return
    end

    local unitsNeedHeal = 0
    wan.HealUnitCountAoE[wan.spellData.BeaconofLight.basename] = wan.HealUnitCountAoE[wan.spellData.BeaconofLight.basename] or 1

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cBeaconofVirtue = wan.UnitDefensiveCooldownToValue(wan.spellData.BeaconofLight.id, groupUnitToken)

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cBeaconofVirtue, currentPercentHealth)
                if abilityValue > 0 then unitsNeedHeal = unitsNeedHeal + 1 end
                wan.UpdateSupportData(groupUnitToken, wan.spellData.BeaconofLight.basename, abilityValue, wan.spellData.BeaconofLight.icon, wan.spellData.BeaconofLight.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.BeaconofLight.basename)
            end
        end

        if unitsNeedHeal > 0 then

            if unitsNeedHeal > nBeaconofVirtueUnitCap then
                unitsNeedHeal = nBeaconofVirtueUnitCap
            end
            wan.HealUnitCountAoE[wan.spellData.BeaconofLight.basename] = unitsNeedHeal
            
        else
            wan.HealUnitCountAoE[wan.spellData.BeaconofLight.basename] = 1
        end
    end
end

-- Init frame 
local frameBeaconofVirtue = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        end
    end)
end
frameBeaconofVirtue:RegisterEvent("ADDON_LOADED")
frameBeaconofVirtue:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BeaconofLight.name == "Beacon of Virtue" and wan.spellData.BeaconofLight.known and wan.spellData.BeaconofLight.id
        wan.BlizzardEventHandler(frameBeaconofVirtue, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBeaconofVirtue, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nBeaconofVirtueUnitCap = wan.GetTraitDescriptionNumbers(wan.traitData.BeaconofLight.entryid, { 1 })
    end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if not wan.PlayerState.InHealerMode then
            wan.UpdateHealingData(nil, wan.spellData.BeaconofLight.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBeaconofVirtue, CheckAbilityValue, abilityActive)
    end
end)