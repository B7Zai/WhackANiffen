local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nColossusSmash, nColossusSmashMaxRange = 0, 10

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ColossusSmash.id) then
        wan.UpdateAbilityData(wan.spellData.ColossusSmash.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nColossusSmashMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.ColossusSmash.basename)
        return
    end

    -- Base value
    local cColossusSmash = nColossusSmash
    local cdPotency = wan.CheckOffensiveCooldownPotency(cColossusSmash, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cColossusSmash) or 0
    wan.UpdateAbilityData(wan.spellData.ColossusSmash.basename, abilityValue, wan.spellData.ColossusSmash.icon, wan.spellData.ColossusSmash.name)
end

-- Init frame 
local frameColossusSmash = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nColossusSmash = wan.OffensiveCooldownToValue(wan.spellData.ColossusSmash.id)
        end
    end)
end
frameColossusSmash:RegisterEvent("ADDON_LOADED")
frameColossusSmash:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ColossusSmash.known and wan.spellData.ColossusSmash.id
        wan.BlizzardEventHandler(frameColossusSmash, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameColossusSmash, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameColossusSmash, CheckAbilityValue, abilityActive)
    end
end)