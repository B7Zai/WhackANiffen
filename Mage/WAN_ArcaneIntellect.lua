local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nArcaneIntellect = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.ArcaneIntellect.id)
        or not wan.CheckClassBuff(wan.spellData.ArcaneIntellect.basename)
    then
        wan.UpdateMechanicData(wan.spellData.ArcaneIntellect.basename)
        return
    end

    -- Base value
    local cArcaneIntellect = nArcaneIntellect

    -- Update ability data
    local abilityValue = cArcaneIntellect
    wan.UpdateMechanicData(wan.spellData.ArcaneIntellect.basename, abilityValue, wan.spellData.ArcaneIntellect.icon, wan.spellData.ArcaneIntellect.name)
end

-- Init frame 
local frameArcaneIntellect = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nArcaneIntellectValue = wan.GetSpellDescriptionNumbers(wan.spellData.ArcaneIntellect.id, { 1 })
            nArcaneIntellect = wan.AbilityPercentageToValue(nArcaneIntellectValue)
        end
    end)
end
frameArcaneIntellect:RegisterEvent("ADDON_LOADED")
frameArcaneIntellect:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ArcaneIntellect.known and wan.spellData.ArcaneIntellect.id
        wan.BlizzardEventHandler(frameArcaneIntellect, abilityActive, "UNIT_AURA", "SPELLS_CHANGED", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameArcaneIntellect, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArcaneIntellect, CheckAbilityValue, abilityActive)
    end
end)
