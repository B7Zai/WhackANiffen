local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local checkDebuffs = { "Rake", "Thrash", "Rip", "Feral Frenzy", "Tear", "Frenzied Assault" }
local nMangleDmg = 0

-- Init trait data
local nPrimalFury = 0
local nMangle = 0
local nIncarnationAoeCap = 0
local nStrikeForTheHeart = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.auraData.player.buff_BearForm
        or not wan.IsSpellUsable(wan.spellData.Mangle.id)
    then
        wan.UpdateAbilityData(wan.spellData.Mangle.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Mangle.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Mangle.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local cMangleInstantDmg = nMangleDmg

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    -- Primal Fury
    if wan.traitData.PrimalFury.known then
        critDamageMod = critDamageMod + nPrimalFury
    end

    -- Mangle
    local cMangle = 0
    if wan.traitData.Mangle.known and wan.CheckForAnyDebuff(targetUnitToken, checkDebuffs) then
        cMangle = nMangleDmg * nMangle
    end

    -- Strike for the Heart
    if wan.traitData.StrikefortheHeart.known then
        critChanceMod = critChanceMod + nStrikeForTheHeart
        critDamageMod = critDamageMod + nStrikeForTheHeart
    end

    -- Incarnation: Guardian of Ursoc
    local cMangleInstantDmgAoE = 0
    if wan.auraData.player.buff_IncarnationGuardianofUrsoc and countValidUnit > 1 then
        local unitCountMangle = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local cMangleIncarnationDmg = nMangleDmg
                local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                local cUnitMangle = 0
                if wan.traitData.Mangle.known and wan.CheckForAnyDebuff(nameplateUnitToken, checkDebuffs) then
                    cUnitMangle = nMangleDmg * nMangle
                end

                cMangleInstantDmgAoE = cMangleInstantDmgAoE + ((cMangleIncarnationDmg + cUnitMangle) * checkPhysicalDR)
                unitCountMangle = unitCountMangle + 1
                
                if unitCountMangle >= nIncarnationAoeCap then break end
            end
        end
    end

    -- Remove physical layer
    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()

    -- Crit layer
    local cMangleCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cMangleInstantDmg = (cMangleInstantDmg + cMangle) * checkPhysicalDR * cMangleCritValue
    cMangleInstantDmgAoE = cMangleInstantDmgAoE * cMangleCritValue

    local cMangleDmg = cMangleInstantDmg + cMangleInstantDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cMangleDmg)
    wan.UpdateAbilityData(wan.spellData.Mangle.basename, abilityValue, wan.spellData.Mangle.icon, wan.spellData.Mangle.name)
end

-- Init frame 
local frameMangle = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            nMangleDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Mangle.id, { 1 })
        end
    end)
end
frameMangle:RegisterEvent("ADDON_LOADED")
frameMangle:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Mangle.known and wan.spellData.Mangle.id
        wan.BlizzardEventHandler(frameMangle, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameMangle, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nPrimalFury = wan.GetTraitDescriptionNumbers(wan.traitData.PrimalFury.entryid, { 1 }) / 100
        nMangle = wan.GetTraitDescriptionNumbers(wan.traitData.Mangle.entryid, { 1 }) / 100
        nIncarnationAoeCap = wan.GetTraitDescriptionNumbers(wan.traitData.IncarnationGuardianofUrsoc.entryid, { 1 })
        nStrikeForTheHeart = wan.GetTraitDescriptionNumbers(wan.traitData.StrikefortheHeart.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMangle, CheckAbilityValue, abilityActive)
    end
end)
