local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nRapidFireArrows, nRapidFireCastTime, nRapidFireDmgPerArrow, nRapidFireDmg = 0, 0, 0, 0

-- Init trait datat
local nPenetratingShots = 0
local nTrickShots, nTrickShotsUnitCap = 0, 0
local nAspectoftheHydra, nAspectoftheHydraUnitCap = 0, 1
local nAmmoConservation = 0
local nUnerringVision = 0
local nLunarStormDuration, nLunarStormDmg, nLunarStormTickRate, nLunarStorm = 0, 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.RapidFire.id)
        or wan.UnitIsCasting("player", wan.spellData.AimedShot.id)
    then
        wan.UpdateAbilityData(wan.spellData.RapidFire.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.RapidFire.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.RapidFire.basename)
        return
    end

    if wan.traitData.TrickShots.known and countValidUnit > 2 and not wan.auraData.player.buff_TrickShots then
        wan.UpdateAbilityData(wan.spellData.RapidFire.basename)
       return
    end

    local canMoveCast = true
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.RapidFire.id, nRapidFireCastTime, canMoveCast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.RapidFire.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cRapidFireInstantDmg = 0
    local cRapidFireDotDmg = 0
    local cRapidFireInstantDmgAoE = 0
    local cRapidFireDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- MARKSMAN TRAITS ----

    local cTrickShotsInstantDmgAoE = 0
    local checkTrickShotsBuff = wan.CheckUnitBuff(nil, wan.traitData.TrickShots.traitkey)
    if checkTrickShotsBuff then
        local countTrickShots = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cTrickShotsInstantDmgAoE = cTrickShotsInstantDmgAoE + (nRapidFireDmg * nTrickShots * checkUnitPhysicalDR)
                countTrickShots = countTrickShots + 1

                if countTrickShots >= nTrickShotsUnitCap then break end
            end
        end
    end

    local cAspectoftheHydra = 0
    if wan.traitData.AspectoftheHydra.known then
        local countAspectoftheHydraUnit = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cAspectoftheHydra = cAspectoftheHydra + (nRapidFireDmg * nAspectoftheHydra * checkUnitPhysicalDR)

                countAspectoftheHydraUnit = countAspectoftheHydraUnit + 1

                if countAspectoftheHydraUnit >= nAspectoftheHydraUnitCap then break end
            end
        end
    end

    local cPenetratingShots = 0
    if wan.traitData.PenetratingShots.known then
        cPenetratingShots = cPenetratingShots + (wan.CritChance * nPenetratingShots)
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    if wan.traitData.UnerringVision.known then
        local checkTrueshotBuff = wan.CheckUnitBuff(nil, wan.spellData.Trueshot.formattedName)
        if checkTrueshotBuff then
            critDamageMod = critDamageMod + nUnerringVision
            critDamageModBase = critDamageModBase + nUnerringVision
        end
    end

    ---- SENTINEL TRAITS ----

    local cLunarStormInstantDmgAoE = 0
    if wan.traitData.LunarStorm.known then
        local checkLunarStormDebuff = wan.CheckUnitDebuff("player", wan.traitData.LunarStorm.traitkey)
        if not checkLunarStormDebuff then
            cLunarStormInstantDmgAoE = cLunarStormInstantDmgAoE + nLunarStorm
        end
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cRapidFireCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cRapidFireCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cRapidFireInstantDmg = cRapidFireInstantDmg
        + (nRapidFireDmg * checkPhysicalDR * cRapidFireCritValue)

    cRapidFireDotDmg = cRapidFireDotDmg

    cRapidFireInstantDmgAoE = cRapidFireInstantDmgAoE
        + (cTrickShotsInstantDmgAoE * cRapidFireCritValue)
        + (cAspectoftheHydra * cRapidFireCritValue)
        + (cLunarStormInstantDmgAoE * cRapidFireCritValueBase)

    cRapidFireDotDmgAoE = cRapidFireDotDmgAoE

    local cRapidFireDmg = (cRapidFireInstantDmg + cRapidFireDotDmg + cRapidFireInstantDmgAoE + cRapidFireDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cRapidFireDmg)
    wan.UpdateAbilityData(wan.spellData.RapidFire.basename, abilityValue, wan.spellData.RapidFire.icon, wan.spellData.RapidFire.name)
end

-- Init frame 
local frameRapidFire = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nRapidFireValues = wan.GetSpellDescriptionNumbers(wan.spellData.RapidFire.id, { 1, 2, 3 })
            nRapidFireArrows = nRapidFireValues[1] + (wan.traitData.AmmoConservation.known and nAmmoConservation or 0)
            nRapidFireCastTime = nRapidFireValues[2] * 1000
            nRapidFireDmgPerArrow = nRapidFireValues[3] / nRapidFireValues[1]
            nRapidFireDmg = nRapidFireDmgPerArrow * nRapidFireArrows

            local nLunarStormValues = wan.GetTraitDescriptionNumbers(wan.traitData.LunarStorm.entryid, { 3, 4, 6 })
            nLunarStormDmg = nLunarStormValues[1]
            nLunarStormDuration = nLunarStormValues[2]
            nLunarStormTickRate = nLunarStormValues[3]
            nLunarStorm = nLunarStormDmg * (nLunarStormDuration / nLunarStormTickRate)
        end
    end)
end
frameRapidFire:RegisterEvent("ADDON_LOADED")
frameRapidFire:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.RapidFire.known and wan.spellData.RapidFire.id
        wan.BlizzardEventHandler(frameRapidFire, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameRapidFire, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01

        local nTrickShotsValues = wan.GetTraitDescriptionNumbers(wan.traitData.TrickShots.entryid, { 2, 3 })
        nTrickShots = nTrickShotsValues[2] * 0.01
        nTrickShotsUnitCap = nTrickShotsValues[1]

        nAspectoftheHydra = wan.GetTraitDescriptionNumbers(wan.traitData.AspectoftheHydra.entryid, { 1 }) * 0.01

        nAmmoConservation = wan.GetTraitDescriptionNumbers(wan.traitData.AmmoConservation.entryid, { 1 })

        nUnerringVision = wan.GetTraitDescriptionNumbers(wan.traitData.UnerringVision.entryid, { 2 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRapidFire, CheckAbilityValue, abilityActive)
    end
end)