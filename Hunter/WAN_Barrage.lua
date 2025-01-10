local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nBarrageCastTime, nBarrageDmg, nBarrageSoftCap = 0, 0, 0

-- Init trait data
local nPenetratingShots = 0
local nRapidFireArrows, nRapidFireCastTime, nRapidFireDmgPerArrow, nRapidFireDmg = 0, 0, 0, 0
local nTrickShots, nTrickShotsUnitCap = 0, 0
local nFanTheHammer = 0
local nRapidFireBarrageUnitCap, nRapidFireBarrage = 0, 0

-- Ability value calculation
local function CheckAbilityValue()

    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Barrage.id)
    then
        wan.UpdateAbilityData(wan.spellData.Barrage.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Barrage.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Barrage.basename)
        return
    end

    local checkTrickShots = wan.auraData.player.buff_TrickShots
    if wan.traitData.RapidFireBarrage.known and wan.traitData.TrickShots.known
        and (countValidUnit > 2 and not checkTrickShots)
        or (checkTrickShots and (wan.UnitIsCasting("player", wan.spellData.RapidFire.name)
            or wan.UnitIsCasting("player", wan.spellData.Barrage.name)
            or wan.UnitIsCasting("player", wan.spellData.AimedShot.name)))
    then
        wan.UpdateAbilityData(wan.spellData.Barrage.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cBarrageInstantDmg = 0
    local cBarrageDotDmg = 0
    local cBarrageInstantAoEDmg = 0
    local cBarrageDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cPenetratingShots = 0
    if wan.traitData.PenetratingShots.known then
        cPenetratingShots = cPenetratingShots + (wan.CritChance * nPenetratingShots)
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    local cRapidFireBarrageInstantDmg = 0
    local cRapidFireBarrageInstantDmgAoE = 0
    if not wan.traitData.RapidFireBarrage.known then
        local cBarrageUnitOverflow = wan.SoftCapOverflow(nBarrageSoftCap, countValidUnit)

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

            cBarrageInstantAoEDmg = cBarrageInstantAoEDmg + (nBarrageDmg * checkPhysicalDR * cBarrageUnitOverflow)
        end
    else
        local cFanTheHammer = 0
        if wan.traitData.RapidFireBarrage.known and wan.traitData.FantheHammer.known then
            cFanTheHammer = cFanTheHammer + (nRapidFireDmgPerArrow * nFanTheHammer)
        end

        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
        cRapidFireBarrageInstantDmg = cRapidFireBarrageInstantDmg + ((nRapidFireDmg + cFanTheHammer) * checkPhysicalDR)

        local countRapidFireBarrage = 0
        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                local cTrickShotsInstantDmgAoE = 0
                if wan.traitData.TrickShots.known and wan.auraData.player.buff_TrickShots then
                    local countTrickShots = 0
            
                    for trickShotsUnitToken, trickShotsGUID in pairs(idValidUnit) do
            
                        if trickShotsGUID ~= nameplateGUID then
                            local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(trickShotsUnitToken)
            
                            cTrickShotsInstantDmgAoE = cTrickShotsInstantDmgAoE + ((nRapidFireDmg + cFanTheHammer) * nTrickShots * checkUnitPhysicalDR)
                            countTrickShots = countTrickShots + 1
            
                            if countTrickShots >= nTrickShotsUnitCap then break end
                        end
                    end
                end

                cRapidFireBarrageInstantDmgAoE = cRapidFireBarrageInstantDmgAoE + (((nRapidFireDmg + cFanTheHammer) * checkUnitPhysicalDR + cTrickShotsInstantDmgAoE) * nRapidFireBarrage)
                countRapidFireBarrage = countRapidFireBarrage + 1

                if countRapidFireBarrage >= nRapidFireBarrageUnitCap then break end
            end
        end
    end

    local canMoveCast = true
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Barrage.id, nBarrageCastTime, canMoveCast)
    local cBarrageCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cBarrageInstantDmg = cBarrageInstantDmg + (cRapidFireBarrageInstantDmg * cBarrageCritValue)
    cBarrageDotDmg = cBarrageDotDmg
    cBarrageInstantAoEDmg = cBarrageInstantAoEDmg + (cRapidFireBarrageInstantDmgAoE * cBarrageCritValue)
    cBarrageDotDmgAoE = cBarrageDotDmgAoE

    local cBarrageDmg = (cBarrageInstantDmg + cBarrageDotDmg + cBarrageInstantAoEDmg + cBarrageDotDmgAoE) * castEfficiency

    local abilityValue = math.floor(cBarrageDmg)
    wan.UpdateAbilityData(wan.spellData.Barrage.basename, abilityValue, wan.spellData.Barrage.icon, wan.spellData.Barrage.name)
end

-- Init frame 
local frameBarrage = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nBarrageValues = wan.GetSpellDescriptionNumbers(wan.spellData.Barrage.id, { 1, 2, 3 })
            nBarrageCastTime = nBarrageValues[1]
            nBarrageDmg = nBarrageValues[2]
            nBarrageSoftCap = nBarrageValues[3]

            local nRapidFireValues = wan.GetSpellDescriptionNumbers(wan.spellData.RapidFire.id, { 1, 2, 3 })
            nRapidFireArrows = nRapidFireValues[1]
            nRapidFireCastTime = nRapidFireValues[2]
            nRapidFireDmgPerArrow = nRapidFireValues[3] / nRapidFireValues[1]
            nRapidFireDmg = nRapidFireValues[3]
        end
    end)
end
frameBarrage:RegisterEvent("ADDON_LOADED")
frameBarrage:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Barrage.known and wan.spellData.Barrage.id
        wan.BlizzardEventHandler(frameBarrage, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBarrage, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01

        local nTrickShotsValues = wan.GetTraitDescriptionNumbers(wan.traitData.TrickShots.entryid, { 2, 3 })
        nTrickShots = nTrickShotsValues[2] * 0.01
        nTrickShotsUnitCap = nTrickShotsValues[1]

        nFanTheHammer = wan.GetTraitDescriptionNumbers(wan.traitData.FantheHammer.entryid, { 1 })

        local nRapidFireBarrageValues = wan.GetTraitDescriptionNumbers(wan.traitData.RapidFireBarrage.entryid, { 1, 2 })
        nRapidFireBarrageUnitCap = nRapidFireBarrageValues[1]
        nRapidFireBarrage = nRapidFireBarrageValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBarrage, CheckAbilityValue, abilityActive)
    end
end)