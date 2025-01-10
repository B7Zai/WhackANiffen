local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nKillShotInstantDmg, nKillShotDotDmg, nKillShotCritDamage = 0, 0, 0

-- Init trait data
local nPenetratingShots = 0
local nVenomsBiteInstantDmg, nVenomsBiteDotDmg = 0, 0
local nHuntersPrey = 0
local nAMurderOfCrows = 0
local nBansheesMarkProcChance = 0
local nImprovedDeathblow = 0
local nKillerAccuracy = 0
local nRazorFragmentsUnitCap, nRazorFragments = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.KillShot.id)
    then
        wan.UpdateAbilityData(wan.spellData.KillShot.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, _, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.KillShot.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.KillShot.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cKillShotInstantDmg = 0
    local cKillShotDotDmg = 0
    local cKillShotInstantDmgAoE = 0
    local cKillShotDotDmgAoE = 0

    critDamageMod = critDamageMod + nKillShotCritDamage

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[wan.TargetUnitID]

    local cPenetratingShots = 0
    if wan.traitData.PenetratingShots.known then
        cPenetratingShots = cPenetratingShots + (wan.CritChance * nPenetratingShots)
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    if wan.traitData.ImprovedDeathblow.known then
        critDamageMod = critDamageMod + nImprovedDeathblow
    end

    if wan.traitData.KillerAccuracy.known then
        critChanceMod = critChanceMod + nKillerAccuracy
        critDamageMod = critDamageMod + nKillerAccuracy
    end

    local cHuntersPrey = 1
    local cHuntersPreyInstantDmgAoE = 0
    if wan.traitData.HuntersPrey.known then
        local activePets = (wan.IsPetUsable() and 1 or 0) * (wan.traitData.AnimalCompanion.known and 2 or 1)
        cHuntersPrey = cHuntersPrey + (nHuntersPrey * activePets)

        local countHuntersPreyUnit = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local checkUnitPhysicalDR = wan.traitData.BlackArrow.known and 1 or wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cHuntersPreyInstantDmgAoE = cHuntersPreyInstantDmgAoE + (nKillShotInstantDmg * checkUnitPhysicalDR)

                countHuntersPreyUnit = countHuntersPreyUnit + 1

                if countHuntersPreyUnit > activePets then break end
            end
        end
    end

    local cVenomsBiteInstantDmg = 0
    local cVenomsBiteDotDmg = 0
    local cVenomsBiteInstantDmgAoE = 0
    local cVenomsBiteDotDmgAoE = 0
    if wan.traitData.VenomsBite.known then
        cVenomsBiteInstantDmg = cVenomsBiteInstantDmg + nVenomsBiteInstantDmg
        local checkSerpentStingDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken].debuff_SerpentSting
        if not checkSerpentStingDebuff then
            local dotPotency = wan.CheckDotPotency(nVenomsBiteInstantDmg, targetUnitToken)
            cVenomsBiteDotDmg = cVenomsBiteDotDmg + (nVenomsBiteDotDmg * dotPotency)
        end

        if wan.traitData.HuntersPrey.known then
            local activePets = (wan.IsPetUsable() and 1 or 0) * (wan.traitData.AnimalCompanion.known and 2 or 1)
            local countHuntersPreyUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    cVenomsBiteInstantDmgAoE = cVenomsBiteInstantDmgAoE + nVenomsBiteInstantDmg

                    local checkSerpentStingDebuff = wan.auraData[nameplateUnitToken].debuff_SerpentSting
                    if not checkSerpentStingDebuff then
                        local dotPotency = wan.CheckDotPotency(nVenomsBiteInstantDmg, nameplateUnitToken)
                        cVenomsBiteDotDmgAoE = cVenomsBiteDotDmgAoE + (nVenomsBiteDotDmg * dotPotency)
                    end

                    countHuntersPreyUnit = countHuntersPreyUnit + 1

                    if countHuntersPreyUnit > activePets then break end
                end
            end
        end
    end

    local cBlackArrowDotDmg = 0
    local cBlackArrowDotDmgAoE = 0
    if wan.traitData.BlackArrow.known then
        local checkBlackArrowDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.traitData.BlackArrow.traitkey]
        if not checkBlackArrowDebuff then
            local dotPotency = wan.CheckDotPotency(nKillShotInstantDmg, targetUnitToken)
            cBlackArrowDotDmg = cBlackArrowDotDmg + (nKillShotDotDmg * dotPotency)
        end

        if wan.traitData.HuntersPrey.known then
            local activePets = (wan.IsPetUsable() and 1 or 0) * (wan.traitData.AnimalCompanion.known and 2 or 1)
            local countHuntersPreyUnit = 0
            
            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitBlackArrowDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.traitData.BlackArrow.traitkey]

                    if not checkUnitBlackArrowDebuff then
                        local dotPotency = wan.CheckDotPotency(nKillShotInstantDmg, nameplateUnitToken)

                        cBlackArrowDotDmgAoE = cBlackArrowDotDmgAoE + (nKillShotDotDmg * dotPotency)

                        countHuntersPreyUnit = countHuntersPreyUnit + 1

                        if countHuntersPreyUnit > activePets then break end
                    end
                end
            end
        end
    end

    local cBansheesMark = 0
    if wan.traitData.BansheesMark.known then
        cBansheesMark = cBansheesMark + (nAMurderOfCrows * nBansheesMarkProcChance)
    end

    local checkPhysicalDR = wan.traitData.BlackArrow.known and 1 or wan.CheckUnitPhysicalDamageReduction()

    -- Crit layer
    local cKillShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cBaseCritValue = wan.ValueFromCritical(wan.CritChance, nil, cPenetratingShots)

    cKillShotInstantDmg = cKillShotInstantDmg + (nKillShotInstantDmg * cHuntersPrey * checkPhysicalDR * cKillShotCritValue) + (cVenomsBiteInstantDmg * cBaseCritValue)
    cKillShotDotDmg = cKillShotDotDmg + ((cVenomsBiteDotDmg + cBlackArrowDotDmg + cBansheesMark) * cBaseCritValue)
    cKillShotInstantDmgAoE = cKillShotInstantDmgAoE + ((cHuntersPreyInstantDmgAoE * cHuntersPrey * checkPhysicalDR * cKillShotCritValue) + (cVenomsBiteInstantDmgAoE * cBaseCritValue))

    local cRazorFragmentDotDmgAoE = 0
    if wan.traitData.RazorFragments.known then
        local checkRazorFragmentsBuff = wan.auraData.player["buff_" .. wan.traitData.RazorFragments.traitkey]
        local countRazorFragments = 0

        if checkRazorFragmentsBuff then
            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
                if nameplateGUID ~= targetGUID then
                    local checkRazorFragmentDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.traitData.RazorFragments.traitkey]

                    if not checkRazorFragmentDebuff then
                        cRazorFragmentDotDmgAoE = cRazorFragmentDotDmgAoE + (nKillShotInstantDmg * cHuntersPrey * nRazorFragments * checkPhysicalDR * cKillShotCritValue * nRazorFragments)
                        countRazorFragments = countRazorFragments + 1

                        if countRazorFragments >= nRazorFragmentsUnitCap then break end
                    end
                end
            end
        end
    end

    cKillShotDotDmgAoE = cKillShotDotDmgAoE + ((cVenomsBiteDotDmgAoE + cBlackArrowDotDmgAoE) * cBaseCritValue) + cRazorFragmentDotDmgAoE

    local cKillShotDmg = cKillShotInstantDmg + cKillShotDotDmg + cKillShotInstantDmgAoE + cKillShotDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cKillShotDmg)
    wan.UpdateAbilityData(wan.spellData.KillShot.basename, abilityValue, wan.spellData.KillShot.icon, wan.spellData.KillShot.name)
end

-- Init frame 
local frameKillShot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nKillShotValues = wan.GetSpellDescriptionNumbers(wan.spellData.KillShot.id, { 1, 2, 3 })
            nKillShotInstantDmg = nKillShotValues[1]
            nKillShotDotDmg = wan.traitData.BlackArrow.known and nKillShotValues[2] or 0
            nKillShotCritDamage = not wan.traitData.BlackArrow.known and nKillShotValues[3] or 0

            nAMurderOfCrows = wan.GetTraitDescriptionNumbers(wan.traitData.AMurderofCrows.entryid, { 2 })

            local nExplosiveVenomValues = wan.GetTraitDescriptionNumbers(wan.traitData.VenomsBite.entryid, { 4, 5 })
            nVenomsBiteInstantDmg = nExplosiveVenomValues[1]
            nVenomsBiteDotDmg = nExplosiveVenomValues[2]
        end
    end)
end
frameKillShot:RegisterEvent("ADDON_LOADED")
frameKillShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.KillShot.known and wan.spellData.KillShot.id
        wan.BlizzardEventHandler(frameKillShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameKillShot, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01

        nBansheesMarkProcChance = wan.GetTraitDescriptionNumbers(wan.traitData.BansheesMark.entryid, { 1 }) * 0.01

        nHuntersPrey = wan.GetTraitDescriptionNumbers(wan.traitData.HuntersPrey.entryid, { 1 }) * 0.01

        nImprovedDeathblow = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedDeathblow.entryid, { 3 })
        
        nKillerAccuracy = wan.GetTraitDescriptionNumbers(wan.traitData.KillerAccuracy.entryid, { 1 })

        local nRazorFragmentsValues = wan.GetTraitDescriptionNumbers(wan.traitData.RazorFragments.entryid, { 2, 3 })
        nRazorFragmentsUnitCap = nRazorFragmentsValues[1]
        nRazorFragments = nRazorFragmentsValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameKillShot, CheckAbilityValue, abilityActive)
    end
end)