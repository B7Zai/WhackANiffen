local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nThunderousRoar, nThunderousRoarMaxRange = 0, 12

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ThunderousRoar.id) then
        wan.UpdateAbilityData(wan.spellData.ThunderousRoar.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nThunderousRoarMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.ThunderousRoar.basename)
        return
    end

    -- Base value
    local cThunderousRoar = nThunderousRoar
    local cdPotency = wan.CheckOffensiveCooldownPotency(cThunderousRoar, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cThunderousRoar) or 0
    wan.UpdateAbilityData(wan.spellData.ThunderousRoar.basename, abilityValue, wan.spellData.ThunderousRoar.icon, wan.spellData.ThunderousRoar.name)
end

-- Init frame 
local frameThunderousRoar = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nThunderousRoar = wan.OffensiveCooldownToValue(wan.spellData.ThunderousRoar.id)
        end
    end)
end
frameThunderousRoar:RegisterEvent("ADDON_LOADED")
frameThunderousRoar:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ThunderousRoar.known and wan.spellData.ThunderousRoar.id
        wan.BlizzardEventHandler(frameThunderousRoar, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameThunderousRoar, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameThunderousRoar, CheckAbilityValue, abilityActive)
    end
end)