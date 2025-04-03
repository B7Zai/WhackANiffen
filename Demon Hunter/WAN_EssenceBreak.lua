local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nEssenceBreak, nEssenceBreakMaxRange = 0, 12

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.EssenceBreak.id)
        or not wan.IsSpellUsable(wan.spellData.BladeDance.id)
    then
        
        wan.UpdateAbilityData(wan.spellData.EssenceBreak.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nEssenceBreakMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.EssenceBreak.basename)
        return
    end

    -- Base value
    local cEssenceBreak = nEssenceBreak
    local cdPotency = wan.CheckOffensiveCooldownPotency(cEssenceBreak, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cEssenceBreak) or 0
    wan.UpdateAbilityData(wan.spellData.EssenceBreak.basename, abilityValue, wan.spellData.EssenceBreak.icon, wan.spellData.EssenceBreak.name)
end

-- Init frame 
local frameEssenceBreak = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nEssenceBreak = wan.OffensiveCooldownToValue(wan.spellData.EssenceBreak.id)
        end
    end)
end
frameEssenceBreak:RegisterEvent("ADDON_LOADED")
frameEssenceBreak:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.EssenceBreak.known and wan.spellData.EssenceBreak.id
        wan.BlizzardEventHandler(frameEssenceBreak, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameEssenceBreak, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameEssenceBreak, CheckAbilityValue, abilityActive)
    end
end)