local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nOdynsFuryDmg, nOdynsFuryDotDmg, nOdynsFuryMaxRange, nOdynsFurySoftCap = 0, 0, 0, 0

-- Init trait data
local nOverwhelmingBlades = 0
local nImprovedWhirlwindUnitCap, nImprovedWhirlwind, nWhirlwindMaxRange = 0, 0, 0
local nRecklessnessCritChance = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.OdynsFury.id) then
        wan.UpdateAbilityData(wan.spellData.OdynsFury.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nOdynsFuryMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.OdynsFury.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    --local critChanceModBase = 0
    --local critDamageModBase = 0

    local cOdynsFuryInstantDmg = 0
    local cOdynsFuryDotDmg = 0
    local cOdynsFuryInstantDmgAoE = 0
    local cOdynsFuryDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cOdynsFuryInstantDmgBaseAoE = 0
    local cOdynsFuryDotDmgBaseAoE = 0
    local cOdynsFuryUnitOverflow = wan.SoftCapOverflow(nOdynsFurySoftCap, countValidUnit)
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

        cOdynsFuryInstantDmgBaseAoE = cOdynsFuryInstantDmgBaseAoE + (nOdynsFuryDmg * cOdynsFuryUnitOverflow * checkUnitPhysicalDR)

        local checkOdynsFuryDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.spellData.OdynsFury.formattedName)
        if not checkOdynsFuryDebuff then
            local checkDotPotency = wan.CheckDotPotency(nOdynsFuryDmg)
            cOdynsFuryDotDmgBaseAoE = cOdynsFuryDotDmgBaseAoE + (nOdynsFuryDotDmg * checkDotPotency)
        end
    end

    ---- WARRIOR TRAITS ----

    if wan.traitData.BerserkersTorment.known or wan.traitData.WarlordsTorment.known or wan.traitData.Recklessness.known then
        local checkRecklessnessBuff = wan.CheckUnitBuff(nil, wan.spellData.Recklessness.formattedName)
        if checkRecklessnessBuff then
            critChanceMod = critChanceMod + nRecklessnessCritChance
        end
    end

    ---- FURY TRAITS ----

    local cImprovedWhirlwindInstantDmgAoE = 0
    local checkImprovedWhirlwindBuff = nil
    local countImprovedWhirlwindUnit = 0
    if wan.traitData.TitanicRage.known then
        checkImprovedWhirlwindBuff = wan.CheckUnitBuff(nil, "Whirlwind")

        if not checkImprovedWhirlwindBuff then

            for _, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    cImprovedWhirlwindInstantDmgAoE = cImprovedWhirlwindInstantDmgAoE + (nOdynsFuryDmg + nOdynsFuryDotDmg)

                    countImprovedWhirlwindUnit = countImprovedWhirlwindUnit + 1

                    if countImprovedWhirlwindUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    ---- SLAYER TRAITS ----

    local cOverwhelmingBlades = 1
    if wan.traitData.OverwhelmingBlades.known or wan.traitData.UnrelentingOnslaught.known then
        local formattedDebuffName = "Overwhelmed"

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkOverwhelmingBladesDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

            if checkOverwhelmingBladesDebuff then
                local cUnitOverwhelmingBladesStacks = checkOverwhelmingBladesDebuff.applications
                cOverwhelmingBlades = cOverwhelmingBlades + ((nOverwhelmingBlades * cUnitOverwhelmingBladesStacks) / countValidUnit)
            end
        end
    end

    local cOdynsFuryCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    --local cOdynsFuryCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cOdynsFuryInstantDmg = cOdynsFuryInstantDmg

    cOdynsFuryDotDmg = cOdynsFuryDotDmg

    cOdynsFuryInstantDmgAoE = cOdynsFuryInstantDmgAoE
        + (cOdynsFuryInstantDmgBaseAoE * cOdynsFuryCritValue * cOverwhelmingBlades)
        + (cImprovedWhirlwindInstantDmgAoE * cOdynsFuryCritValue * cOverwhelmingBlades)

    cOdynsFuryDotDmgAoE = cOdynsFuryDotDmgAoE
        + (cOdynsFuryDotDmgBaseAoE * cOdynsFuryCritValue * cOverwhelmingBlades)

    local cOdynsFuryDmg = cOdynsFuryInstantDmg + cOdynsFuryDotDmg + cOdynsFuryInstantDmgAoE + cOdynsFuryDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cOdynsFuryDmg)
    wan.UpdateAbilityData(wan.spellData.OdynsFury.basename, abilityValue, wan.spellData.OdynsFury.icon, wan.spellData.OdynsFury.name)
end

-- Init frame 
local frameOdynsFury = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nOdynsFuryValues = wan.GetSpellDescriptionNumbers(wan.spellData.OdynsFury.id, { 1, 2, 4, 5 })
            nOdynsFuryDmg = nOdynsFuryValues[1]
            nOdynsFuryDotDmg = nOdynsFuryValues[2]
            nOdynsFuryMaxRange = nOdynsFuryValues[3]
            nOdynsFurySoftCap = nOdynsFuryValues[4]
        end
    end)
end
frameOdynsFury:RegisterEvent("ADDON_LOADED")
frameOdynsFury:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.OdynsFury.known and wan.spellData.OdynsFury.id
        wan.BlizzardEventHandler(frameOdynsFury, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameOdynsFury, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        local nImprovedWhirlwindValues = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedWhirlwind.entryid, { 2, 3 })
        nImprovedWhirlwindUnitCap = nImprovedWhirlwindValues[1]
        nImprovedWhirlwind = nImprovedWhirlwindValues[2] * 0.01
        nWhirlwindMaxRange = wan.traitData.ImprovedWhirlwind.known and 11 or 0

        nOverwhelmingBlades = wan.GetTraitDescriptionNumbers(wan.traitData.OverwhelmingBlades.entryid, { 1 }) * 0.01

        nRecklessnessCritChance = wan.GetSpellDescriptionNumbers(wan.spellData.Recklessness.id, { 2 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameOdynsFury, CheckAbilityValue, abilityActive)
    end
end)