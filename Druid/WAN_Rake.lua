local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local abilityActive = false
local sRakeDebuff, nRakeInstantDmg, nRakeDotDmg, nRakeMaxRange = "Rake", 0, 0, 8
local sCatForm = "CatForm"
local sProwl = "Prowl"

-- Init trait
local bSuddenAmbush, sSuddenAmbush = false, "SuddenAmbush"
local bPouncingStrikes, nPouncingStrikes = false, 0
local bDoubleClawedRake, nDoubleClawedRakeAoECap = false, 0
local bBloodtalons, sBloodtalons, nBloodtalonsTimer, runBloodtalons = false, "Bloodtalons", 0, true

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or not wan.CheckUnitBuff(nil, sCatForm)
        or not wan.IsSpellUsable(wan.spellData.Rake.id)
    then
        wan.UpdateAbilityData(wan.spellData.Rake.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nRakeMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Rake.basename)
        return
    end

    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cRakeInstantDmg = 0
    local cRakeDotDmg = 0
    local cRakeInstantDmgAoE = 0
    local cRakeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cRakeDotDmgBase = 0
    local checkRakeDebuff = wan.CheckUnitDebuff(nil, sRakeDebuff)
    if not checkRakeDebuff then
        local dotPotency = wan.CheckDotPotency(nRakeInstantDmg)

        cRakeDotDmgBase = cRakeDotDmgBase + (nRakeDotDmg * dotPotency)
    end

    ---- FERAL TRAITS ----

    -- Double-Clawed Rake
    local cDoubleClawedRakeInstantDmgAoE = 0
    local cDoubleClawedRakeDotDmgAoE = 0
    if bDoubleClawedRake then
        local cDoubleClawedRakeAoECap = math.min((math.max(countValidUnit - 1, 0)), nDoubleClawedRakeAoECap)

        cDoubleClawedRakeInstantDmgAoE = cDoubleClawedRakeInstantDmgAoE + (nRakeInstantDmg * cDoubleClawedRakeAoECap)

        local countDoubleClawedRakeUnits = 0
        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkDoubleClawedDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sRakeDebuff)

                if not checkDoubleClawedDebuff then

                    local unitDotPotency = wan.CheckDotPotency(nRakeInstantDmg, nameplateUnitToken)

                    cDoubleClawedRakeDotDmgAoE = nRakeDotDmg * unitDotPotency

                    countDoubleClawedRakeUnits = countDoubleClawedRakeUnits + 1

                    if countDoubleClawedRakeUnits >= nDoubleClawedRakeAoECap then break end
                end
            end
        end
    end

    local cPouncingStrikes = 1
    if bPouncingStrikes or wan.PlayerState.SpecializationName ~= "Feral" then
        local checkProwl = wan.CheckUnitBuff(nil, sProwl)
        local checkSuddenAmbush = nil

        if bSuddenAmbush then
            checkSuddenAmbush = wan.CheckUnitBuff(nil, sSuddenAmbush)
        end

        if checkProwl or checkSuddenAmbush then
            critChanceMod = critChanceMod + wan.CritChance
            cPouncingStrikes = cPouncingStrikes + nPouncingStrikes
        end

        --- Poucing Strikes is baseline whenever the player isn't playing Feral
        --- spell decription doesn't get updated so manual update is necessary
    end

    if bBloodtalons then
        if not wan.IsTimerRunning then
            runBloodtalons = true
        end

        local checkBloodtalonsBuff = wan.CheckUnitBuff(nil, sBloodtalons)
        if not checkBloodtalonsBuff and not runBloodtalons then
            wan.UpdateAbilityData(wan.spellData.Rake.basename)
            return
        end
    end

    local cRakeCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cRakeCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cRakeInstantDmg = cRakeInstantDmg
        + (nRakeInstantDmg * cRakeCritValue * cPouncingStrikes)

    cRakeDotDmg = cRakeDotDmg
        + (cRakeDotDmgBase * cRakeCritValue * cPouncingStrikes)

    cRakeInstantDmgAoE = cRakeInstantDmgAoE
        + (cDoubleClawedRakeInstantDmgAoE * cRakeCritValue * cPouncingStrikes)

    cRakeDotDmgAoE = cRakeDotDmgAoE
        + (cDoubleClawedRakeDotDmgAoE * cRakeCritValue * cPouncingStrikes)

    local cRakeDmg = cRakeInstantDmg + cRakeDotDmg + cRakeInstantDmgAoE + cRakeDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cRakeDmg)
    wan.UpdateAbilityData(wan.spellData.Rake.basename, abilityValue, wan.spellData.Rake.icon, wan.spellData.Rake.name)
end

local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)
        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local rakeValues = wan.GetSpellDescriptionNumbers(wan.spellData.Rake.id, { 1, 2, 3 })
            nRakeInstantDmg = rakeValues[1]
            nRakeDotDmg = rakeValues[2]
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and bBloodtalons then
            if spellID == wan.spellData.Rake.id then
                wan.SetTimer(nBloodtalonsTimer)

                if wan.IsTimerRunning then
                    runBloodtalons = false
                end
            end
        end
    end)
end

local frameRake = CreateFrame("Frame")
frameRake:RegisterEvent("ADDON_LOADED")
frameRake:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Rake.known and wan.spellData.Rake.id
        wan.BlizzardEventHandler(frameRake, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameRake, CheckAbilityValue, abilityActive)

        sCatForm = wan.spellData.CatForm.formattedName
        sProwl = wan.spellData.Prowl.formattedName
        sRakeDebuff = wan.spellData.Rake.formattedName
        nRakeMaxRange = wan.spellData.Swipe.known and wan.spellData.Swipe.maxRange or 8
    end

    if event == "TRAIT_DATA_READY" then
        bSuddenAmbush = wan.traitData.SuddenAmbush.known
        sSuddenAmbush = wan.traitData.SuddenAmbush.traitkey

        bPouncingStrikes = wan.traitData.PouncingStrikes.known
        nPouncingStrikes = wan.GetTraitDescriptionNumbers(wan.traitData.PouncingStrikes.entryid, { 3 }) * 0.01

        bBloodtalons = wan.traitData.Bloodtalons.known
        sBloodtalons = wan.traitData.Bloodtalons.traitkey
        nBloodtalonsTimer = wan.GetTraitDescriptionNumbers(wan.traitData.Bloodtalons.entryid, { 2 })

        bDoubleClawedRake = wan.traitData.DoubleClawedRake.known
        nDoubleClawedRakeAoECap = wan.GetTraitDescriptionNumbers(wan.traitData.DoubleClawedRake.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRake, CheckAbilityValue, abilityActive)
    end
end)
