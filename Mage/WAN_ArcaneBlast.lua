local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nArcaneBlastDmg = 0

-- Init trait datat
local nArcaneDebilitation = 0
local nLeydrinker, nLeydrinkerUnitCap = 0, 4

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ArcaneBlast.id)
    then
        wan.UpdateAbilityData(wan.spellData.ArcaneBlast.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit = wan.ValidUnitBoolCounter(wan.spellData.ArcaneBlast.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ArcaneBlast.basename)
        return
    end

    local canMovecast = wan.auraData.player.buff_IceFloes and true or false
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.ArcaneBlast.id, wan.spellData.ArcaneBlast.castTime, canMovecast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.ArcaneBlast.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cArcaneBlastInstantDmg = 0
    local cArcaneBlastDotDmg = 0
    local cArcaneBlastInstantDmgAoE = 0
    local cArcaneBlastDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- ARCANE TRAITS ----

    local cArcaneDebilitation = 1
    if wan.traitData.ArcaneDebilitation.known then
        local checkArcaneDebilitationDebuff = wan.CheckUnitDebuff(targetUnitToken, wan.traitData.ArcaneDebilitation.traitkey)
        if checkArcaneDebilitationDebuff then
            local checkArcaneDebilitationStacks = checkArcaneDebilitationDebuff.applications
            cArcaneDebilitation = cArcaneDebilitation + (nArcaneDebilitation * checkArcaneDebilitationStacks)
        end
    end

    local cLeydrinkerInstantDmgAoE = 0
    if wan.traitData.Leydrinker.known then
        local checkLeydrinkerBuff = wan.CheckUnitBuff(nil, wan.traitData.Leydrinker.traitkey)
        if checkLeydrinkerBuff then
            local cLeydrinkerUnitCap = math.min(countValidUnit, nLeydrinkerUnitCap)
            cLeydrinkerInstantDmgAoE = cLeydrinkerInstantDmgAoE + (nArcaneBlastDmg * nLeydrinker * cArcaneDebilitation * cLeydrinkerUnitCap)
        end
    end

    local cArcaneBlastCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cArcaneBlastInstantDmg = cArcaneBlastInstantDmg
        + (nArcaneBlastDmg * cArcaneDebilitation * cArcaneBlastCritValue)

    cArcaneBlastDotDmg = cArcaneBlastDotDmg 

    cArcaneBlastInstantDmgAoE = cArcaneBlastInstantDmgAoE
        + (cLeydrinkerInstantDmgAoE * cArcaneBlastCritValue)

    cArcaneBlastDotDmgAoE = cArcaneBlastDotDmgAoE

    local cArcaneBlastDmg = (cArcaneBlastInstantDmg + cArcaneBlastDotDmg + cArcaneBlastInstantDmgAoE + cArcaneBlastDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cArcaneBlastDmg)
    wan.UpdateAbilityData(wan.spellData.ArcaneBlast.basename, abilityValue, wan.spellData.ArcaneBlast.icon, wan.spellData.ArcaneBlast.name)
end

-- Init frame 
local frameArcaneBlast = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nArcaneBlastDmg = wan.GetSpellDescriptionNumbers(wan.spellData.ArcaneBlast.id, { 1 })

        end
    end)
end
frameArcaneBlast:RegisterEvent("ADDON_LOADED")
frameArcaneBlast:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ArcaneBlast.known and wan.spellData.ArcaneBlast.id
        wan.BlizzardEventHandler(frameArcaneBlast, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameArcaneBlast, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nArcaneDebilitation = wan.GetTraitDescriptionNumbers(wan.traitData.ArcaneDebilitation.entryid, { 1 }, wan.traitData.ArcaneDebilitation.rank) * 0.01

        nLeydrinker = wan.GetTraitDescriptionNumbers(wan.traitData.Leydrinker.entryid, { 2 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArcaneBlast, CheckAbilityValue, abilityActive)
    end
end)