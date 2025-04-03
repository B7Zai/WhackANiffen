local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nSigilofSpite, nSigilofSpiteMaxRange = 0, 10

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.SigilofSpite.id)
    then
        wan.UpdateAbilityData(wan.spellData.SigilofSpite.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.SigilofSpite.maxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.SigilofSpite.basename)
        return
    end

    -- Base value
    local cSigilofSpite = nSigilofSpite
    local cdPotency = wan.CheckOffensiveCooldownPotency(cSigilofSpite, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cSigilofSpite) or 0
    wan.UpdateAbilityData(wan.spellData.SigilofSpite.basename, abilityValue, wan.spellData.SigilofSpite.icon, wan.spellData.SigilofSpite.name)
end

-- Init frame 
local frameSigilofSpite = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nSigilofSpite = wan.OffensiveCooldownToValue(wan.spellData.SigilofSpite.id)
        end
    end)
end
frameSigilofSpite:RegisterEvent("ADDON_LOADED")
frameSigilofSpite:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.SigilofSpite.known and wan.spellData.SigilofSpite.id
        wan.BlizzardEventHandler(frameSigilofSpite, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSigilofSpite, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSigilofSpite, CheckAbilityValue, abilityActive)
    end
end)