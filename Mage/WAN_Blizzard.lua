local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nBlizzardDmg = 0

-- Init trait data
local nOverflowingEnergy = 0
local nShatterMultiplier, nShatter, sFrozenDebuffs = 0, 0, {}

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Blizzard.id)
    then
        wan.UpdateAbilityData(wan.spellData.Blizzard.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Blizzard.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Blizzard.basename)
        return
    end

    local canMovecast = wan.auraData.player.buff_IceFloes and true or false
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Blizzard.id, wan.spellData.Blizzard.castTime, canMovecast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.Blizzard.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cBlizzardInstantDmg = 0
    local cBlizzardDotDmg = 0
    local cBlizzardInstantDmgAoE = 0
    local cBlizzardDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cBlizzardBaseDmgAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local unitAoEPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        cBlizzardBaseDmgAoE = cBlizzardBaseDmgAoE + (nBlizzardDmg * unitAoEPotency)
    end

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

    local cBlizzardCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cBlizzardInstantDmg = cBlizzardInstantDmg

    cBlizzardDotDmg = cBlizzardDotDmg

    cBlizzardInstantDmgAoE = cBlizzardInstantDmgAoE
        + (cBlizzardBaseDmgAoE * cBlizzardCritValue)

    cBlizzardDotDmgAoE = cBlizzardDotDmgAoE
    
    local cBlizzardDmg = (cBlizzardInstantDmg + cBlizzardDotDmg + cBlizzardInstantDmgAoE + cBlizzardDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cBlizzardDmg)
    wan.UpdateAbilityData(wan.spellData.Blizzard.basename, abilityValue, wan.spellData.Blizzard.icon, wan.spellData.Blizzard.name)
end

-- Init frame 
local frameBlizzard = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBlizzardDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Blizzard.id, { 1 })
        end
    end)
end
frameBlizzard:RegisterEvent("ADDON_LOADED")
frameBlizzard:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Blizzard.known and wan.spellData.Blizzard.id
        wan.BlizzardEventHandler(frameBlizzard, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBlizzard, CheckAbilityValue, abilityActive)
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
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBlizzard, CheckAbilityValue, abilityActive)
    end
end)