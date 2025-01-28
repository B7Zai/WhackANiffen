local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nAuraMastery = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.auraData.player.buff_DevotionAura
        or not wan.PlayerState.Combat or not wan.IsSpellUsable(wan.spellData.AuraMastery.id)
    then
        wan.UpdateSupportData(nil, wan.spellData.AuraMastery.basename)
        return
    end

    local unitsNeedHeal = 0
    wan.HealUnitCountAoE[wan.spellData.AuraMastery.basename] = wan.HealUnitCountAoE[wan.spellData.AuraMastery.basename] or 1

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cAuraMastery = wan.UnitDefensiveCooldownToValue(wan.spellData.AuraMastery.id, groupUnitToken)

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cAuraMastery, currentPercentHealth)
                if abilityValue > 0 then unitsNeedHeal = unitsNeedHeal + 1 end
                wan.UpdateSupportData(groupUnitToken, wan.spellData.AuraMastery.basename, abilityValue, wan.spellData.AuraMastery.icon, wan.spellData.AuraMastery.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.AuraMastery.basename)
            end
        end

        if unitsNeedHeal > 0 then
            wan.HealUnitCountAoE[wan.spellData.AuraMastery.basename] = unitsNeedHeal
        else
            wan.HealUnitCountAoE[wan.spellData.AuraMastery.basename] = 1
        end
    end
end

-- Init frame 
local frameAuraMastery = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        end
    end)
end
frameAuraMastery:RegisterEvent("ADDON_LOADED")
frameAuraMastery:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.AuraMastery.known and wan.spellData.AuraMastery.id
        wan.BlizzardEventHandler(frameAuraMastery, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameAuraMastery, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if not wan.PlayerState.InHealerMode then
            wan.UpdateHealingData(nil, wan.spellData.AuraMastery.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameAuraMastery, CheckAbilityValue, abilityActive)
    end
end)