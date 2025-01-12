local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init data
local abilityActive = false
local nSpearhead = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Spearhead.id)
    then
        wan.UpdateAbilityData(wan.spellData.Spearhead.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Spearhead.id)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.Spearhead.basename)
        return
    end

    -- Base value
    local cSpearhead = nSpearhead
    local cdPotency = wan.CheckOffensiveCooldownPotency(cSpearhead, isValidUnit, idValidUnit)


    -- Update ability data
    local abilityValue = cdPotency and math.floor(cSpearhead) or 0
    wan.UpdateAbilityData(wan.spellData.Spearhead.basename, abilityValue, wan.spellData.Spearhead.icon, wan.spellData.Spearhead.name)
end

-- Init frame 
local frameSpearhead = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nSpearhead = wan.OffensiveCooldownToValue(wan.spellData.Spearhead.id)
        end
    end)
end
frameSpearhead:RegisterEvent("ADDON_LOADED")
frameSpearhead:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Spearhead.known and wan.spellData.Spearhead.id
        wan.SetUpdateRate(frameSpearhead, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameSpearhead, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSpearhead, CheckAbilityValue, abilityActive)
    end
end)
