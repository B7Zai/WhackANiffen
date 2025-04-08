local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local abilityActive = false
local checkDebuffs = {"Rake", "Thrash", "Rip", "FeralFrenzy", "Tear", "FrenziedAssault"}
local nShredDmg, nThrashDotDmg = 0, 0
local nShredMaxRange = 0
local sCatForm = "CatForm"

-- Init trait data
local nPouncingStrikes = 0
local nMercilessClaws, nThrashingClaws = 0, 0
local nStrikeForTheHeart = 0

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

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cShredInstantDmg = nShredDmg
    local cShredDotDmg = 0

    local targetUnitToken = wan.TargetUnitID

    -- Remove physical layer
    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()

    -- Pouncing Strikes
    local cPouncingStrikes = 1
    if wan.auraData.player.buff_SuddenAmbush or ((wan.traitData.PouncingStrikes.known or wan.PlayerState.SpecializationName ~= "Feral") and wan.auraData.player.buff_Prowl) then 
        critChanceMod = critChanceMod + wan.CritChance
        cPouncingStrikes = cPouncingStrikes + nPouncingStrikes
    end

    -- Merciless Claws
    local cMercilessClaws = 1
    if wan.traitData.MercilessClaws.known and wan.CheckForAnyDebuff(targetUnitToken, checkDebuffs) then
        cMercilessClaws = cMercilessClaws * nMercilessClaws
    end

    --Thrashing Claws
    local cThrashingClaws = 1
    local cThrashingClawsDot = 0
    if wan.traitData.ThrashingClaws.known then                                    
        local bThrashingDebuffs = wan.CheckForAnyDebuff(targetUnitToken, checkDebuffs)

        if bThrashingDebuffs then
            cThrashingClaws = 1 + nThrashingClaws
        end

        local checkThrashDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.spellData.Thrash.basename]
        if not checkThrashDebuff then
            local dotPotency = wan.CheckDotPotency(nShredDmg)
            cThrashingClawsDot = nThrashDotDmg * dotPotency
        end
    end

    -- Strike for the Heart
    if wan.traitData.StrikefortheHeart.known then
        critChanceMod = critChanceMod + nStrikeForTheHeart
        critDamageMod = critDamageMod + nStrikeForTheHeart
    end

    cShredInstantDmg = cShredInstantDmg * checkPhysicalDR * cPouncingStrikes * cMercilessClaws * cThrashingClaws
    cShredDotDmg = cShredDotDmg + cThrashingClawsDot

    -- Crit layer
    cShredInstantDmg = cShredInstantDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    cShredDotDmg = cShredDotDmg * wan.ValueFromCritical(wan.CritChance)

    local cShredDmg = cShredInstantDmg + cShredDotDmg

    -- Update ability data
    local abilityValue = math.floor(cShredDmg)
    wan.UpdateAbilityData(wan.spellData.Shred.basename, abilityValue, wan.spellData.Shred.icon, wan.spellData.Shred.name)
end

-- Init frame 
local frameShred = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nShredDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Shred.id, { 1 })

            nThrashDotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Thrash.id, { 2 })
        end
    end)
end
frameShred:RegisterEvent("ADDON_LOADED")
frameShred:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Shred.known and wan.spellData.Shred.id
        wan.BlizzardEventHandler(frameShred, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameShred, CheckAbilityValue, abilityActive)

        nShredMaxRange = not wan.spellData.Swipe.known and 8 or wan.spellData.Swipe.maxRange

        sCatForm = wan.spellData.CatForm.formattedName
    end

    if event == "TRAIT_DATA_READY" then
        nPouncingStrikes = wan.GetTraitDescriptionNumbers(wan.traitData.PouncingStrikes.entryid, { 3 }) / 100
        nMercilessClaws = wan.GetTraitDescriptionNumbers(wan.traitData.MercilessClaws.entryid, { 1 }) / 100
        nThrashingClaws = wan.GetTraitDescriptionNumbers(wan.traitData.ThrashingClaws.entryid, { 1 }) / 100
        nStrikeForTheHeart = wan.GetTraitDescriptionNumbers(wan.traitData.StrikefortheHeart.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameShred, CheckAbilityValue, abilityActive)
    end
end)