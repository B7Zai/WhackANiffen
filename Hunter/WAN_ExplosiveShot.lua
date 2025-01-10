local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nExplosiveShotDmg, nExplosiveShotSoftCap = 0, 0

-- Init trait data
local nPenetratingShots = 0
local nExplosiveVenomInstantDmg, nExplosiveVenomDotDmg, nExplosiveVenomStacks = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ExplosiveShot.id)
    then
        wan.UpdateAbilityData(wan.spellData.ExplosiveShot.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.ExplosiveShot.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ExplosiveShot.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cExplosiveShotInstantDmg = 0
    local cExplosiveShotDotDmg = 0
    local cExplosiveShotInstantDmgAoE = 0
    local cExplosiveShotDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cPenetratingShots = 0
    if wan.traitData.PenetratingShots.known then
        cPenetratingShots = cPenetratingShots + (wan.CritChance * nPenetratingShots)
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    local cExplosiveVenomInstantDmgAoE = 0
    local cExplosiveVenomDotDmgAoE = 0
    if wan.traitData.ExplosiveVenom.known then
        local checkExplosiveVenomBuff = wan.auraData.player["buff_" .. wan.traitData.ExplosiveVenom.traitkey]

        if checkExplosiveVenomBuff and checkExplosiveVenomBuff.applications == (nExplosiveVenomStacks - 1) then

            for nameplateUnitToken, _ in pairs(idValidUnit) do
                local checkUnitExplosiveVenomBuff = wan.auraData[nameplateUnitToken].debuff_SerpentSting
                cExplosiveVenomInstantDmgAoE = cExplosiveVenomInstantDmgAoE + nExplosiveVenomInstantDmg

                if not checkUnitExplosiveVenomBuff then
                    local dotPotency = wan.CheckDotPotency(nExplosiveVenomInstantDmg, nameplateUnitToken)
                    cExplosiveVenomDotDmgAoE = cExplosiveVenomDotDmgAoE + (nExplosiveVenomDotDmg * dotPotency)
                end

            end
        end
    end

    local cExplosiveShotUnitOverflow = wan.AdjustSoftCapUnitOverflow(nExplosiveShotSoftCap, countValidUnit)
    local cExplosiveShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cExplosiveShotInstantDmg = cExplosiveShotInstantDmg
    cExplosiveShotDotDmg = cExplosiveShotDotDmg
    cExplosiveShotInstantDmgAoE = cExplosiveShotInstantDmgAoE + (((nExplosiveShotDmg * cExplosiveShotUnitOverflow) + cExplosiveVenomInstantDmgAoE) * cExplosiveShotCritValue)
    cExplosiveShotDotDmgAoE = cExplosiveShotDotDmgAoE + (cExplosiveVenomDotDmgAoE * cExplosiveShotCritValue)

    local cExplosiveShotDmg = cExplosiveShotInstantDmg + cExplosiveShotDotDmg + cExplosiveShotInstantDmgAoE + cExplosiveShotDotDmgAoE

    local abilityValue = math.floor(cExplosiveShotDmg)
    wan.UpdateAbilityData(wan.spellData.ExplosiveShot.basename, abilityValue, wan.spellData.ExplosiveShot.icon, wan.spellData.ExplosiveShot.name)
end

-- Init frame 
local frameExplosiveShot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nExplosiveShotValues = wan.GetSpellDescriptionNumbers(wan.spellData.ExplosiveShot.id, { 2, 4 })
            nExplosiveShotDmg = nExplosiveShotValues[1]
            nExplosiveShotSoftCap = nExplosiveShotValues[2]

            local nExplosiveVenomValues = wan.GetTraitDescriptionNumbers(wan.traitData.VenomsBite.entryid, { 4, 5 })
            nExplosiveVenomInstantDmg = nExplosiveVenomValues[1]
            nExplosiveVenomDotDmg = nExplosiveVenomValues[2]
        end
    end)
end
frameExplosiveShot:RegisterEvent("ADDON_LOADED")
frameExplosiveShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ExplosiveShot.known and wan.spellData.ExplosiveShot.id
        wan.BlizzardEventHandler(frameExplosiveShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameExplosiveShot, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01

        nExplosiveVenomStacks = wan.GetTraitDescriptionNumbers(wan.traitData.ExplosiveVenom.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameExplosiveShot, CheckAbilityValue, abilityActive)
    end
end)