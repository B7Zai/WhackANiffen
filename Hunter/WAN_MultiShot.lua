local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nMultiShotDmg, nMultiShotSoftCap = 0, 0

-- Init trait data
local nExplosiveVenomInstantDmg, nExplosiveVenomDotDmg, nExplosiveVenomStacks = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.MultiShot.id)
    then
        wan.UpdateAbilityData(wan.spellData.MultiShot.basename)
        wan.UpdateMechanicData(wan.spellData.MultiShot.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.MultiShot.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.MultiShot.basename)
        wan.UpdateMechanicData(wan.spellData.MultiShot.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cMultiShotInstantDmg = 0
    local cMultiShotDotDmg = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local checkExplosiveVenom = false
    if wan.traitData.ExplosiveVenom.known then
        local checkExplosiveVenomBuff = wan.auraData.player["buff_" .. wan.traitData.ExplosiveVenom.traitkey]
        if checkExplosiveVenomBuff and checkExplosiveVenomBuff.applications == (nExplosiveVenomStacks - 1) then
            checkExplosiveVenom = true
        end
    end

    local cMultiShotInstantAoEDmg = 0
    local cMultiShotDotDmgAoE = 0
    local cMultiShotUnitOverflow = wan.SoftCapOverflow(nMultiShotSoftCap, countValidUnit)
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

        local cExplosiveVenomInstantDmg = 0
        local cExplosiveVenomDotDmg = 0
        if checkExplosiveVenom then
            cExplosiveVenomInstantDmg = cExplosiveVenomInstantDmg + nExplosiveVenomInstantDmg
            local checkSerpentStingDebuff = wan.auraData[nameplateUnitToken].debuff_SerpentSting
            if not checkSerpentStingDebuff then
                local dotPotency = wan.CheckDotPotency(nExplosiveVenomInstantDmg, nameplateUnitToken)
                cExplosiveVenomDotDmg = cExplosiveVenomDotDmg + (nExplosiveVenomDotDmg * dotPotency)
            end
        end

        cMultiShotInstantAoEDmg = cMultiShotInstantAoEDmg + ((nMultiShotDmg * checkPhysicalDR * cMultiShotUnitOverflow) + cExplosiveVenomInstantDmg)
        cMultiShotDotDmgAoE = cMultiShotDotDmgAoE + cExplosiveVenomDotDmg
    end

    -- Crit layer
    local cMultiShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cMultiShotInstantDmg = cMultiShotInstantDmg
    cMultiShotDotDmg = cMultiShotDotDmg
    cMultiShotInstantAoEDmg = cMultiShotInstantAoEDmg * cMultiShotCritValue
    cMultiShotDotDmgAoE = cMultiShotDotDmgAoE * cMultiShotCritValue

    local cMultiShotDmg = cMultiShotInstantDmg + cMultiShotDotDmg + cMultiShotInstantAoEDmg + cMultiShotDotDmgAoE

    local mechanicPrio = false
    if wan.traitData.BeastCleave.known and countValidUnit > 2 then
        local checkBeastCleaveBuff = wan.auraData.player.buff_BeastCleave
        if not checkBeastCleaveBuff then
            mechanicPrio = true
        else
            local expirationTime = checkBeastCleaveBuff.expirationTime - GetTime()

            if expirationTime < 2 then
                mechanicPrio = true
            end
        end
    end

    local abilityValue = not mechanicPrio and math.floor(cMultiShotDmg) or 0
    local mechanicValue = mechanicPrio and math.floor(cMultiShotDmg) or 0
    wan.UpdateAbilityData(wan.spellData.MultiShot.basename, abilityValue, wan.spellData.MultiShot.icon, wan.spellData.MultiShot.name)
    wan.UpdateMechanicData(wan.spellData.MultiShot.basename, mechanicValue, wan.spellData.MultiShot.icon, wan.spellData.MultiShot.name)
end

-- Init frame 
local frameMultiShot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nMultiShotValues = wan.GetSpellDescriptionNumbers(wan.spellData.MultiShot.id, { 2, 3 })
            nMultiShotDmg = nMultiShotValues[1]
            nMultiShotSoftCap = nMultiShotValues[2]

            local nExplosiveVenomValues = wan.GetTraitDescriptionNumbers(wan.traitData.VenomsBite.entryid, { 4, 5 })
            nExplosiveVenomInstantDmg = nExplosiveVenomValues[1]
            nExplosiveVenomDotDmg = nExplosiveVenomValues[2]
        end
    end)
end
frameMultiShot:RegisterEvent("ADDON_LOADED")
frameMultiShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.MultiShot.known and wan.spellData.MultiShot.id
        wan.BlizzardEventHandler(frameMultiShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameMultiShot, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nExplosiveVenomStacks = wan.GetTraitDescriptionNumbers(wan.traitData.ExplosiveVenom.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMultiShot, CheckAbilityValue, abilityActive)
    end
end)