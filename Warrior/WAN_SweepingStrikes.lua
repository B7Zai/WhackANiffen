local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nSweepingStrikesUnitCap, nSweepingStrikesMaxRange, nSweepingStrikes = 0, 15, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.SweepingStrikes.id) then
        wan.UpdateAbilityData(wan.spellData.SweepingStrikes.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nSweepingStrikesMaxRange)
    if countValidUnit < 2 then
        wan.UpdateAbilityData(wan.spellData.SweepingStrikes.basename)
        return
    end

    -- Base value
    local cSweepingStrikes = nSweepingStrikes
    local cdPotency = wan.CheckOffensiveCooldownPotency(cSweepingStrikes, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cSweepingStrikes) or 0
    wan.UpdateAbilityData(wan.spellData.SweepingStrikes.basename, abilityValue, wan.spellData.SweepingStrikes.icon, wan.spellData.SweepingStrikes.name)
end

-- Init frame 
local frameSweepingStrikes = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nSweepingStrikes = wan.OffensiveCooldownToValue(wan.spellData.SweepingStrikes.id)
        end
    end)
end
frameSweepingStrikes:RegisterEvent("ADDON_LOADED")
frameSweepingStrikes:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.SweepingStrikes.known and wan.spellData.SweepingStrikes.id
        wan.BlizzardEventHandler(frameSweepingStrikes, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSweepingStrikes, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSweepingStrikes, CheckAbilityValue, abilityActive)
    end
end)