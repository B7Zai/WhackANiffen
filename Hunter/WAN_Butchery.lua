local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nButcheryDmg, nButcherySoftCap = 0, 0

-- Init trait data
local nMercilessBlow = 0
local nSymphonicArsenal, nSymphonicArsenalUnitCap = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Butchery.id)
    then
        wan.UpdateAbilityData(wan.spellData.Butchery.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Butchery.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Butchery.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cButcheryInstantDmg = 0
    local cButcheryDotDmg = 0
    local cButcheryInstantDmgAoE = 0
    local cButcheryDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cButcheryUnitOverflow = wan.SoftCapOverflow(nButcherySoftCap, countValidUnit)
    local cButcheryInstantDmgBaseAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

        cButcheryInstantDmgBaseAoE = cButcheryInstantDmgBaseAoE + (nButcheryDmg * checkPhysicalDR * cButcheryUnitOverflow)
    end

    ---- SURVIVAL TRAITS ----

    local cMercilessBlowDotDmgAoE = 0
    if wan.traitData.MercilessBlow.known then
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkMercilessBlowDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.traitData.MercilessBlow.traitkey)

            if not checkMercilessBlowDebuff then
                local dotPotency = wan.CheckDotPotency(nButcheryDmg, nameplateUnitToken)
                cMercilessBlowDotDmgAoE = cMercilessBlowDotDmgAoE + (nMercilessBlow * dotPotency)
            end
        end
    end

    ---- SENTINEL TRAITS ----

    local cSymphonicArsenalInstantDmgAoE = 0
    if wan.traitData.SymphonicArsenal.known then
        local cSymphonicArsenalUnitCap = math.min(countValidUnit, nSymphonicArsenalUnitCap)

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkSentinelDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.traitData.Sentinel.traitkey)

            if checkSentinelDebuff then
                cSymphonicArsenalInstantDmgAoE = cSymphonicArsenalInstantDmgAoE + (nSymphonicArsenal * cSymphonicArsenalUnitCap)
            end
        end
    end

    local cButcheryCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cButcheryInstantDmg = cButcheryInstantDmg

    cButcheryDotDmg = cButcheryDotDmg

    cButcheryInstantDmgAoE = cButcheryInstantDmgAoE
        + (cButcheryInstantDmgBaseAoE * cButcheryCritValue)
        + (cSymphonicArsenalInstantDmgAoE * cButcheryCritValue)

    cButcheryDotDmgAoE = cButcheryDotDmgAoE
        + (cMercilessBlowDotDmgAoE * cButcheryCritValue)

    local cButcheryDmg = cButcheryInstantDmg + cButcheryDotDmg + cButcheryInstantDmgAoE + cButcheryDotDmgAoE

    local abilityValue = math.floor(cButcheryDmg)
    wan.UpdateAbilityData(wan.spellData.Butchery.basename, abilityValue, wan.spellData.Butchery.icon, wan.spellData.Butchery.name)
end

-- Init frame 
local frameButchery = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nButcheryValues = wan.GetSpellDescriptionNumbers(wan.spellData.Butchery.id, { 2, 3 })
            nButcheryDmg = nButcheryValues[1]
            nButcherySoftCap = nButcheryValues[2]

            nMercilessBlow = wan.GetTraitDescriptionNumbers(wan.traitData.MercilessBlow.entryid, { 1 })

            local nSymphonicArsenalValues = wan.GetTraitDescriptionNumbers(wan.traitData.SymphonicArsenal.entryid, { 1, 2 })
            nSymphonicArsenal = nSymphonicArsenalValues[1]
            nSymphonicArsenalUnitCap = nSymphonicArsenalValues[2]
        end
    end)
end
frameButchery:RegisterEvent("ADDON_LOADED")
frameButchery:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Butchery.known and wan.spellData.Butchery.id
        wan.BlizzardEventHandler(frameButchery, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameButchery, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameButchery, CheckAbilityValue, abilityActive)
    end
end)