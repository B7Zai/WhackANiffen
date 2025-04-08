local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nGroveGuardians = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or not wan.PlayerState.Combat
        or wan.CheckUnitBuff(nil, wan.spellData.CatForm.formattedName)
        or wan.CheckUnitBuff(nil, wan.spellData.BearForm.formattedName)
        or wan.CheckUnitBuff(nil, wan.spellData.MoonkinForm.formattedName)
        or not wan.IsSpellUsable(wan.spellData.GroveGuardians.id)
    then
        wan.UpdateMechanicData(wan.spellData.GroveGuardians.basename)
        wan.UpdateSupportData(nil, wan.spellData.GroveGuardians.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do
            if idValidGroupUnit[groupUnitToken] then
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cGroveGuardians = wan.UnitDefensiveCooldownToValue(wan.spellData.GroveGuardians.id, groupUnitToken)

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cGroveGuardians, currentPercentHealth)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.GroveGuardians.basename, abilityValue, wan.spellData.GroveGuardians.icon, wan.spellData.GroveGuardians.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.GroveGuardians.basename)
            end
        end
    else
        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local cGroveGuardians = nGroveGuardians

        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cGroveGuardians, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.GroveGuardians.basename, abilityValue, wan.spellData.GroveGuardians.icon, wan.spellData.GroveGuardians.name)
    end
end

-- Init frame 
local frameGroveGuardians = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nGroveGuardians = wan.DefensiveCooldownToValue(wan.spellData.GroveGuardians.id)
        end
    end)
end
frameGroveGuardians:RegisterEvent("ADDON_LOADED")
frameGroveGuardians:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.GroveGuardians.known and wan.spellData.GroveGuardians.id
        wan.BlizzardEventHandler(frameGroveGuardians, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameGroveGuardians, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.GroveGuardians.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.GroveGuardians.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameGroveGuardians, CheckAbilityValue, abilityActive)
    end
end)