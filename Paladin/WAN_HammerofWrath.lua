local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init spell data
local abilityActive = false
local nHammerofWrathDmg, nHammerofWrathDotDmg = 0, 0

-- Init trait data
local nVengefulWrath, nVengefulWrathThreshold = 0, 0
local nBoundlessJudgment = 0
local nHighlordsWrath = 0
local nLuminosity = 0
local nSunSearDotDmg, nSunSearProcChance = 0, 0
local nSecondSunriseProcChance, nSecondSunrise = 0, 0
local nMasteryHighlordsJudgmentProcChance, nMasteryHighlordsJudgmentDmg = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.HammerofWrath.id)
    then
        wan.UpdateAbilityData(wan.spellData.HammerofWrath.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.HammerofWrath.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.HammerofWrath.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cHammerofWrathInstantDmg = nHammerofWrathDmg
    local cHammerofWrathDotDmg = 0
    local cHammerofWrathInstantDmgAoE = 0
    local cHammerofWrathDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    local cVengefulWrath = 1
    if wan.traitData.VengefulWrath.known then
        local unitHealthPercentage = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1
        if unitHealthPercentage < nVengefulWrathThreshold then
            cVengefulWrath = cVengefulWrath + nVengefulWrath
        end
    end

    ---- RETRIBUTION TRAITS ----

    local cHighlordsJudgmentInstantDmg = 0
    if wan.spellData.MasteryHighlordsJudgment.known then
        cHighlordsJudgmentInstantDmg = cHighlordsJudgmentInstantDmg + (nMasteryHighlordsJudgmentDmg * (nMasteryHighlordsJudgmentProcChance * nBoundlessJudgment * nHighlordsWrath))
    end

    ---- HERALD OF THE SUN TRAITS ----

    if wan.traitData.Luminosity.known then
        critChanceMod = critChanceMod + nLuminosity
    end

    local cSunSearDotDmg = 0
    if wan.traitData.SunSear.known then
        cSunSearDotDmg = cSunSearDotDmg + (nSunSearDotDmg * nSunSearProcChance)
    end

    local cSecondSunriseInstantDmg = 0
    if wan.traitData.SecondSunrise.known then
        cSecondSunriseInstantDmg = cSecondSunriseInstantDmg + (nHammerofWrathDmg * nSecondSunriseProcChance * nSecondSunrise)  
    end
    
    local cHammerofWrathCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cHammerofWrathBaseCritValue = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cHammerofWrathInstantDmg = (cHammerofWrathInstantDmg * cVengefulWrath * cHammerofWrathCritValue)
        + (cSecondSunriseInstantDmg * cHammerofWrathCritValue)
        + (cHighlordsJudgmentInstantDmg * cHammerofWrathBaseCritValue)

    cHammerofWrathDotDmg = cHammerofWrathDotDmg + (cSunSearDotDmg * cHammerofWrathBaseCritValue)
    cHammerofWrathInstantDmgAoE = cHammerofWrathInstantDmgAoE
    cHammerofWrathDotDmgAoE = cHammerofWrathDotDmgAoE

    local cHammerofWrathDmg = cHammerofWrathInstantDmg + cHammerofWrathDotDmg + cHammerofWrathInstantDmgAoE + cHammerofWrathDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cHammerofWrathDmg)
    wan.UpdateAbilityData(wan.spellData.HammerofWrath.basename, abilityValue, wan.spellData.HammerofWrath.icon, wan.spellData.HammerofWrath.name)
end

-- Init frame 
local frameHammerofWrath = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nHammerofWrathValues = wan.GetSpellDescriptionNumbers(wan.spellData.HammerofWrath.id, { 1, 2 })
            nHammerofWrathDmg = nHammerofWrathValues[1]

            local nMasteryHighlordsJudgmentValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHighlordsJudgment.id, { 2, 3 })
            nMasteryHighlordsJudgmentProcChance = nMasteryHighlordsJudgmentValues[1] * 0.01
            nMasteryHighlordsJudgmentDmg = nMasteryHighlordsJudgmentValues[2]

            nSunSearDotDmg = wan.GetTraitDescriptionNumbers(wan.traitData.SunSear.entryid, { 1 })
            nSunSearProcChance = wan.CritChance * 0.01
        end
    end)
end
frameHammerofWrath:RegisterEvent("ADDON_LOADED")
frameHammerofWrath:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.HammerofWrath.known and wan.spellData.HammerofWrath.id
        wan.BlizzardEventHandler(frameHammerofWrath, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameHammerofWrath, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        local nVengefulWrathValues = wan.GetTraitDescriptionNumbers(wan.traitData.VengefulWrath.entryid, { 1, 2 }, wan.traitData.VengefulWrath.rank)
        nVengefulWrath = nVengefulWrathValues[1] * 0.01
        nVengefulWrathThreshold = nVengefulWrathValues[2] * 0.01

        nLuminosity = wan.GetTraitDescriptionNumbers(wan.traitData.Luminosity.entryid, { 1 })

        local nSecondSunriseValues = wan.GetTraitDescriptionNumbers(wan.traitData.SecondSunrise.entryid, { 1, 2 })
        nSecondSunriseProcChance = nSecondSunriseValues[1] * 0.01
        nSecondSunrise = nSecondSunriseValues[2] * 0.01

        nBoundlessJudgment = 1 + wan.GetTraitDescriptionNumbers(wan.traitData.BoundlessJudgment.entryid, { 1 }) * 0.01

        nHighlordsWrath = 1 + wan.GetTraitDescriptionNumbers(wan.traitData.HighlordsWrath.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameHammerofWrath, CheckAbilityValue, abilityActive)
    end
end)