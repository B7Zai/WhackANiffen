local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nFlourishHeal = 0
local nFlourish = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
        or not wan.PlayerState.Combat or not wan.IsSpellUsable(wan.spellData.Flourish.id)
    then
        wan.UpdateMechanicData(wan.spellData.Flourish.basename)
        wan.UpdateSupportData(nil, wan.spellData.Flourish.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local _, countHots = wan.GetUnitHotValues(groupUnitToken)
                local cFlourishHeal = wan.UnitAbilityPercentageToValue(groupUnitToken, nFlourishHeal)
                cFlourishHeal = cFlourishHeal * countHots
                cFlourishHeal = nFlourish <= cFlourishHeal and cFlourishHeal or 0

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cFlourishHeal, currentPercentHealth)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.Flourish.basename, abilityValue, wan.spellData.Flourish.icon, wan.spellData.Flourish.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.Flourish.basename)
            end
        end
    else
        local unitToken = "player"
        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local _, countHots = wan.GetUnitHotValues(unitToken)
        local cFlourishHeal = wan.UnitAbilityPercentageToValue(unitToken, nFlourishHeal)
        
        cFlourishHeal = cFlourishHeal * countHots
        cFlourishHeal = cFlourishHeal >= nFlourish and cFlourishHeal or 0

        local abilityValue = wan.UnitAbilityHealValue(unitToken, cFlourishHeal, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.Flourish.basename, abilityValue, wan.spellData.Flourish.icon, wan.spellData.Flourish.name)
    end
end

-- Init frame 
local frameFlourish = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nFlourishHeal = wan.GetSpellDescriptionNumbers(wan.spellData.Flourish.id, { 3 })
            nFlourish = wan.DefensiveCooldownToValue(wan.spellData.Flourish.id)
        end
    end)
end
frameFlourish:RegisterEvent("ADDON_LOADED")
frameFlourish:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Flourish.known and wan.spellData.Flourish.id
        wan.BlizzardEventHandler(frameFlourish, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFlourish, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.Flourish.basename)
        else
            wan.UpdateHealingData(nil, wan.spellData.Flourish.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFlourish, CheckAbilityValue, abilityActive)
    end
end)
