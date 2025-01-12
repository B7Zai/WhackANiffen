local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nRapidFireArrows, nRapidFireCastTime, nRapidFireDmgPerArrow, nRapidFireDmg = 0, 0, 0, 0

-- Init trait datat
local nPenetratingShots = 0
local nTrickShots, nTrickShotsUnitCap = 0, 0
local nFanTheHammer = 0
local nLunarStormDuration, nLunarStormDmg, nLunarStormTickRate, nLunarStorm, nLunarStormICD, cLunarStormLastProc = 0, 0, 0, 0, 0, GetTime()

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or not wan.IsSpellUsable(wan.spellData.RapidFire.id)
        or wan.UnitIsCasting("player", wan.spellData.AimedShot.name)
        or wan.UnitIsCasting("player", wan.spellData.Barrage.name)
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

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cRapidFireInstantDmg = 0
    local cRapidFireDotDmg = 0
    local cRapidFireInstantDmgAoE = 0
    local cRapidFireDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cPenetratingShots = 0
    if wan.traitData.PenetratingShots.known then
        cPenetratingShots = cPenetratingShots + (wan.CritChance * nPenetratingShots)
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    local cFanTheHammer = 0
    if wan.traitData.FantheHammer.known then
        cFanTheHammer = cFanTheHammer + (nRapidFireDmgPerArrow * nFanTheHammer)
    end

    local cTrickShotsInstantDmgAoE = 0
    if wan.traitData.TrickShots.known and wan.auraData.player.buff_TrickShots then
        local countTrickShots = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cTrickShotsInstantDmgAoE = cTrickShotsInstantDmgAoE + ((nRapidFireDmg + cFanTheHammer) * nTrickShots * checkUnitPhysicalDR)
                countTrickShots = countTrickShots + 1

                if countTrickShots >= nTrickShotsUnitCap then break end
            end
        end
    end

    local cLunarStorm = 0
    if wan.traitData.LunarStorm.known then
        local currentTime = GetTime()
        local cLunarStormLast = currentTime - cLunarStormLastProc
        if cLunarStormLast > nLunarStormICD then
            for nameplateUnitToken, _ in pairs(idValidUnit) do
                local checkLunarStormDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.traitData.LunarStorm.traitkey]
                if checkLunarStormDebuff then cLunarStormLastProc = GetTime() break end
            end
            cLunarStorm = cLunarStorm + nLunarStorm 
        end
    end

    local canMoveCast = true
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.RapidFire.id, nRapidFireCastTime, canMoveCast)
    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cRapidFireCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cBaseCritValue = wan.ValueFromCritical(wan.CritChance)

    cRapidFireInstantDmg = cRapidFireInstantDmg + ((nRapidFireDmg + cFanTheHammer) * checkPhysicalDR * cRapidFireCritValue)
    cRapidFireDotDmg = cRapidFireDotDmg 
    cRapidFireInstantDmgAoE = cRapidFireInstantDmgAoE + ((cTrickShotsInstantDmgAoE + cLunarStorm) * cRapidFireCritValue)
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
            nRapidFireArrows = nRapidFireValues[1]
            nRapidFireCastTime = nRapidFireValues[2]
            nRapidFireDmgPerArrow = nRapidFireValues[3] / nRapidFireValues[1]
            nRapidFireDmg = nRapidFireValues[3]

            local nLunarStormValues = wan.GetTraitDescriptionNumbers(wan.traitData.LunarStorm.entryid, { 1, 3, 4, 5 })
            nLunarStormICD = nLunarStormValues[1]
            nLunarStormDuration = nLunarStormValues[2]
            nLunarStormDmg = nLunarStormValues[3]
            nLunarStormTickRate = nLunarStormValues[4]
            nLunarStorm = nLunarStormValues[3] *  (nLunarStormValues[2] / nLunarStormValues[4])
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

        nFanTheHammer = wan.GetTraitDescriptionNumbers(wan.traitData.FantheHammer.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRapidFire, CheckAbilityValue, abilityActive)
    end
end)