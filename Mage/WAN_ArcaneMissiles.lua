local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nArcaneMissilesDmg, nArcaneMissilesCastTime, nArcaneMissilesDmgPerMissile = 0, 0, 0

-- Init trait data
local nOverflowingEnergy = 0
local nAmplification = 0
local nEureka = 0
local nArcaneDebilitation = 0
local nAetherAttunement, nAetherAttunementUnitCap, nAetherAttunementAoE = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ArcaneMissiles.id)
    then
        wan.UpdateAbilityData(wan.spellData.ArcaneMissiles.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.ArcaneMissiles.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ArcaneMissiles.basename)
        return
    end

    local canMovecast = ((wan.traitData.Slipstream.known or wan.auraData.player.buff_IceFloes) and true) or false
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.ArcaneMissiles.id, nArcaneMissilesCastTime, canMovecast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.ArcaneMissiles.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cArcaneMissilesInstantDmg = 0
    local cArcaneMissilesDotDmg = 0
    local cArcaneMissilesInstantDmgAoE = 0
    local cArcaneMissilesDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    ---- ARCANE TRAITS ----
    
    local nAmplificationInstantDmg = 0
    if wan.traitData.Amplification.known then
        nAmplificationInstantDmg = nAmplificationInstantDmg + (nArcaneMissilesDmgPerMissile * nAmplification)
    end

    local cEureka = 1
    if wan.traitData.Eureka.known then
        local formattedBuffName = wan.spellData.Clearcasting.formattedName
        local checkClearcastingBuff = wan.CheckUnitBuff(nil, formattedBuffName)
        if checkClearcastingBuff then
            cEureka = cEureka + nEureka
        end
    end

    local cArcaneDebilitation = 1
    local cArcaneDebilitationAoE = 1
    if wan.traitData.ArcaneDebilitation.known then
        local formattedDebuffName = wan.traitData.ArcaneDebilitation.traitkey
        local checkArcaneDebilitationDebuff = wan.CheckUnitDebuff(nil, formattedDebuffName)
        if checkArcaneDebilitationDebuff then
            local checkArcaneDebilitationStacks = checkArcaneDebilitationDebuff.applications
            cArcaneDebilitation = cArcaneDebilitation + (nArcaneDebilitation * checkArcaneDebilitationStacks)
        end

        if wan.traitData.AetherAttunement.known then
            local checkAetherAttunementBuff = wan.CheckUnitBuff(nil, wan.traitData.AetherAttunement.traitkey)

            if checkAetherAttunementBuff then

                for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                    if nameplateGUID ~= targetGUID then
                        local checkUnitArcaneDebilitationDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

                        if checkUnitArcaneDebilitationDebuff then
                            local checkUnitArcaneDebilitationStacks = checkUnitArcaneDebilitationDebuff.applications
                            cArcaneDebilitationAoE = cArcaneDebilitationAoE + (nArcaneDebilitation * checkUnitArcaneDebilitationStacks)
                        end
                    end
                end
            end
        end
    end

    local cAetherAttunement = 1
    local cAetherAttunementAoE = 1
    local cAetherAttunementInstantDmgAoE = 0
    if wan.traitData.AetherAttunement.known then
        local checkAetherAttunementBuff = wan.CheckUnitBuff(nil, wan.traitData.AetherAttunement.traitkey)

        if checkAetherAttunementBuff then
            cAetherAttunement = cAetherAttunement + nAetherAttunement
            cAetherAttunementAoE = cAetherAttunementAoE + nAetherAttunementAoE
            local countAetherAttunementUnit = 0

            for _, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    cAetherAttunementInstantDmgAoE = cAetherAttunementInstantDmgAoE + (nArcaneMissilesDmg + nAmplificationInstantDmg)
                    countAetherAttunementUnit = countAetherAttunementUnit + 1

                    if countAetherAttunementUnit >= nAetherAttunementUnitCap then break end
                end
            end
        end
    end

    local cArcaneMissilesCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cArcaneMissilesInstantDmg = cArcaneMissilesInstantDmg
        + ((nArcaneMissilesDmg + nAmplificationInstantDmg) * cEureka * cArcaneDebilitation * cAetherAttunement * cArcaneMissilesCritValue)

    cArcaneMissilesDotDmg = cArcaneMissilesDotDmg

    cArcaneMissilesInstantDmgAoE = cArcaneMissilesInstantDmgAoE
        + (cAetherAttunementInstantDmgAoE * cEureka * cArcaneDebilitationAoE * cAetherAttunementAoE * cArcaneMissilesCritValue)

    cArcaneMissilesDotDmgAoE = cArcaneMissilesDotDmgAoE
    
    local cArcaneMissilesDmg = (cArcaneMissilesInstantDmg + cArcaneMissilesDotDmg + cArcaneMissilesInstantDmgAoE + cArcaneMissilesDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cArcaneMissilesDmg)
    wan.UpdateAbilityData(wan.spellData.ArcaneMissiles.basename, abilityValue, wan.spellData.ArcaneMissiles.icon, wan.spellData.ArcaneMissiles.name)
end

-- Init frame 
local frameArcaneMissiles = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nArcaneMissilesValues = wan.GetSpellDescriptionNumbers(wan.spellData.ArcaneMissiles.id, { 1, 2 })
            nArcaneMissilesCastTime = nArcaneMissilesValues[1] * 1000
            nArcaneMissilesDmgPerMissile = nArcaneMissilesValues[2] * 0.2
            nArcaneMissilesDmg = nArcaneMissilesValues[2]
        end
    end)
end
frameArcaneMissiles:RegisterEvent("ADDON_LOADED")
frameArcaneMissiles:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ArcaneMissiles.known and wan.spellData.ArcaneMissiles.id
        wan.BlizzardEventHandler(frameArcaneMissiles, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameArcaneMissiles, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        nAmplification = wan.GetTraitDescriptionNumbers(wan.traitData.Amplification.entryid, { 1 })

        nEureka = wan.GetTraitDescriptionNumbers(wan.traitData.Eureka.entryid, { 1 }) * 0.01

        nArcaneDebilitation = wan.GetTraitDescriptionNumbers(wan.traitData.ArcaneDebilitation.entryid, { 1 }, wan.traitData.ArcaneDebilitation.rank) * 0.01

        local nAetherAttunementValues = wan.GetTraitDescriptionNumbers(wan.traitData.AetherAttunement.entryid, { 4, 5, 6 })
        nAetherAttunement = nAetherAttunementValues[1] * 0.01
        nAetherAttunementUnitCap = nAetherAttunementValues[2]
        nAetherAttunementAoE = nAetherAttunementValues[3] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArcaneMissiles, CheckAbilityValue, abilityActive)
    end
end)