local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "CLASS" then return end

-- Init spell data
local abilityActive = false
local nDmg, nDotDmg = 0, 0

-- Init trait data
local aTraitWithRanks, nTraitWithRanks = {}, 0
local nTraitWithUnitCap, nTrait


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.AbilityName.id)
    then
        wan.UpdateAbilityData(wan.spellData.AbilityName.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.AbilityName.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.AbilityName.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cInstantDmg = 0
    local cDotDmg = 0
    local cInstantDmgAoE = 0
    local cDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cDotDmgBase = 0
    local checkDebuff = wan.CheckUnitDebuff(targetUnitToken, wan.spellData.AbilityName.basename)
    if not checkDebuff then
        local dotPotency = wan.CheckDotPotency()
        cDotDmgBase = cDotDmgBase + (nDotDmg * dotPotency)
    end

    local cInstantDmgAoEBase = 0
    for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
        local countCappedAbility = 0

        if nameplateGUID ~= targetGUID then
            local checkUnitDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.spellData.AbilityName.basename)

            if not checkUnitDebuff then
                local dotUnitPotency = wan.CheckDotPotency(nDmg, nameplateUnitToken)
                local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()

                cInstantDmgAoEBase = cInstantDmgAoEBase + (nDmg * checkPhysicalDR * dotUnitPotency)
                countCappedAbility = countCappedAbility + 1

                -- if countCappedAbility >= nBlessedChampionUnitCap then break end
            end
        end
    end

    ---- TRAITS ----


    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cAbilityCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cInstantDmg = cInstantDmg
    cDotDmg = cDotDmg
    cInstantDmgAoE = cInstantDmgAoE
    cDotDmgAoE = cDotDmgAoE

    local cAbilityDmg = cInstantDmg + cDotDmg + cInstantDmgAoE + cDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cAbilityDmg)
    wan.UpdateAbilityData(wan.spellData.AbilityName.basename, abilityValue, wan.spellData.AbilityName.icon, wan.spellData.AbilityName.name)
end

-- Init frame 
local frameAbilityName = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nAbilityValues = wan.GetSpellDescriptionNumbers(wan.spellData.AbilityName.id, { 1, 2 })
            nDmg = nAbilityValues[1]
            nDotDmg = nAbilityValues[2] * 0.01
        end
    end)
end
frameAbilityName:RegisterEvent("ADDON_LOADED")
frameAbilityName:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.AbilityName.isPassive and wan.spellData.AbilityName.known and wan.spellData.AbilityName.id
        wan.BlizzardEventHandler(frameAbilityName, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameAbilityName, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 

        aTraitWithRanks = wan.traitData.TraitName
        nTraitWithRanks = wan.GetTraitDescriptionNumbers(aTraitWithRanks.entryid, { 1 }, aTraitWithRanks.rank)

        
        local nTraitValues = wan.GetTraitDescriptionNumbers(wan.traitData.TraitName.entryid, { 1, 2 })
        nTraitWithUnitCap = nTraitValues[1]
        nTrait = nTraitValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameAbilityName, CheckAbilityValue, abilityActive)
    end
end)