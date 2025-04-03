local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nEyeBeamDmg, nEyeBeamSoftCap, nEyeBeamMaxRange = 0, 0, 20

-- Init trait data
local bCollectiveAnguish, nCollectiveAnguishDmg = false, 0
local bLooksCanKill = false
local bKnowYourEnemy, nKnowYourEnemy = false, 0

local bReaversMark, sReaversMark, nReaversMark = false, "ReaversMark", 0

local checkDemonsurgeEmpowerment = false
local bDemonsurge, nDemonsurgeDmg, nDemonsurgeSoftCap, bDemonsurgeMaxRange = false, 0, 0, 11
local bFocusedHatred, nFocusedHatred, nFocusedHatredStep = false, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.EyeBeam.id)
    then
        wan.UpdateAbilityData(wan.spellData.EyeBeam.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.EyeBeam.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.EyeBeam.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cEyeBeamInstantDmg = 0
    local cEyeBeamDotDmg = 0
    local cEyeBeamInstantDmgAoE = 0
    local cEyeBeamDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- DEMON HUNTER TRAITS ----

    local cCollectiveAnguishInstantDmgAoE = 0
    if bCollectiveAnguish then
        cCollectiveAnguishInstantDmgAoE = cCollectiveAnguishInstantDmgAoE + (nCollectiveAnguishDmg * countValidUnit)
    end

    ---- HAVOC TRAITS ----

    if bLooksCanKill then
        critChanceMod = critChanceMod + 100
    end

    if bKnowYourEnemy then
        critDamageMod = critDamageMod + (wan.CritChance * nKnowYourEnemy)
        critDamageModBase = critDamageModBase + (wan.CritChance * nKnowYourEnemy)
    end

    ---- ALDRACHI REAVER TRAITS ----

    local cReaversMarkAoE = 1
    if bReaversMark then

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitReaversMarkDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sReaversMark)
            if checkUnitReaversMarkDebuff then
                local cReaversMarkStacks = checkUnitReaversMarkDebuff and checkUnitReaversMarkDebuff.applications

                if not cReaversMarkStacks or cReaversMarkStacks == 0 then
                    cReaversMarkStacks = 1
                end

                cReaversMarkAoE = cReaversMarkAoE + ((nReaversMark * cReaversMarkStacks) / countValidUnit)
            end
        end
    end

    ---- FEL-SCARRED TRAITS ----

    local cDemonsurgeInstantDmgAoE = 0
    if bDemonsurge and checkDemonsurgeEmpowerment then
        local _, countValidUnitDemonsurge = wan.ValidUnitBoolCounter(nil, bDemonsurgeMaxRange)
        local cDemonsurgeUnitOverflow = wan.AdjustSoftCapUnitOverflow(nDemonsurgeSoftCap, countValidUnitDemonsurge)

        local cFocusedHatred = 1
        if bFocusedHatred then
            local nFocusedHatredUnits = math.max(countValidUnitDemonsurge - 1, 0)

            cFocusedHatred = cFocusedHatred + (math.max((nFocusedHatred - (nFocusedHatredStep *  nFocusedHatredUnits)), 0))
        end

        cDemonsurgeInstantDmgAoE = cDemonsurgeInstantDmgAoE + (nDemonsurgeDmg * cDemonsurgeUnitOverflow * cFocusedHatred)
    end

    local cEyeBeamUnitOverflow = wan.AdjustSoftCapUnitOverflow(nEyeBeamSoftCap, countValidUnit)
    local cEyeBeamCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cEyeBeamCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cEyeBeamInstantDmg = cEyeBeamInstantDmg

    cEyeBeamDotDmg = cEyeBeamDotDmg

    cEyeBeamInstantDmgAoE = cEyeBeamInstantDmgAoE
        + (nEyeBeamDmg * cEyeBeamUnitOverflow * cEyeBeamCritValue * cReaversMarkAoE)
        + (cCollectiveAnguishInstantDmgAoE * cEyeBeamCritValueBase * cReaversMarkAoE)

    cEyeBeamDotDmgAoE = cEyeBeamDotDmgAoE

    local cEyeBeamDmg = cEyeBeamInstantDmg + cEyeBeamDotDmg + cEyeBeamInstantDmgAoE + cEyeBeamDotDmgAoE

    local cdPotency = wan.CheckOffensiveCooldownPotency(cEyeBeamDmg, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cEyeBeamDmg) or 0
    wan.UpdateAbilityData(wan.spellData.EyeBeam.basename, abilityValue, wan.spellData.EyeBeam.icon, wan.spellData.EyeBeam.name)
end

-- Init frame 
local frameEyeBeam = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)

        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nEyeBeamValues = wan.GetSpellDescriptionNumbers(wan.spellData.EyeBeam.id, { 1, 3 })
            nEyeBeamDmg = nEyeBeamValues[1]
            nEyeBeamSoftCap = nEyeBeamValues[2]

            nCollectiveAnguishDmg = wan.GetTraitDescriptionNumbers(wan.traitData.CollectiveAnguish.entryid, { 1 }, wan.traitData.CollectiveAnguish.rank)

            local nDemonsurgeValues = wan.GetTraitDescriptionNumbers(wan.traitData.Demonsurge.entryid, { 2, 3 }, wan.traitData.Demonsurge.rank)
            nDemonsurgeDmg = nDemonsurgeValues[1]
            nDemonsurgeSoftCap = nDemonsurgeValues[2]
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.EyeBeam.id then
            checkDemonsurgeEmpowerment = false
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.Metamorphosis.id then
            checkDemonsurgeEmpowerment = true
        end

    end)
end
frameEyeBeam:RegisterEvent("ADDON_LOADED")
frameEyeBeam:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.EyeBeam.isPassive and wan.spellData.EyeBeam.known and wan.spellData.EyeBeam.id
        wan.BlizzardEventHandler(frameEyeBeam, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameEyeBeam, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then

        bCollectiveAnguish = wan.traitData.CollectiveAnguish.known

        bLooksCanKill = wan.traitData.LooksCanKill.known

        bKnowYourEnemy = wan.traitData.KnowYourEnemy.known
        nKnowYourEnemy = wan.GetTraitDescriptionNumbers(wan.traitData.KnowYourEnemy.entryid, { 1 }, wan.traitData.KnowYourEnemy.rank) * 0.01

        bReaversMark = wan.traitData.ReaversMark.known
        sReaversMark = wan.traitData.ReaversMark.traitkey
        nReaversMark = wan.GetTraitDescriptionNumbers(wan.traitData.ReaversMark.entryid, { 1 }, wan.traitData.ReaversMark.rank) * 0.01

        bDemonsurge = wan.traitData.Demonsurge.known

        bFocusedHatred = wan.traitData.FocusedHatred.known
        local nFocusedHatredValues = wan.GetTraitDescriptionNumbers(wan.traitData.FocusedHatred.entryid, { 1, 2 }, wan.traitData.FocusedHatred.rank)
        nFocusedHatred = nFocusedHatredValues[1] * 0.01
        nFocusedHatredStep = nFocusedHatredValues[2] * 10
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameEyeBeam, CheckAbilityValue, abilityActive)
    end
end)