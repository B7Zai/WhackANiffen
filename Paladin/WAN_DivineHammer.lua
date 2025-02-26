local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local abilityActive = false
local nDivineHammer, nDivineHammerMaxRange = 0, 0

-- Trait data


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.IsSpellUsable(wan.spellData.WakeofAshes.id)
        or not wan.IsSpellUsable(wan.spellData.DivineHammer.id)
    then
        wan.UpdateAbilityData(wan.spellData.DivineHammer.basename)
        return
    end

    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nDivineHammerMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.DivineHammer.basename)
        return
    end

    local cDivineHammer = nDivineHammer
    local cdPotency = wan.CheckOffensiveCooldownPotency(cDivineHammer, isValidUnit, idValidUnit)

    local abilityValue = cdPotency and math.floor(cDivineHammer) or 0
    wan.UpdateAbilityData(wan.spellData.DivineHammer.basename, abilityValue, wan.spellData.DivineHammer.icon, wan.spellData.DivineHammer.name)
end

-- Init frame 
local frameDivineHammer = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nDivineHammer = wan.OffensiveCooldownToValue(wan.spellData.DivineHammer.id)

            nDivineHammerMaxRange = wan.GetSpellDescriptionNumbers(wan.spellData.DivineHammer.id, { 1 })
        end
    end)
end
frameDivineHammer:RegisterEvent("ADDON_LOADED")
frameDivineHammer:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.DivineHammer.known and wan.spellData.DivineHammer.id
        wan.SetUpdateRate(frameDivineHammer, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameDivineHammer, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDivineHammer, CheckAbilityValue, abilityActive)
    end
end)
