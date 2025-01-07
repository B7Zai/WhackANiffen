local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nKillShotInstantDmg, nKillShotDotDmg, nKillShotCritDamage = 0, 0, 0

-- Init trait data
local nVenomsBiteInstantDmg, nVenomsBiteDotDmg = 0, 0
local nAMurderOfCrows = 0
local nBansheesMarkProcChance = 0

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

    local cKillShotInstantDmg = nKillShotInstantDmg
    local cKillShotDotDmg = 0

    critDamageMod = critDamageMod + nKillShotCritDamage

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[wan.TargetUnitID]

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()

    local cVenomsBiteInstantDmg = 0
    local cVenomsBiteDotDmg = 0
    if wan.traitData.VenomsBite.known then
        cVenomsBiteInstantDmg = cVenomsBiteInstantDmg + nVenomsBiteInstantDmg
        local checkSerpentStingDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken].debuff_SerpentSting
        if not checkSerpentStingDebuff then
            local dotPotency = wan.CheckDotPotency(nVenomsBiteInstantDmg, targetUnitToken)
            cVenomsBiteDotDmg = cVenomsBiteDotDmg + (nVenomsBiteDotDmg * dotPotency)
        end
    end

    local cBlackArrowDotDmg = 0
    if wan.traitData.BlackArrow.known then
        checkPhysicalDR = 1
        local checkBlackArrowDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.traitData.BlackArrow.traitkey]
        if not checkBlackArrowDebuff then
            local dotPotency = wan.CheckDotPotency(nKillShotInstantDmg, targetUnitToken)

            cBlackArrowDotDmg = cBlackArrowDotDmg + (nKillShotDotDmg * dotPotency)
        end
    end

    local cBansheesMark = 0
    if wan.traitData.BansheesMark.known then
        cBansheesMark = cBansheesMark + (nAMurderOfCrows * nBansheesMarkProcChance)
    end

    -- Crit layer
    local cKillShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cBaseCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    local cKillShotInstantDmgAoE = 0
    local cKillShotDotDmgAoE = 0
    if wan.traitData.HuntersPrey.known then
        local activePets = (wan.IsPetUsable() and 1 or 0) * (wan.traitData.AnimalCompanion.known and 2 or 1)
        local countHuntersPreyUnit = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateGUID)

                local cVenomsBiteInstantDmg = 0
                local cVenomsBiteDotDmg = 0
                if wan.traitData.VenomsBite.known then
                    cVenomsBiteInstantDmg = cVenomsBiteInstantDmg + nVenomsBiteInstantDmg
                    local checkSerpentStingDebuff = wan.auraData[nameplateUnitToken].debuff_SerpentSting
                    if not checkSerpentStingDebuff then
                        local dotPotency = wan.CheckDotPotency(nVenomsBiteInstantDmg, nameplateUnitToken)
                        cVenomsBiteDotDmg = cVenomsBiteDotDmg + (nVenomsBiteDotDmg * dotPotency)
                    end
                end

                local cBlackArrowDotDmg = 0
                if wan.traitData.BlackArrow.known then
                    checkUnitPhysicalDR = 1
                    local checkBlackArrowDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.traitData.BlackArrow.traitkey]
                    if not checkBlackArrowDebuff then
                        local dotPotency = wan.CheckDotPotency(nKillShotInstantDmg, nameplateUnitToken)

                        cBlackArrowDotDmg = cBlackArrowDotDmg + (nKillShotDotDmg * dotPotency)
                    end
                end

                cKillShotInstantDmgAoE = cKillShotInstantDmgAoE + (nKillShotInstantDmg * cKillShotCritValue * checkUnitPhysicalDR) + (cVenomsBiteInstantDmg * cBaseCritValue)
                cKillShotDotDmgAoE = cKillShotDotDmgAoE + ((cVenomsBiteDotDmg + cBlackArrowDotDmg) * cBaseCritValue)

                countHuntersPreyUnit = countHuntersPreyUnit + 1

                if countHuntersPreyUnit > activePets then break end
            end
        end
    end

    cKillShotInstantDmg = cKillShotInstantDmg * checkPhysicalDR * cKillShotCritValue
    cKillShotDotDmg = ((cKillShotDotDmg + cVenomsBiteDotDmg + cBlackArrowDotDmg + (cBansheesMark * checkPhysicalDR)) * cKillShotCritValue)

    local cKillShotDmg = cKillShotInstantDmg + cKillShotDotDmg + cKillShotInstantDmgAoE + cKillShotDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cKillShotDmg)
    wan.UpdateAbilityData(wan.spellData.KillShot.basename, abilityValue, wan.spellData.KillShot.icon, wan.spellData.KillShot.name)
end

-- Init frame 
local frameArcaneShot = CreateFrame("Frame")
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
        end
    end)
end
frameArcaneShot:RegisterEvent("ADDON_LOADED")
frameArcaneShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.KillShot.known and wan.spellData.KillShot.id
        wan.BlizzardEventHandler(frameArcaneShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameArcaneShot, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        local nExplosiveVenomValues = wan.GetTraitDescriptionNumbers(wan.traitData.VenomsBite.entryid, { 4, 5 })
        nVenomsBiteInstantDmg = nExplosiveVenomValues[1]
        nVenomsBiteDotDmg = nExplosiveVenomValues[2]

        nBansheesMarkProcChance = wan.GetTraitDescriptionNumbers(wan.traitData.BansheesMark.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArcaneShot, CheckAbilityValue, abilityActive)
    end
end)