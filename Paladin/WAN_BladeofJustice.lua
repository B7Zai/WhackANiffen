local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init spell data
local abilityActive = false
local nBladeofJusticeDmg = 0

-- Init trait data
local nExpurgation = 0
local nBladeofVengeance, nBladeofVengeanceSoftCap = 0, 0


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.BladeofJustice.id)
    then
        wan.UpdateAbilityData(wan.spellData.BladeofJustice.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.BladeofJustice.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.BladeofJustice.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cBladeofJusticeInstantDmg = nBladeofJusticeDmg
    local cBladeofJusticeDotDmg = 0
    local cBladeofJusticeInstantDmgAoE = 0
    local cBladeofJusticeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- RETRIBUTION TRAITS ----

    local cExpurgationDotDmg = 0
    local cExpurgationDotDmgAoE = 0
    if wan.traitData.Expurgation.known then
        local formattedDebuffName = wan.traitData.Expurgation.traitkey
        local checkExpurgationDebuff = wan.CheckUnitDebuff(targetUnitToken, formattedDebuffName)

        if not checkExpurgationDebuff then
            local dotPotency = wan.CheckDotPotency()
            cExpurgationDotDmg = cExpurgationDotDmg + (nExpurgation * dotPotency)
        end

        if wan.traitData.BladeofVengeance.known then

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkExpurgationUnitDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

                    if not checkExpurgationUnitDebuff then
                        local unitDotPotency = wan.CheckDotPotency(nBladeofVengeance, nameplateUnitToken)

                        cExpurgationDotDmgAoE = cExpurgationDotDmgAoE + (nExpurgation * unitDotPotency)
                    end
                end
            end
        end
    end

    local nBladeofVengeanceInstantDmgAoE = 0
    if wan.traitData.BladeofVengeance.known then
        local nBladeofVengeanceUnitOverflow = wan.SoftCapOverflow(nBladeofVengeanceSoftCap, countValidUnit)

        for _, nameplateGUID in pairs(idValidUnit) do
    
            if nameplateGUID ~= targetGUID then
                nBladeofVengeanceInstantDmgAoE = nBladeofVengeanceInstantDmgAoE + (nBladeofVengeance * nBladeofVengeanceUnitOverflow)
            end
        end
    end

    local cBladeofJusticeCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cBladeofJusticeInstantDmg = cBladeofJusticeInstantDmg * cBladeofJusticeCritValue
    cBladeofJusticeDotDmg = cBladeofJusticeDotDmg + (cExpurgationDotDmg * cBladeofJusticeCritValue)
    cBladeofJusticeInstantDmgAoE = cBladeofJusticeInstantDmgAoE + (nBladeofVengeanceInstantDmgAoE * cBladeofJusticeCritValue)
    cBladeofJusticeDotDmgAoE = cBladeofJusticeDotDmgAoE + (cExpurgationDotDmgAoE * cBladeofJusticeCritValue)

    local cBladeofJusticeDmg = cBladeofJusticeInstantDmg + cBladeofJusticeDotDmg + cBladeofJusticeInstantDmgAoE + cBladeofJusticeDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cBladeofJusticeDmg)
    wan.UpdateAbilityData(wan.spellData.BladeofJustice.basename, abilityValue, wan.spellData.BladeofJustice.icon, wan.spellData.BladeofJustice.name)
end

-- Init frame 
local frameBladeofJustice = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBladeofJusticeDmg = wan.GetSpellDescriptionNumbers(wan.spellData.BladeofJustice.id, { 1 })

            nExpurgation = wan.GetTraitDescriptionNumbers(wan.traitData.Expurgation.entryid, { 1 })
        end
    end)
end
frameBladeofJustice:RegisterEvent("ADDON_LOADED")
frameBladeofJustice:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BladeofJustice.known and wan.spellData.BladeofJustice.id
        wan.BlizzardEventHandler(frameBladeofJustice, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBladeofJustice, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        local nBladeofVengeanceDmgValues = wan.GetTraitDescriptionNumbers(wan.traitData.BladeofVengeance.entryid, { 1, 2 })
        nBladeofVengeance = nBladeofVengeanceDmgValues[1]
        nBladeofVengeanceSoftCap = nBladeofVengeanceDmgValues[2]
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBladeofJustice, CheckAbilityValue, abilityActive)
    end
end)