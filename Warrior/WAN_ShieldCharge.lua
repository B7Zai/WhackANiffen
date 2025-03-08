local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nShieldChargeDmg, nShieldChargeDmgAoE = 0, 0

-- Init trait data
local nMartialExpertCritDamage = 0
local nDominanceoftheColossus = 0
local nBatteringRamCritValues = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ShieldCharge.id) then
        wan.UpdateAbilityData(wan.spellData.ShieldCharge.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.ShieldCharge.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ShieldCharge.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    --local critChanceModBase = 0
    --local critDamageModBase = 0

    local cShieldChargeInstantDmg = 0
    local cShieldChargeDotDmg = 0
    local cShieldChargeInstantDmgAoE = 0
    local cShieldChargeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]


    local cShieldChargeInstantDmgBaseAoE = 0
    for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

        if nameplateGUID ~= targetGUID then
            local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

            cShieldChargeInstantDmgBaseAoE = cShieldChargeInstantDmgBaseAoE + (nShieldChargeDmgAoE * checkUnitPhysicalDR)
        end
    end

    ---- PROTECTION TRAITS ----

    if wan.traitData.BatteringRam.known then
        critChanceMod = critChanceMod + nBatteringRamCritValues
        critDamageMod = critDamageMod + nBatteringRamCritValues
    end

    ---- COLOSSUS TRAITS ----

    if wan.traitData.MartialExpert.known then
        critDamageMod = critDamageMod + nMartialExpertCritDamage
    end

    local cDominanceoftheColossus = 1
    local cDominanceoftheColossusAoE = 1
    if wan.traitData.DominanceoftheColossus.known then
        local checkWreckedDebuff = wan.CheckUnitDebuff(nil, "Wrecked")

        if checkWreckedDebuff then
            local cWreckedStacks = checkWreckedDebuff.applications
            cDominanceoftheColossus = cDominanceoftheColossus + (nDominanceoftheColossus * cWreckedStacks)
        end

        local cDominanceoftheColossusUnit = math.max(countValidUnit - 1, 0)
        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkUnitWreckedDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "Wrecked")

                if checkUnitWreckedDebuff then
                    local cUnitWreckedStacks = checkUnitWreckedDebuff.applications

                    cDominanceoftheColossusAoE = cDominanceoftheColossusAoE + ((nDominanceoftheColossus * cUnitWreckedStacks) / cDominanceoftheColossusUnit)
                end
            end
        end
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cShieldChargeCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    --local cShieldChargeCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cShieldChargeInstantDmg = cShieldChargeInstantDmg
        + (nShieldChargeDmg * checkPhysicalDR * cShieldChargeCritValue * cDominanceoftheColossus)

    cShieldChargeDotDmg = cShieldChargeDotDmg

    cShieldChargeInstantDmgAoE = cShieldChargeInstantDmgAoE
        + (cShieldChargeInstantDmgBaseAoE * cShieldChargeCritValue * cDominanceoftheColossusAoE)

    cShieldChargeDotDmgAoE = cShieldChargeDotDmgAoE

    local cShieldChargeDmg = cShieldChargeInstantDmg + cShieldChargeDotDmg + cShieldChargeInstantDmgAoE + cShieldChargeDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cShieldChargeDmg)
    wan.UpdateAbilityData(wan.spellData.ShieldCharge.basename, abilityValue, wan.spellData.ShieldCharge.icon, wan.spellData.ShieldCharge.name)
end

-- Init frame 
local frameShieldCharge = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nShieldChargeValues = wan.GetSpellDescriptionNumbers(wan.spellData.ShieldCharge.id, { 1, 2 })
            nShieldChargeDmg = nShieldChargeValues[1]
            nShieldChargeDmgAoE = nShieldChargeValues[2]
        end
    end)
end
frameShieldCharge:RegisterEvent("ADDON_LOADED")
frameShieldCharge:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ShieldCharge.known and wan.spellData.ShieldCharge.id
        wan.BlizzardEventHandler(frameShieldCharge, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameShieldCharge, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nMartialExpertCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.MartialExpert.entryid, { 1 })

        nDominanceoftheColossus = wan.GetTraitDescriptionNumbers(wan.traitData.DominanceoftheColossus.entryid, { 3 }) * 0.001

        nBatteringRamCritValues = wan.GetTraitDescriptionNumbers(wan.traitData.BatteringRam.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameShieldCharge, CheckAbilityValue, abilityActive)
    end
end)