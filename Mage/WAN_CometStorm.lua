local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nCometStormDmg = 0

-- Init trait data
local nMasteryIgnite = 0
local nOverflowingEnergy = 0
local nShatterMultiplier, nShatter, sFrozenDebuffs = 0, 0, {}
local nIsothermicCoreMeteor, nIsothermicCoreCometStorm, nMeteorDmg, nMeteorDotDmg = 0, 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.CometStorm.id)
    then
        wan.UpdateAbilityData(wan.spellData.CometStorm.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.CometStorm.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.CometStorm.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cCometStormInstantDmg = 0
    local cCometStormDotDmg = 0
    local cCometStormInstantDmgAoE = 0
    local cCometStormDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    ---- FROST TRAITS ----

    if wan.traitData.Shatter.known then
        for nameplateUnitToken, _ in pairs(idValidUnit) do

            for _, debuff in pairs(sFrozenDebuffs) do
                local checkID = debuff == wan.traitData.FreezingCold.traitkey and 386770 or nil
                local checkFrozenDebuff = wan.CheckUnitDebuff(nameplateUnitToken, debuff, checkID)
                if checkFrozenDebuff then
                    critChanceMod = critChanceMod + ((wan.CritChance * nShatterMultiplier) + nShatter)
                    break
                end
            end
        end
        critChanceMod = critChanceMod / countValidUnit
    end

    ---- FROSTFIRE TRAITS ----

    local cIsothermicCoreInstantDmgAoE = 0
    local cIsothermicCoreDotDmgAoE = 0
    if wan.traitData.IsothermicCore.known then
        cIsothermicCoreInstantDmgAoE = cIsothermicCoreInstantDmgAoE + (nMeteorDmg * nIsothermicCoreMeteor * countValidUnit)

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local dotPotency = wan.CheckDotPotency(nil, nameplateUnitToken)
    
            cIsothermicCoreDotDmgAoE = cIsothermicCoreDotDmgAoE + (nMeteorDotDmg * nIsothermicCoreMeteor * dotPotency)
        end
    end

    local cCometStormCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cCometStormInstantDmg = cCometStormInstantDmg

    cCometStormDotDmg = cCometStormDotDmg

    cCometStormInstantDmgAoE = cCometStormInstantDmgAoE
        + (nCometStormDmg * countValidUnit * cCometStormCritValue)
        + (cIsothermicCoreInstantDmgAoE * cCometStormCritValue)

    cCometStormDotDmgAoE = cCometStormDotDmgAoE
        + (cIsothermicCoreDotDmgAoE * cCometStormCritValue)

    local cCometStormDmg = cCometStormInstantDmg + cCometStormDotDmg + cCometStormInstantDmgAoE + cCometStormDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cCometStormDmg)
    wan.UpdateAbilityData(wan.spellData.CometStorm.basename, abilityValue, wan.spellData.CometStorm.icon, wan.spellData.CometStorm.name)
end

-- Init frame 
local frameCometStorm = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nCometStormDmg = wan.GetSpellDescriptionNumbers(wan.spellData.CometStorm.id, { 2 })

            local nMeteorValues = wan.GetSpellDescriptionNumbers(wan.spellData.Meteor.id, { 2, 4 })
            nMeteorDmg = nMeteorValues[1]
            nMeteorDotDmg = nMeteorValues[2]
        end
    end)
end
frameCometStorm:RegisterEvent("ADDON_LOADED")
frameCometStorm:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.CometStorm.known and wan.spellData.CometStorm.id
        wan.BlizzardEventHandler(frameCometStorm, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameCometStorm, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        sFrozenDebuffs = {
            "WintersChill",
            wan.traitData.Frostbite.traitkey,
            wan.traitData.IceLance.traitkey,
            wan.spellData.FrostNova.formattedName,
            wan.traitData.FreezingCold.traitkey,
            wan.traitData.IceNova.traitkey,
            "Freeze"
        }

        local nShatterValues = wan.GetTraitDescriptionNumbers(wan.traitData.Shatter.entryid, { 1, 2 })
        nShatterMultiplier = nShatterValues[1]
        nShatter = nShatterValues[2]

        local nIsothermicCoreValues = wan.GetTraitDescriptionNumbers(wan.traitData.IsothermicCore.entryid, { 1, 2 })
        nIsothermicCoreMeteor = nIsothermicCoreValues[1] * 0.01
        nIsothermicCoreCometStorm = nIsothermicCoreValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameCometStorm, CheckAbilityValue, abilityActive)
    end
end)