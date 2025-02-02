local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init spell data
local abilityActive = false
local nAvengersShieldDmg, nAvengersShieldUnitCap = 0, 0

-- Init trait data
local nRefiningFire = 0
local nTyrsEnforcer = 0
local nSoaringShield = 0
local nFocusedEnmity = 0
local nFerrenMarcussFervor = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.AvengersShield.id)
    then
        wan.UpdateAbilityData(wan.spellData.AvengersShield.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.AvengersShield.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.AvengersShield.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cAvengersShieldInstantDmg = 0
    local cAvengersShieldDotDmg = 0
    local cAvengersShieldInstantDmgAoE = 0
    local cAvengersShieldDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cAvengersShieldUnitCap = nAvengersShieldUnitCap
    if wan.traitData.SoaringShield.entryid then
        cAvengersShieldUnitCap = cAvengersShieldUnitCap + nSoaringShield
    end

    local countAvengersShieldUnits = 0
    for _, nameplateGUID in pairs(idValidUnit) do
        if nameplateGUID ~= targetGUID then
            cAvengersShieldInstantDmgAoE = cAvengersShieldInstantDmgAoE + (nAvengersShieldDmg)
            countAvengersShieldUnits = countAvengersShieldUnits + 1

            if countAvengersShieldUnits >= cAvengersShieldUnitCap then break end
        end
    end

    ---- PROTECTION TRAITS ----

    local cRefiningFireDotDmg = 0
    local cRefiningFireDotDmgAoE = 0
    if wan.traitData.RefiningFire.known then
        local checkRefiningFireDebuff = wan.CheckUnitDebuff(targetUnitToken, wan.traitData.RefiningFire.traitkey)
        if not checkRefiningFireDebuff then
            local dotPotency = wan.CheckDotPotency(nAvengersShieldDmg, targetUnitToken)
            cRefiningFireDotDmg = cRefiningFireDotDmg + (nRefiningFire * dotPotency)
        end

        local countRefiningFireUnits = 0
        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkUnitRefiningFireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.traitData.RefiningFire.traitkey)

                if not checkUnitRefiningFireDebuff then
                    local unitDotPotency = wan.CheckDotPotency(nAvengersShieldDmg, nameplateUnitToken)
                    cRefiningFireDotDmgAoE = cRefiningFireDotDmgAoE + (nRefiningFire * unitDotPotency)
                end

                countRefiningFireUnits = countRefiningFireUnits + 1
                if countRefiningFireUnits >= cAvengersShieldUnitCap then break end
            end
        end
    end

    local cTyrsEnforcerInstantDmgAoE = 0
    if wan.traitData.TyrsEnforcer.known then
        local countTyrsEnforcerUnits = math.min(countValidUnit, cAvengersShieldUnitCap)
        cTyrsEnforcerInstantDmgAoE = cTyrsEnforcerInstantDmgAoE + (nTyrsEnforcer * countTyrsEnforcerUnits * countValidUnit)
    end

    local cFocusedEnmity = 1
    if wan.traitData.FocusedEnmity.known then
        cFocusedEnmity = cFocusedEnmity + (countValidUnit == 1 and nFocusedEnmity or 0)
    end

    local cFerrenMarcussFervor = 1
    if wan.traitData.FerrenMarcussFervor.known then
        cFerrenMarcussFervor = cFerrenMarcussFervor + nFerrenMarcussFervor
    end

    local cAvengersShieldCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cAvengersShieldInstantDmg = cAvengersShieldInstantDmg
        + (nAvengersShieldDmg * cFocusedEnmity * cFerrenMarcussFervor * cAvengersShieldCritValue)

    cAvengersShieldDotDmg = cAvengersShieldDotDmg
        + (cRefiningFireDotDmg * cAvengersShieldCritValue)

    cAvengersShieldInstantDmgAoE = cAvengersShieldInstantDmgAoE
        + (cTyrsEnforcerInstantDmgAoE * cAvengersShieldCritValue)

    cAvengersShieldDotDmgAoE = cAvengersShieldDotDmgAoE
        + (cRefiningFireDotDmgAoE * cAvengersShieldCritValue) 

    local cAvengersShieldDmg = cAvengersShieldInstantDmg + cAvengersShieldDotDmg + cAvengersShieldInstantDmgAoE + cAvengersShieldDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cAvengersShieldDmg)
    wan.UpdateAbilityData(wan.spellData.AvengersShield.basename, abilityValue, wan.spellData.AvengersShield.icon, wan.spellData.AvengersShield.name)
end

-- Init frame 
local frameAvengersShield = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nAvengersShieldValues = wan.GetSpellDescriptionNumbers(wan.spellData.AvengersShield.id, { 1, 3 })
            nAvengersShieldDmg = nAvengersShieldValues[1]
            nAvengersShieldUnitCap = nAvengersShieldValues[2]

            nRefiningFire = wan.GetTraitDescriptionNumbers(wan.traitData.RefiningFire.entryid, { 1 })

            nTyrsEnforcer = wan.GetTraitDescriptionNumbers(wan.traitData.TyrsEnforcer.entryid, { 1 }, wan.traitData.TyrsEnforcer.rank)
        end
    end)
end
frameAvengersShield:RegisterEvent("ADDON_LOADED")
frameAvengersShield:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.AvengersShield.known and wan.spellData.AvengersShield.id
        wan.BlizzardEventHandler(frameAvengersShield, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameAvengersShield, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then        
        nSoaringShield = wan.GetTraitDescriptionNumbers(wan.traitData.SoaringShield.entryid, { 1 })

        nFocusedEnmity = wan.GetTraitDescriptionNumbers(wan.traitData.FocusedEnmity.entryid, { 1 }) * 0.01

        nFerrenMarcussFervor = wan.GetTraitDescriptionNumbers(wan.traitData.FerrenMarcussFervor.entryid, { 1 }, wan.traitData.FerrenMarcussFervor.rank) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameAvengersShield, CheckAbilityValue, abilityActive)
    end
end)