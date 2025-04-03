local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nMetamorphosisOffensive, nMetamorphosisDefensive, nMetamorphosisMaxRange = 0, 0, 20
local isTank = false

local bChaoticTransformation = false

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or (not wan.PlayerState.InRaid and wan.CheckUnitBuff(nil, wan.spellData.Darkness.formattedName))
        or wan.CheckUnitBuff(nil, wan.spellData.Metamorphosis.formattedName)
        or not wan.IsSpellUsable(wan.spellData.Metamorphosis.id)
    then
        wan.UpdateAbilityData(wan.spellData.Metamorphosis.basename)
        wan.UpdateMechanicData(wan.spellData.Metamorphosis.basename)
        return
    end

    if bChaoticTransformation then
        local isUsableBladeDance, insufficientPowerBladeDance = wan.IsSpellUsable(wan.spellData.BladeDance.id)
        local isUsableEyeBeam, insufficientPowerEyeBeam = wan.IsSpellUsable(wan.spellData.EyeBeam.id)

        if isUsableBladeDance or insufficientPowerBladeDance or isUsableEyeBeam or insufficientPowerEyeBeam then
            wan.UpdateAbilityData(wan.spellData.Metamorphosis.basename)
            return
        end
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nMetamorphosisMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.Metamorphosis.basename)
        return
    end

    -- Base value
    local cMetamorphosisOffensive = nMetamorphosisOffensive
    local cdPotency = wan.CheckOffensiveCooldownPotency(cMetamorphosisOffensive, isValidUnit, idValidUnit)

    local cMetamorphosisDefensive = nMetamorphosisDefensive
    local currentPercentHealth = wan.CheckUnitPercentHealth(playerGUID)
    local isTanking = wan.IsTanking()

    -- Update ability data
    local abilityValue = not isTank and cdPotency and math.floor(cMetamorphosisOffensive) or 0
    local defensiveValue = isTank and isTanking and wan.UnitAbilityHealValue(playerUnitToken, cMetamorphosisDefensive, currentPercentHealth) or 0
    wan.UpdateAbilityData(wan.spellData.Metamorphosis.basename, abilityValue, wan.spellData.Metamorphosis.icon, wan.spellData.Metamorphosis.name)
    wan.UpdateMechanicData(wan.spellData.Metamorphosis.basename, defensiveValue, wan.spellData.Metamorphosis.icon, wan.spellData.Metamorphosis.name)
end

-- Init frame 
local frameMetamorphosis = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nMetamorphosisOffensive = wan.OffensiveCooldownToValue(wan.spellData.Metamorphosis.id)
            nMetamorphosisDefensive = wan.DefensiveCooldownToValue(wan.spellData.Metamorphosis.id)

            nMetamorphosisMaxRange = isTank and 20 or wan.spellData.Metamorphosis.maxRange
        end
    end)
end
frameMetamorphosis:RegisterEvent("ADDON_LOADED")
frameMetamorphosis:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Metamorphosis.known and wan.spellData.Metamorphosis.id
        wan.BlizzardEventHandler(frameMetamorphosis, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameMetamorphosis, CheckAbilityValue, abilityActive)

        isTank = wan.spellData.MasteryFelBlood.known
    end

    if event == "TRAIT_DATA_READY" then
        bChaoticTransformation = wan.traitData.ChaoticTransformation.known
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMetamorphosis, CheckAbilityValue, abilityActive)
    end
end)