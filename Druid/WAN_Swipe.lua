local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local checkDebuffs = { "Rake", "Thrash", "Rip", "FeralFrenzy", "Tear", "FrenziedAssault" }
local nSwipeDmg, nSwipeSoftCap = 0, 0
local sCatForm, sBearForm = "CatForm", "BearForm"
local sProwl = "Prowl"

-- Init trait data
local bMercilessClaws, nMercilessClaws= false, 0
local bThrashingClaws, nThrashingClaws, sThrashDebuff, nThrashDotDmg  = false, 0, "Thrash", 0
local bBloodtalons, sBloodtalons, nBloodtalonsTimer, runBloodtalons = false, "Bloodtalons", 0, true
local bStrikefortheHeart, nStrikefortheHeart = false, 0

-- Ability value calculation
local function CheckAbilityValue()
    local _, insufficientPowerShred = wan.IsSpellUsable(wan.spellData.Shred.id)
    local isUsableSwipe, _ = wan.IsSpellUsable(wan.spellData.Swipe.id)

    if not wan.PlayerState.Status 
        or (wan.CheckUnitBuff(nil, sCatForm) and (not isUsableSwipe or insufficientPowerShred))
        or (wan.CheckUnitBuff(nil, sBearForm) and not isUsableSwipe)
    then
        wan.UpdateAbilityData(wan.spellData.Swipe.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Swipe.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Swipe.basename)
        return
    end

    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cSwipeInstantDmg = 0
    local cSwipeDotDmg = 0
    local cSwipeInstantDmgAoE = 0
    local cSwipeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local nSwipeInstantDmgBaseAoE = 0
    local cSwipeUnitOverflow = wan.SoftCapOverflow(nSwipeSoftCap, countValidUnit)
    for nameplateUnitToken, _ in pairs (idValidUnit) do
        local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

        nSwipeInstantDmgBaseAoE = nSwipeInstantDmgBaseAoE + (nSwipeDmg * checkUnitPhysicalDR * cSwipeUnitOverflow)
    end

    ---- FERAL TRAITS ----

    local cMercilessClaws = 1
    if bMercilessClaws then

        for nameplateUnitToken, _ in pairs (idValidUnit) do
            local checkUnitAnyDebuff = wan.CheckUnitAnyDebuff(nameplateUnitToken, checkDebuffs)

            if checkUnitAnyDebuff then
                cMercilessClaws = cMercilessClaws + (nMercilessClaws / countValidUnit)
            end
        end
    end

    local cThrashingClawsDotDmgAoE = 0
    if bThrashingClaws then

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sThrashDebuff)

            if not checkDebuff then
                local checkUnitDotPotency = wan.CheckDotPotency(nSwipeDmg, nameplateUnitToken)
                cThrashingClawsDotDmgAoE = cThrashingClawsDotDmgAoE + (nThrashDotDmg * checkUnitDotPotency)
            end
        end
    end

    if bBloodtalons then
        if not wan.IsTimerRunning then
            runBloodtalons = true
        end

        local checkBloodtalonsBuff = wan.CheckUnitBuff(nil, sBloodtalons)
        if not checkBloodtalonsBuff and not runBloodtalons then
            wan.UpdateAbilityData(wan.spellData.Swipe.basename)
            return
        end
    end

    ---- DRUID OF THE CLAW TRAITS ----

    if bStrikefortheHeart then
        critChanceMod = critChanceMod + nStrikefortheHeart
        critDamageMod = critDamageMod + nStrikefortheHeart
    end

    -- Crit layer
    local cSwipeInstantCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cSwipeDotCritValue = wan.ValueFromCritical(wan.CritChance)

    cSwipeInstantDmg = cSwipeInstantDmg

    cSwipeDotDmg = cSwipeDotDmg

    cSwipeInstantDmgAoE = cSwipeInstantDmgAoE
        + (nSwipeInstantDmgBaseAoE * cSwipeInstantCritValue * cMercilessClaws)

    cSwipeDotDmgAoE = cSwipeDotDmgAoE
        + (cThrashingClawsDotDmgAoE * cSwipeDotCritValue)

    local cSwipeDmg = cSwipeInstantDmg + cSwipeDotDmg + cSwipeInstantDmgAoE + cSwipeDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cSwipeDmg)
    wan.UpdateAbilityData(wan.spellData.Swipe.basename, abilityValue, wan.spellData.Swipe.icon, wan.spellData.Swipe.name)
end

-- Init frame 
local frameSwipe = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)

        if event == "SPELLS_CHANGED" then
            if not wan.traitData.BrutalSlash.known then
                nSwipeSoftCap = wan.GetSpellDescriptionNumbers(wan.spellData.Swipe.id, { 2 })
            elseif wan.traitData.BrutalSlash.known and wan.traitData.MercilessClaws.known then
                nSwipeSoftCap = wan.GetSpellDescriptionNumbers(wan.spellData.Swipe.id, { 3 })
            elseif wan.traitData.BrutalSlash.known and not wan.traitData.MercilessClaws.known then
                nSwipeSoftCap = wan.GetSpellDescriptionNumbers(wan.spellData.Swipe.id, { 2 })
            end
        end

        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nSwipeDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Swipe.id, { 1 })
            
            nThrashDotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Thrash.id, { 2 })
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player"  and bBloodtalons then
            if spellID == wan.spellData.Swipe.id then
                wan.SetTimer(nBloodtalonsTimer)

                if wan.IsTimerRunning then
                    runBloodtalons = false
                end
            end
        end
    end)
end
frameSwipe:RegisterEvent("ADDON_LOADED")
frameSwipe:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Swipe.known and wan.spellData.Swipe.id
        wan.BlizzardEventHandler(frameSwipe, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameSwipe, CheckAbilityValue, abilityActive)

        sCatForm = wan.spellData.CatForm.formattedName
        sBearForm = wan.spellData.BearForm.formattedName
        sProwl = wan.spellData.Prowl.formattedName
    end

    if event == "TRAIT_DATA_READY" then

        bMercilessClaws = wan.traitData.MercilessClaws.known
        nMercilessClaws = wan.GetTraitDescriptionNumbers(wan.traitData.MercilessClaws.entryid, { 2 }) * 0.01

        bThrashingClaws = wan.traitData.ThrashingClaws.known
        sThrashDebuff = wan.spellData.Thrash.formattedName

        bBloodtalons = wan.traitData.Bloodtalons.known
        sBloodtalons = wan.traitData.Bloodtalons.traitkey
        nBloodtalonsTimer = wan.GetTraitDescriptionNumbers(wan.traitData.Bloodtalons.entryid, { 2 })

        bStrikefortheHeart = wan.traitData.StrikefortheHeart.known
        nStrikefortheHeart = wan.GetTraitDescriptionNumbers(wan.traitData.StrikefortheHeart.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSwipe, CheckAbilityValue, abilityActive)
    end
end)