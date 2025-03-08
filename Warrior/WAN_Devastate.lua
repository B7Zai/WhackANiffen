local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nDevastateDmg = 0

-- Init trait data
local nDeepWoundsDotDmg = 0
local nMartialExpertCritDamage = 0
local nDominanceoftheColossus = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Devastate.id) then
        wan.UpdateAbilityData(wan.spellData.Devastate.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Devastate.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Devastate.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cDevastateInstantDmg = 0
    local cDevastateDotDmg = 0
    local cDevastateInstantDmgAoE = 0
    local cDevastateDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- PROTECTION TRAITS ----

    local cDeepWoundsDotDmg = 0
    if wan.spellData.DeepWounds.known then
        local checkMasteryDeepWoundsDebuff = wan.CheckUnitDebuff(nil, "DeepWounds")
        if not checkMasteryDeepWoundsDebuff then
            local checkDotPotency = wan.CheckDotPotency(nDevastateDmg)

            cDeepWoundsDotDmg = cDeepWoundsDotDmg + (nDeepWoundsDotDmg * checkDotPotency)
        end
    end

    ---- COLOSSUS TRAITS ----

    if wan.traitData.MartialExpert.known then
        critDamageMod = critDamageMod + nMartialExpertCritDamage
    end

    local cDominanceoftheColossus = 1
    if wan.traitData.DominanceoftheColossus.known then
        local checkWreckedDebuff = wan.CheckUnitDebuff(nil, "Wrecked")

        if checkWreckedDebuff then
            local cWreckedStacks = checkWreckedDebuff.applications
            cDominanceoftheColossus = cDominanceoftheColossus + (nDominanceoftheColossus * cWreckedStacks)
        end
    end


    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cDevastateCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cDevastateCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cDevastateInstantDmg = cDevastateInstantDmg
        + (nDevastateDmg * checkPhysicalDR * cDevastateCritValue * cDominanceoftheColossus)

    cDevastateDotDmg = cDevastateDotDmg
        + (cDeepWoundsDotDmg * cDevastateCritValueBase * cDominanceoftheColossus)

    cDevastateInstantDmgAoE = cDevastateInstantDmgAoE

    cDevastateDotDmgAoE = cDevastateDotDmgAoE

    local cDevastateDmg = cDevastateInstantDmg + cDevastateDotDmg + cDevastateInstantDmgAoE + cDevastateDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cDevastateDmg)
    wan.UpdateAbilityData(wan.spellData.Devastate.basename, abilityValue, wan.spellData.Devastate.icon, wan.spellData.Devastate.name)
end

-- Init frame 
local frameDevastate = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nDevastateDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Devastate.id, { 1 })

            nDeepWoundsDotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.DeepWounds.id, { 1 })
        end
    end)
end
frameDevastate:RegisterEvent("ADDON_LOADED")
frameDevastate:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Devastate.known and wan.spellData.Devastate.id
        wan.BlizzardEventHandler(frameDevastate, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameDevastate, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nMartialExpertCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.MartialExpert.entryid, { 1 })

        nDominanceoftheColossus = wan.GetTraitDescriptionNumbers(wan.traitData.DominanceoftheColossus.entryid, { 3 }) * 0.001
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDevastate, CheckAbilityValue, abilityActive)
    end
end)