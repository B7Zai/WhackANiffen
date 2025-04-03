local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nFelBarrage, nFelBarrageMaxRange = 0, 11
local currentPower, currentPowerPercentage = 0, 0
local checkMaxPower = 0
local sImmolationAuraBuff = "ImmolationAura"
local sTacticalRetreatBuff = "TacticalRetreat"

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or currentPowerPercentage < 0.7
        or (not wan.CheckUnitBuff(nil, sImmolationAuraBuff) and not wan.CheckUnitBuff(nil, sTacticalRetreatBuff))
        or not wan.IsSpellUsable(wan.spellData.FelBarrage.id)
    then
        wan.UpdateAbilityData(wan.spellData.FelBarrage.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nFelBarrageMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.FelBarrage.basename)
        return
    end

    -- Base value
    local cFelBarrage = nFelBarrage
    local cdPotency = wan.CheckOffensiveCooldownPotency(cFelBarrage, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cFelBarrage) or 0
    wan.UpdateAbilityData(wan.spellData.FelBarrage.basename, abilityValue, wan.spellData.FelBarrage.icon, wan.spellData.FelBarrage.name)
end

-- Init frame 
local frameFelBarrage = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if event == "SPELLS_CHANGED" then
            checkMaxPower = wan.CheckUnitMaxPower("player", 17) or 0
            currentPower = wan.CheckUnitPower("player", 17) or 0
        end

        if event == "UNIT_POWER_UPDATE" then
            local unitID, powerType = ...
            if unitID == "player" and powerType == "FURY" then
                currentPower = wan.CheckUnitPower("player", 17) or 0
                currentPowerPercentage = currentPower / checkMaxPower
            end
        end

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nFelBarrage = wan.OffensiveCooldownToValue(wan.spellData.FelBarrage.id)

            sImmolationAuraBuff = wan.spellData.ImmolationAura.formattedName
        end
    end)
end
frameFelBarrage:RegisterEvent("ADDON_LOADED")
frameFelBarrage:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FelBarrage.known and wan.spellData.FelBarrage.id
        wan.BlizzardEventHandler(frameFelBarrage, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED","UNIT_POWER_UPDATE")
        wan.SetUpdateRate(frameFelBarrage, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        sTacticalRetreatBuff = wan.traitData.TacticalRetreat.traitkey
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFelBarrage, CheckAbilityValue, abilityActive)
    end
end)