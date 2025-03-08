local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nBloodthirstDmg = 0

-- Init trait data
local nCrushingForce = 0
local nOverwhelmingBlades = 0
local nColdSteelHotBloodDmg, nColdSteelHotBloodProcChance = 0, 0
local nViciousContempt, nViciousContemptThreshold = 0, 0
local nImprovedWhirlwindUnitCap, nImprovedWhirlwind, nWhirlwindMaxRange = 0, 0, 0
local nBloodcrazeCritChance = 0
local nRecklessnessCritChance = 0
local nRecklessAbandonDotDmg = 0
local nReaptheStormProcChance, nReaptheStormDmg, nReaptheStormSoftCap = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Bloodthirst.id) then
        wan.UpdateAbilityData(wan.spellData.Bloodthirst.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Bloodthirst.id, nWhirlwindMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Bloodthirst.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cBloodthirstInstantDmg = 0
    local cBloodthirstDotDmg = 0
    local cBloodthirstInstantDmgAoE = 0
    local cBloodthirstDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- WARRIOR TRAITS ----

    if wan.traitData.CrushingForce.known then
        critDamageMod = critDamageMod + nCrushingForce
    end

    if wan.traitData.BerserkersTorment.known or wan.traitData.WarlordsTorment.known or wan.traitData.Recklessness.known then
        local checkRecklessnessBuff = wan.CheckUnitBuff(nil, wan.spellData.Recklessness.formattedName)
        if checkRecklessnessBuff then
            critChanceMod = critChanceMod + nRecklessnessCritChance
        end
    end

    ---- FURY TRAITS ----

    local cImprovedWhirlwindInstantDmgAoE = 0
    local checkImprovedWhirlwindBuff = nil
    local countImprovedWhirlwindUnit = 0
    if wan.traitData.ImprovedWhirlwind.known then
        checkImprovedWhirlwindBuff = wan.CheckUnitBuff(nil, "Whirlwind")

        if checkImprovedWhirlwindBuff then
            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    cImprovedWhirlwindInstantDmgAoE = cImprovedWhirlwindInstantDmgAoE + (nBloodthirstDmg * nImprovedWhirlwind * checkUnitPhysicalDR)

                    countImprovedWhirlwindUnit = countImprovedWhirlwindUnit + 1

                    if countImprovedWhirlwindUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    local cColdSteelHotBloodDotDmg = 0
    local cColdSteelHotBloodDotDmgAoE = 0
    if wan.traitData.ColdSteelHotBlood.entryid then
        local checkGushingWoundDebuff = wan.CheckUnitDebuff(nil, "GushingWound")
        if not checkGushingWoundDebuff then
            local checkDotPotency = wan.CheckDotPotency(nBloodthirstDmg)

            cColdSteelHotBloodDotDmg = cColdSteelHotBloodDotDmg + (nColdSteelHotBloodDmg * nColdSteelHotBloodProcChance * checkDotPotency)
        end

        if checkImprovedWhirlwindBuff then
            local countColdSteelHotBloodUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitGushingWoundDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "GushingWound")

                    if not checkUnitGushingWoundDebuff then
                        local checkUnitDotPotency = wan.CheckDotPotency(nBloodthirstDmg)
                        cColdSteelHotBloodDotDmgAoE = cColdSteelHotBloodDotDmgAoE + (nColdSteelHotBloodDmg * nColdSteelHotBloodProcChance * checkUnitDotPotency)
                    end

                    countColdSteelHotBloodUnit = countColdSteelHotBloodUnit + 1

                    if countColdSteelHotBloodUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    local cViciousContempt = 1
    local cViciousContemptAoE = 1
    if wan.traitData.ViciousContempt.known then
        local checkHealthPercentage = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1

        if checkHealthPercentage < nViciousContemptThreshold then
            cViciousContempt = cViciousContempt + nViciousContempt
        end

        if checkImprovedWhirlwindBuff then
            local countViciousContemptUnit = 0

            for _, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitHealthPercentage = nameplateGUID and UnitPercentHealthFromGUID(nameplateGUID) or 1

                    if checkUnitHealthPercentage < nViciousContemptThreshold then
                        cViciousContemptAoE = cViciousContemptAoE + (nViciousContempt / countImprovedWhirlwindUnit)
                    end

                    countViciousContemptUnit = countViciousContemptUnit + 1

                    if countViciousContemptUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    if wan.traitData.Bloodcraze.known then
        local checkBloodcrazeBuff = wan.CheckUnitBuff(nil, wan.traitData.Bloodcraze.traitkey)
        if checkBloodcrazeBuff then
            local cBloodcrazeStacks = checkBloodcrazeBuff.applications
            critChanceMod = critChanceMod + (nBloodcrazeCritChance * cBloodcrazeStacks)
        end
    end

    local cRecklessAbandonDotDmg = 0
    local cRecklessAbandonDotDmgAoE = 0
    if wan.traitData.RecklessAbandon.known and wan.spellData.Bloodthirst.name == "Bloodbath" then
        local checkDotPotency = wan.CheckDotPotency(nBloodthirstDmg)
        cRecklessAbandonDotDmg = cRecklessAbandonDotDmg + (nRecklessAbandonDotDmg * checkDotPotency)

        if checkImprovedWhirlwindBuff then
            local countRecklessAbandonUnit = 0

            for _, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitDotPotency = wan.CheckDotPotency(nBloodthirstDmg)
                    cRecklessAbandonDotDmgAoE = cRecklessAbandonDotDmgAoE + (nRecklessAbandonDotDmg * checkUnitDotPotency)

                    countRecklessAbandonUnit = countRecklessAbandonUnit + 1

                    if countRecklessAbandonUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    ---- SLAYER TRAITS ----

    local cOverwhelmingBlades = 1
    local cOverwhelmingBladesAoE = 1
    if wan.traitData.OverwhelmingBlades.known or wan.traitData.UnrelentingOnslaught.known then
        local checkOverwhelmingBladesDebuff = wan.CheckUnitDebuff(nil, "Overwhelmed")

        if checkOverwhelmingBladesDebuff then
            local cOverwhelmingBladesStacks = checkOverwhelmingBladesDebuff.applications
            cOverwhelmingBlades = cOverwhelmingBlades + (nOverwhelmingBlades * cOverwhelmingBladesStacks)
        end

        if checkImprovedWhirlwindBuff then
            local countOverwhelmingBladesUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitOverwhelmingBladesDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "Overwhelmed")

                    if checkUnitOverwhelmingBladesDebuff then
                        local cUnitOverwhelmingBladesStacks = checkUnitOverwhelmingBladesDebuff.applications
                        cOverwhelmingBladesAoE = cOverwhelmingBladesAoE + ((nOverwhelmingBlades * cUnitOverwhelmingBladesStacks) / countImprovedWhirlwindUnit)
                    end

                    countOverwhelmingBladesUnit = countOverwhelmingBladesUnit + 1

                    if countOverwhelmingBladesUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    local cReaptheStormInstantDmgAoE = 0
    if wan.traitData.ReaptheStorm.known then
        local cReaptheStormUnitOverflow = wan.SoftCapOverflow(nReaptheStormSoftCap, countValidUnit)
        local cProcChanceUnitOverflow = wan.AdjustSoftCapUnitOverflow(2, countValidUnit)
        local cReaptheStormProcChance = nReaptheStormProcChance * cProcChanceUnitOverflow

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

            cReaptheStormInstantDmgAoE = cReaptheStormInstantDmgAoE + (nReaptheStormDmg * cReaptheStormProcChance * cReaptheStormUnitOverflow * checkUnitPhysicalDR)
        end
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cBloodthirstCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cBloodthirstCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cBloodthirstInstantDmg = cBloodthirstInstantDmg
        + (nBloodthirstDmg * checkPhysicalDR * cBloodthirstCritValue * cOverwhelmingBlades * cViciousContempt)

    cBloodthirstDotDmg = cBloodthirstDotDmg
        + (cColdSteelHotBloodDotDmg * cBloodthirstCritValue * cOverwhelmingBlades)
        + (cRecklessAbandonDotDmg * cBloodthirstCritValueBase * cOverwhelmingBlades)
        + (cReaptheStormInstantDmgAoE * cBloodthirstCritValueBase * cOverwhelmingBlades)

    cBloodthirstInstantDmgAoE = cBloodthirstInstantDmgAoE
        + (cImprovedWhirlwindInstantDmgAoE * cBloodthirstCritValue * cOverwhelmingBladesAoE * cViciousContemptAoE)

    cBloodthirstDotDmgAoE = cBloodthirstDotDmgAoE
        + (cColdSteelHotBloodDotDmgAoE * cBloodthirstCritValue * cOverwhelmingBladesAoE)
        + (cRecklessAbandonDotDmgAoE * cBloodthirstCritValueBase * cOverwhelmingBladesAoE)

    local cBloodthirstDmg = cBloodthirstInstantDmg + cBloodthirstDotDmg + cBloodthirstInstantDmgAoE + cBloodthirstDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cBloodthirstDmg)
    wan.UpdateAbilityData(wan.spellData.Bloodthirst.basename, abilityValue, wan.spellData.Bloodthirst.icon, wan.spellData.Bloodthirst.name)
end

-- Init frame 
local frameBloodthirst = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBloodthirstDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Bloodthirst.id, { 1 })

            nColdSteelHotBloodDmg = wan.GetTraitDescriptionNumbers(wan.traitData.ColdSteelHotBlood.entryid, { 2 })
            nColdSteelHotBloodProcChance = wan.CritChance * 0.01

            local nReaptheStormValues = wan.GetTraitDescriptionNumbers(wan.traitData.ReaptheStorm.entryid, { 1, 2, 3 })
            nReaptheStormProcChance = nReaptheStormValues[1] * 0.01
            nReaptheStormDmg = nReaptheStormValues[2]
            nReaptheStormSoftCap = nReaptheStormValues[3]
        end
    end)
end
frameBloodthirst:RegisterEvent("ADDON_LOADED")
frameBloodthirst:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Bloodthirst.known and wan.spellData.Bloodthirst.id
        wan.BlizzardEventHandler(frameBloodthirst, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBloodthirst, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nCrushingForce = wan.GetTraitDescriptionNumbers(wan.traitData.CrushingForce.entryid, { 2 }, wan.traitData.CrushingForce.rank)

        local nViciousContemptValues = wan.GetTraitDescriptionNumbers(wan.traitData.ViciousContempt.entryid, { 1, 2 })
        nViciousContempt = nViciousContemptValues[1] * 0.01
        nViciousContemptThreshold = nViciousContemptValues[2] * 0.01

        local nImprovedWhirlwindValues = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedWhirlwind.entryid, { 2, 3 })
        nImprovedWhirlwindUnitCap = nImprovedWhirlwindValues[1]
        nImprovedWhirlwind = nImprovedWhirlwindValues[2] * 0.01
        nWhirlwindMaxRange = wan.traitData.ImprovedWhirlwind.known and 11 or 0

        nOverwhelmingBlades = wan.GetTraitDescriptionNumbers(wan.traitData.OverwhelmingBlades.entryid, { 1 }) * 0.01

        nBloodcrazeCritChance = wan.GetTraitDescriptionNumbers(wan.traitData.Bloodcraze.entryid, { 1 })

        nRecklessnessCritChance = wan.GetSpellDescriptionNumbers(wan.spellData.Recklessness.id, { 2 })

        nRecklessAbandonDotDmg = wan.GetTraitDescriptionNumbers(wan.traitData.RecklessAbandon.entryid, { 12 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBloodthirst, CheckAbilityValue, abilityActive)
    end
end)