local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nFuryOfTheEagleDmg, nFuryOfTheEagleCrit, nFuryOfTheEagleCastTime, nFuryOfTheEagleThreshold, nFuryOfTheEagleSoftCap = 0, 0, 0, 0, 0
local nFuryOfTheEagleMaxRange = 10

-- Init trait data

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.FuryoftheEagle.id)
    then
        wan.UpdateAbilityData(wan.spellData.FuryoftheEagle.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(nil, nFuryOfTheEagleMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.FuryoftheEagle.basename)
        return
    end

    local canMoveCast = true
    local cFuryoftheEagleCastEfficiency = wan.CheckCastEfficiency(wan.spellData.FuryoftheEagle.id, nFuryOfTheEagleCastTime, canMoveCast)
    if cFuryoftheEagleCastEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.AimedShot.basename)
        return
    end

    local critChanceMod = 0
    local critDamageMod = 0

    local cFuryOfTheEagleInstantDmg = 0
    local cFuryOfTheEagleDotDmg = 0
    local cFuryOfTheEagleInstantDmgAoE = 0
    local cFuryOfTheEagleDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cFuryOfTheEagleInstantDmgBaseAoE = 0
    local countFuryoftheEagleBelowThresholdUnit = 0
    local cFuryOfTheEagleUnitOverflow = wan.SoftCapOverflow(nFuryOfTheEagleSoftCap, countValidUnit)
    for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

        local targetPercentHealth = nameplateGUID and UnitPercentHealthFromGUID(nameplateGUID) or 1
        if targetPercentHealth < nFuryOfTheEagleThreshold then
            countFuryoftheEagleBelowThresholdUnit = countFuryoftheEagleBelowThresholdUnit + 1
        end

        cFuryOfTheEagleInstantDmgBaseAoE =  cFuryOfTheEagleInstantDmgBaseAoE + (nFuryOfTheEagleDmg * checkPhysicalDR * cFuryOfTheEagleUnitOverflow)
    end

    if countFuryoftheEagleBelowThresholdUnit > 0 then
        critChanceMod = critChanceMod + ((nFuryOfTheEagleCrit * countFuryoftheEagleBelowThresholdUnit) / countValidUnit)
    end

    local cFuryOfTheEagleCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cFuryOfTheEagleInstantDmg = cFuryOfTheEagleInstantDmg

    cFuryOfTheEagleDotDmg = cFuryOfTheEagleDotDmg

    cFuryOfTheEagleInstantDmgAoE = cFuryOfTheEagleInstantDmgAoE
        + (cFuryOfTheEagleInstantDmgBaseAoE * cFuryOfTheEagleCritValue)

    cFuryOfTheEagleDotDmgAoE = cFuryOfTheEagleDotDmgAoE

    local cFuryOfTheEagleDmg = (cFuryOfTheEagleInstantDmg + cFuryOfTheEagleDotDmg + cFuryOfTheEagleInstantDmgAoE + cFuryOfTheEagleDotDmgAoE) * cFuryoftheEagleCastEfficiency

    local cdPotency = wan.CheckOffensiveCooldownPotency(cFuryOfTheEagleDmg, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cFuryOfTheEagleDmg) or 0
    wan.UpdateAbilityData(wan.spellData.FuryoftheEagle.basename, abilityValue, wan.spellData.FuryoftheEagle.icon, wan.spellData.FuryoftheEagle.name)
end

-- Init frame 
local frameFuryOfTheEagle = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nFuryOfTheEagleValues = wan.GetSpellDescriptionNumbers(wan.spellData.FuryoftheEagle.id, { 1, 2, 3, 4, 5 })
            nFuryOfTheEagleDmg = nFuryOfTheEagleValues[1]
            nFuryOfTheEagleCastTime = nFuryOfTheEagleValues[2] * 1000
            nFuryOfTheEagleCrit = nFuryOfTheEagleValues[3]
            nFuryOfTheEagleThreshold = nFuryOfTheEagleValues[4] * 0.01
            nFuryOfTheEagleSoftCap = nFuryOfTheEagleValues[5]
        end
    end)
end
frameFuryOfTheEagle:RegisterEvent("ADDON_LOADED")
frameFuryOfTheEagle:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FuryoftheEagle.known and wan.spellData.FuryoftheEagle.id
        wan.BlizzardEventHandler(frameFuryOfTheEagle, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFuryOfTheEagle, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFuryOfTheEagle, CheckAbilityValue, abilityActive)
    end
end)