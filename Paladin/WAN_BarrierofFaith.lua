local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nBarrierofFaith = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
     or not wan.IsSpellUsable(wan.spellData.BarrierofFaith.id)
    then
        wan.UpdateMechanicData(wan.spellData.BarrierofFaith.basename)
        wan.UpdateSupportData(nil, wan.spellData.BarrierofFaith.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do
            if idValidGroupUnit[groupUnitToken] then
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cBarrierofFaith = wan.UnitDefensiveCooldownToValue(wan.spellData.BarrierofFaith.id, groupUnitToken)

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cBarrierofFaith, currentPercentHealth)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.BarrierofFaith.basename, abilityValue, wan.spellData.BarrierofFaith.icon, wan.spellData.BarrierofFaith.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.BarrierofFaith.basename)
            end
        end
    else
        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local cBarrierofFaith = nBarrierofFaith

        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cBarrierofFaith, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.BarrierofFaith.basename, abilityValue, wan.spellData.BarrierofFaith.icon, wan.spellData.BarrierofFaith.name)
    end
end

-- Init frame 
local frameBarrierofFaith = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBarrierofFaith = wan.DefensiveCooldownToValue(wan.spellData.BarrierofFaith.id)
        end
    end)
end
frameBarrierofFaith:RegisterEvent("ADDON_LOADED")
frameBarrierofFaith:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BarrierofFaith.known and wan.spellData.BarrierofFaith.id
        wan.BlizzardEventHandler(frameBarrierofFaith, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBarrierofFaith, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.BarrierofFaith.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.BarrierofFaith.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBarrierofFaith, CheckAbilityValue, abilityActive)
    end
end)