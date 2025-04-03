local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nTheHunt, nTheHuntMaxRange = 0, 10

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or not wan.IsSpellUsable(wan.spellData.TheHunt.id)
    then
        wan.UpdateAbilityData(wan.spellData.TheHunt.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.TheHunt.id)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.TheHunt.basename)
        return
    end

    -- Base value
    local cTheHunt = nTheHunt
    local cdPotency = wan.CheckOffensiveCooldownPotency(cTheHunt, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cTheHunt) or 0
    wan.UpdateAbilityData(wan.spellData.TheHunt.basename, abilityValue, wan.spellData.TheHunt.icon, wan.spellData.TheHunt.name)
end

-- Init frame 
local frameTheHunt = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nTheHunt = wan.OffensiveCooldownToValue(wan.spellData.TheHunt.id)
        end
    end)
end
frameTheHunt:RegisterEvent("ADDON_LOADED")
frameTheHunt:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.TheHunt.known and wan.spellData.TheHunt.id
        wan.BlizzardEventHandler(frameTheHunt, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameTheHunt, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameTheHunt, CheckAbilityValue, abilityActive)
    end
end)