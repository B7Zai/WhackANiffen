local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nTranquility = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or wan.CheckUnitBuff(nil, wan.spellData.CatForm.formattedName)
        or wan.CheckUnitBuff(nil, wan.spellData.BearForm.formattedName)
        or wan.CheckUnitBuff(nil, wan.spellData.MoonkinForm.formattedName)
        or not wan.PlayerState.Combat or not wan.IsSpellUsable(wan.spellData.Tranquility.id)
    then
        wan.UpdateMechanicData(wan.spellData.Tranquility.basename)
        wan.UpdateSupportData(nil, wan.spellData.Tranquility.basename)
        return
    end

    local unitsNeedHeal = 0
    wan.HealUnitCountAoE[wan.spellData.Tranquility.basename] = wan.HealUnitCountAoE[wan.spellData.Tranquility.basename] or 1

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cTranquility = wan.UnitDefensiveCooldownToValue(wan.spellData.Tranquility.id, groupUnitToken)

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cTranquility, currentPercentHealth)
                if abilityValue > 0 then unitsNeedHeal = unitsNeedHeal + 1 end
                wan.UpdateSupportData(groupUnitToken, wan.spellData.Tranquility.basename, abilityValue, wan.spellData.Tranquility.icon, wan.spellData.Tranquility.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.Tranquility.basename)
            end
        end

        if unitsNeedHeal > 0 then
            wan.HealUnitCountAoE[wan.spellData.Tranquility.basename] = unitsNeedHeal
        else
            wan.HealUnitCountAoE[wan.spellData.Tranquility.basename] = 1
        end
    end
end

-- Init frame 
local frameTranquility = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        end
    end)
end
frameTranquility:RegisterEvent("ADDON_LOADED")
frameTranquility:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Tranquility.known and wan.spellData.Tranquility.id
        wan.BlizzardEventHandler(frameTranquility, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameTranquility, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if not wan.PlayerState.InHealerMode then
            wan.UpdateHealingData(nil, wan.spellData.Tranquility.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameTranquility, CheckAbilityValue, abilityActive)
    end
end)