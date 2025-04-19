local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local abilityActive = false
local checkDebuffs = {"Rake", "Thrash", "Rip", "FeralFrenzy", "Tear", "FrenziedAssault"}
local nShredDmg, nShredMaxRange  = 0, 8
local sCatForm = "CatForm"
local sProwl = "Prowl"

-- Init trait data
local bSuddenAmbush, sSuddenAmbush = false, "SuddenAmbush"
local bPouncingStrikes, nPouncingStrikes = false, 0
local bMercilessClaws, nMercilessClaws= false, 0
local bThrashingClaws, nThrashingClaws, sThrashDebuff, nThrashDotDmg  = false, 0, "Thrash", 0
local bBloodtalons, sBloodtalons, nBloodtalonsTimer, runBloodtalons = false, "Bloodtalons", 0, true
local bStrikefortheHeart, nStrikefortheHeart = false, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or not wan.IsSpellUsable(wan.spellData.Shred.id)
        or not wan.CheckUnitBuff(nil, sCatForm)
    then
        wan.UpdateAbilityData(wan.spellData.Shred.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(nil, nShredMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Shred.basename)
        return
    end

    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cShredInstantDmg = 0
    local cShredDotDmg = 0
    local cShredInstantDmgAoE = 0
    local cShredDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- FERAL TRAITS ----

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

    local cMercilessClaws = 1
    if bMercilessClaws and wan.CheckForAnyDebuff(targetUnitToken, checkDebuffs) then
        cMercilessClaws = cMercilessClaws + nMercilessClaws
    end

    local cThrashingClaws = 1
    local cThrashingClawsDotDmg = 0
    if bThrashingClaws then
        local checkThrashDebuff = wan.CheckUnitDebuff(nil, sThrashDebuff)                                  
        local checkAnyDebuff = wan.CheckForAnyDebuff(targetUnitToken, checkDebuffs)

        if checkAnyDebuff then
            cThrashingClaws = 1 + nThrashingClaws
        end

        if not checkThrashDebuff then
            local dotPotency = wan.CheckDotPotency(nShredDmg)

            cThrashingClawsDotDmg = nThrashDotDmg * dotPotency
        end
    end

    if bBloodtalons then
        if not wan.IsTimerRunning then
            runBloodtalons = true
        end

        local checkBloodtalonsBuff = wan.CheckUnitBuff(nil, sBloodtalons)
        if not checkBloodtalonsBuff and not runBloodtalons then
            wan.UpdateAbilityData(wan.spellData.Shred.basename)
            return
        end
    end

    ---- DRUID OF THE CLAW TRAITS ----

    if bStrikefortheHeart then
        critChanceMod = critChanceMod + nStrikefortheHeart
        critDamageMod = critDamageMod + nStrikefortheHeart
    end

    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cShredCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cShredCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cShredInstantDmg = cShredInstantDmg
        + (nShredDmg * checkUnitPhysicalDR * cShredCritValue * cPouncingStrikes * cMercilessClaws * cThrashingClaws)

    cShredDotDmg = cShredDotDmg
        + (cThrashingClawsDotDmg * cShredCritValueBase)

    cShredInstantDmgAoE = cShredInstantDmgAoE

    cShredDotDmgAoE = cShredDotDmgAoE

    local cShredDmg = cShredInstantDmg + cShredDotDmg + cShredInstantDmgAoE + cShredDotDmgAoE

    local abilityValue = math.floor(cShredDmg)
    wan.UpdateAbilityData(wan.spellData.Shred.basename, abilityValue, wan.spellData.Shred.icon, wan.spellData.Shred.name)
end

local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)
        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nShredDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Shred.id, { 1 })

            nThrashDotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Thrash.id, { 2 })
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and bBloodtalons then
            if spellID == wan.spellData.Shred.id then
                wan.SetTimer(nBloodtalonsTimer)

                if wan.IsTimerRunning then
                    runBloodtalons = false
                end
            end
        end
    end)
end

local frameShred = CreateFrame("Frame")
frameShred:RegisterEvent("ADDON_LOADED")
frameShred:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Shred.known and wan.spellData.Shred.id
        wan.BlizzardEventHandler(frameShred, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameShred, CheckAbilityValue, abilityActive)

        sCatForm = wan.spellData.CatForm.formattedName
        sProwl = wan.spellData.Prowl.formattedName
        nShredMaxRange = wan.spellData.Swipe.known and wan.spellData.Swipe.maxRange or 8
    end

    if event == "TRAIT_DATA_READY" then

        bSuddenAmbush = wan.traitData.SuddenAmbush.known
        sSuddenAmbush = wan.traitData.SuddenAmbush.traitkey

        bPouncingStrikes = wan.traitData.PouncingStrikes.known
        nPouncingStrikes = wan.GetTraitDescriptionNumbers(wan.traitData.PouncingStrikes.entryid, { 3 }) * 0.01

        bMercilessClaws = wan.traitData.MercilessClaws.known
        nMercilessClaws = wan.GetTraitDescriptionNumbers(wan.traitData.MercilessClaws.entryid, { 1 }) * 0.01

        bThrashingClaws = wan.traitData.ThrashingClaws.known
        sThrashDebuff = wan.spellData.Thrash.formattedName
        nThrashingClaws = wan.GetTraitDescriptionNumbers(wan.traitData.ThrashingClaws.entryid, { 1 }) * 0.01

        bBloodtalons = wan.traitData.Bloodtalons.known
        sBloodtalons = wan.traitData.Bloodtalons.traitkey
        nBloodtalonsTimer = wan.GetTraitDescriptionNumbers(wan.traitData.Bloodtalons.entryid, { 2 })

        bStrikefortheHeart = wan.traitData.StrikefortheHeart.known
        nStrikefortheHeart = wan.GetTraitDescriptionNumbers(wan.traitData.StrikefortheHeart.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameShred, CheckAbilityValue, abilityActive)
    end
end)