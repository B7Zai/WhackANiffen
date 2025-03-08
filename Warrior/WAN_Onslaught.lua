local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nOnslaughtDmg = 0

-- Init trait data
local nOverwhelmingBlades = 0
local nImprovedWhirlwindUnitCap, nImprovedWhirlwind, nWhirlwindMaxRange = 0, 0, 0
local nRecklessnessCritChance = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Onslaught.id) then
        wan.UpdateAbilityData(wan.spellData.Onslaught.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Onslaught.id, nWhirlwindMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Onslaught.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    --local critChanceModBase = 0
    --local critDamageModBase = 0

    local cOnslaughtInstantDmg = 0
    local cOnslaughtDotDmg = 0
    local cOnslaughtInstantDmgAoE = 0
    local cOnslaughtDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

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
    if wan.traitData.ImprovedWhirlwind.known then
        checkImprovedWhirlwindBuff = wan.CheckUnitBuff(nil, "Whirlwind")

        if checkImprovedWhirlwindBuff then
            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    cImprovedWhirlwindInstantDmgAoE = cImprovedWhirlwindInstantDmgAoE + (nOnslaughtDmg * nImprovedWhirlwind * checkUnitPhysicalDR)

                    countImprovedWhirlwindUnit = countImprovedWhirlwindUnit + 1

                    if countImprovedWhirlwindUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    ---- SLAYER TRAITS ----

    local cOverwhelmingBlades = 1
    local cOverwhelmingBladesAoE = 1
    if wan.traitData.OverwhelmingBlades.known or wan.traitData.UnrelentingOnslaught.known then
        local checkOverwhelmingBladesDebuff = wan.CheckUnitDebuff(nil, "Overwhelmed")

        if checkOverwhelmingBladesDebuff then
            local cOverwhelmingBladesStacks = checkOverwhelmingBladesDebuff.applications
            cOverwhelmingBlades = cOverwhelmingBlades + (nOverwhelmingBlades * cOverwhelmingBladesStacks)
        end


        if checkImprovedWhirlwindBuff then
            local countOverwhelmingBladesUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitOverwhelmingBladesDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "Overwhelmed")

                    if checkUnitOverwhelmingBladesDebuff then
                        local cUnitOverwhelmingBladesStacks = checkUnitOverwhelmingBladesDebuff.applications
                        cOverwhelmingBladesAoE = cOverwhelmingBladesAoE + ((nOverwhelmingBlades * cUnitOverwhelmingBladesStacks) / countImprovedWhirlwindUnit)
                    end

                    countOverwhelmingBladesUnit = countOverwhelmingBladesUnit + 1

                    if countOverwhelmingBladesUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cOnslaughtCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    --local cOnslaughtCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cOnslaughtInstantDmg = cOnslaughtInstantDmg
        + (nOnslaughtDmg * checkPhysicalDR * cOnslaughtCritValue * cOverwhelmingBlades)

    cOnslaughtDotDmg = cOnslaughtDotDmg

    cOnslaughtInstantDmgAoE = cOnslaughtInstantDmgAoE
        + (cImprovedWhirlwindInstantDmgAoE * cOnslaughtCritValue * cOverwhelmingBladesAoE)

    cOnslaughtDotDmgAoE = cOnslaughtDotDmgAoE

    local cOnslaughtDmg = cOnslaughtInstantDmg + cOnslaughtDotDmg + cOnslaughtInstantDmgAoE + cOnslaughtDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cOnslaughtDmg)
    wan.UpdateAbilityData(wan.spellData.Onslaught.basename, abilityValue, wan.spellData.Onslaught.icon, wan.spellData.Onslaught.name)
end

-- Init frame 
local frameOnslaught = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nOnslaughtDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Onslaught.id, { 1 })
        end
    end)
end
frameOnslaught:RegisterEvent("ADDON_LOADED")
frameOnslaught:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Onslaught.known and wan.spellData.Onslaught.id
        wan.BlizzardEventHandler(frameOnslaught, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameOnslaught, CheckAbilityValue, abilityActive)
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
        wan.SetUpdateRate(frameOnslaught, CheckAbilityValue, abilityActive)
    end
end)