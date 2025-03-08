local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nRavager = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.Ravager.id)
        or wan.CheckUnitBuff(nil, wan.spellData.Ravager.formattedName)
    then
        wan.UpdateAbilityData(wan.spellData.Ravager.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Ravager.maxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.Ravager.basename)
        return
    end

    -- Base value
    local cRavager = nRavager
    local cdPotency = wan.CheckOffensiveCooldownPotency(cRavager, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cRavager) or 0
    wan.UpdateAbilityData(wan.spellData.Ravager.basename, abilityValue, wan.spellData.Ravager.icon, wan.spellData.Ravager.name)
end

-- Init frame 
local frameRavager = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nRavager = wan.OffensiveCooldownToValue(wan.spellData.Ravager.id)
        end
    end)
end
frameRavager:RegisterEvent("ADDON_LOADED")
frameRavager:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Ravager.known and wan.spellData.Ravager.id
        wan.BlizzardEventHandler(frameRavager, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameRavager, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRavager, CheckAbilityValue, abilityActive)
    end
end)