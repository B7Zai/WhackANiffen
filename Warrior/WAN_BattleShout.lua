local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nBattleShout = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.BattleShout.id)
        or not wan.CheckClassBuff(wan.spellData.BattleShout.formattedName)
    then
        wan.UpdateMechanicData(wan.spellData.BattleShout.basename)
        return
    end

    -- Base value
    local cBattleShout = nBattleShout

    -- Update ability data
    local abilityValue = cBattleShout
    wan.UpdateMechanicData(wan.spellData.BattleShout.basename, abilityValue, wan.spellData.BattleShout.icon, wan.spellData.BattleShout.name)
end

-- Init frame 
local frameBattleShout = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nBattleShoutValue = wan.GetSpellDescriptionNumbers(wan.spellData.BattleShout.id, { 1 })
            nBattleShout = wan.AbilityPercentageToValue(nBattleShoutValue)
        end
    end)
end
frameBattleShout:RegisterEvent("ADDON_LOADED")
frameBattleShout:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BattleShout.known and wan.spellData.BattleShout.id
        wan.BlizzardEventHandler(frameBattleShout, abilityActive, "UNIT_AURA", "SPELLS_CHANGED", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBattleShout, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBattleShout, CheckAbilityValue, abilityActive)
    end
end)
