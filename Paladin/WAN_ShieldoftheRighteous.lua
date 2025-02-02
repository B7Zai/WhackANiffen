local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init spell data
local abilityActive = false
local nShieldoftheRighteousDmg, nShieldoftheRighteousMaxRange = 0, 11

-- Init trait data
local nGreaterJudgment = 0
local nShiningRighteousnessDmg = 0
local checkHammerofLight = false
local nEmpyreanHammer = 0
local nWrathfulDescent = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or checkHammerofLight
        or not wan.IsSpellUsable(wan.spellData.ShieldoftheRighteous.id)
    then
        wan.UpdateAbilityData(wan.spellData.ShieldoftheRighteous.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nShieldoftheRighteousMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ShieldoftheRighteous.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cShieldoftheRighteousInstantDmg = 0
    local cShieldoftheRighteousDotDmg = 0
    local cShieldoftheRighteousInstantDmgAoE = 0
    local cShieldoftheRighteousDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    local cGreaterJudgmentAoE = 1
    if wan.traitData.GreaterJudgment.known then
        local formattedDebuffName = wan.spellData.Judgment.basename
        local countGreaterJudgmentDebuff = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitGreaterJudgmentDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)
            if checkUnitGreaterJudgmentDebuff then
                countGreaterJudgmentDebuff = countGreaterJudgmentDebuff + 1
            end
        end

        if countGreaterJudgmentDebuff > 0 then
            cGreaterJudgmentAoE = cGreaterJudgmentAoE + (nGreaterJudgment * (countGreaterJudgmentDebuff / countValidUnit))
        end
    end

    ---- HOLY TRAITS ----

    local cShiningRighteousnessInstantDmg = 0
    if wan.traitData.ShiningRighteousness.known then
        cShiningRighteousnessInstantDmg = cShiningRighteousnessInstantDmg + nShiningRighteousnessDmg
    end

    --- TEMPLAR TRAITS ----

    local cEmpyreanHammerInstantDmg = 0
    if wan.traitData.LightsGuidance.known then

        local cWrathfulDescent = 1
        if wan.traitData.WrathfulDescent.known then
            local nWrathfulDescentUnits = math.max(countValidUnit - 1, 0)
            local nWrathfulDescentProcChance = wan.CritChance * 0.01
            cWrathfulDescent = cWrathfulDescent + (nWrathfulDescent * nWrathfulDescentUnits * nWrathfulDescentProcChance)
        end

        cEmpyreanHammerInstantDmg = cEmpyreanHammerInstantDmg + (nEmpyreanHammer * cWrathfulDescent)

        if wan.traitData.Hammerfall.known then
            local formattedBuffName = wan.traitData.ShaketheHeavens.traitkey
            local checkShaketheHeavensBuff = wan.CheckUnitBuff(nil, formattedBuffName)

            if checkShaketheHeavensBuff then
                cEmpyreanHammerInstantDmg = cEmpyreanHammerInstantDmg + (nEmpyreanHammer * cWrathfulDescent)
            end
        end
    end

    local cShieldoftheRighteousCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cShieldoftheRighteousCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cShieldoftheRighteousInstantDmg = cShieldoftheRighteousInstantDmg
        + (cShiningRighteousnessInstantDmg * cShieldoftheRighteousCritValueBase)
        + (cEmpyreanHammerInstantDmg * cShieldoftheRighteousCritValueBase)

    cShieldoftheRighteousDotDmg = cShieldoftheRighteousDotDmg

    cShieldoftheRighteousInstantDmgAoE = cShieldoftheRighteousInstantDmgAoE
        + (nShieldoftheRighteousDmg * countValidUnit * cShieldoftheRighteousCritValue)
        + (nShieldoftheRighteousDmg * cGreaterJudgmentAoE * cShieldoftheRighteousCritValue)

    cShieldoftheRighteousDotDmgAoE = cShieldoftheRighteousDotDmgAoE


    local cShieldoftheRighteousDmg = cShieldoftheRighteousInstantDmg + cShieldoftheRighteousDotDmg + cShieldoftheRighteousInstantDmgAoE + cShieldoftheRighteousDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cShieldoftheRighteousDmg)
    wan.UpdateAbilityData(wan.spellData.ShieldoftheRighteous.basename, abilityValue, wan.spellData.ShieldoftheRighteous.icon, wan.spellData.ShieldoftheRighteous.name)
end

-- Init frame 
local frameShieldoftheRighteous = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nShieldoftheRighteousValues = wan.GetSpellDescriptionNumbers(wan.spellData.ShieldoftheRighteous.id, { 1, 2 })
            nShieldoftheRighteousDmg = nShieldoftheRighteousValues[1]

            nShiningRighteousnessDmg = wan.GetTraitDescriptionNumbers(wan.traitData.ShiningRighteousness.entryid, { 1 })

            checkHammerofLight = wan.spellData.WakeofAshes.name == "Hammer of Light"

            nEmpyreanHammer = wan.GetTraitDescriptionNumbers(wan.traitData.LightsGuidance.entryid, { 8 })
        end
    end)
end
frameShieldoftheRighteous:RegisterEvent("ADDON_LOADED")
frameShieldoftheRighteous:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ShieldoftheRighteous.known and wan.spellData.ShieldoftheRighteous.id
        wan.BlizzardEventHandler(frameShieldoftheRighteous, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameShieldoftheRighteous, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nGreaterJudgment = wan.GetTraitDescriptionNumbers(wan.traitData.GreaterJudgment.entryid, { 1 }) * 0.01

        nWrathfulDescent = wan.GetTraitDescriptionNumbers(wan.traitData.WrathfulDescent.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameShieldoftheRighteous, CheckAbilityValue, abilityActive)
    end
end)