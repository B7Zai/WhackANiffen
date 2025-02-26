local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nExplosiveShotDmg, nExplosiveShotSoftCap = 0, 0

-- Init trait data
local nPenetratingShots = 0
local nBombardierUnitCap = 0
local nThunderingHooves, nStompDmg, nStompDmgAoE = 0, 0, 0
local nUnerringVision = 0

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

    ---- BEAST MASTERY TRAITS ----

    local cThunderingHooves = 1
    local cThunderingHoovesInstandDmg = 0
    local cThunderingHoovesInstandDmgAoE = 0
    if wan.traitData.ThunderingHooves.entryid then
        cThunderingHooves = cThunderingHooves + nThunderingHooves

        local activePets = (wan.IsPetUsable() and 1 or 0) * (wan.traitData.AnimalCompanion.known and 2 or 1)
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(targetUnitToken)
        cThunderingHoovesInstandDmg = cThunderingHoovesInstandDmg + (nStompDmg * checkPhysicalDR * activePets * cThunderingHooves)

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cThunderingHoovesInstandDmgAoE = cThunderingHoovesInstandDmgAoE + (nStompDmgAoE * checkUnitPhysicalDR * activePets * cThunderingHooves)
            end
        end
    end

    ---- MARKSMAN TRAITS ----

    if wan.traitData.PenetratingShots.known then
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    if wan.traitData.UnerringVision.known then
        local checkTrueshotBuff = wan.CheckUnitBuff(nil, wan.spellData.Trueshot.formattedName)
        if checkTrueshotBuff then
            critDamageMod = critDamageMod + nUnerringVision
        end
    end

    ---- SURVIVAL TRAITS ----

    local cBombardier = 1
    if wan.traitData.Bombardier.known then
        local checkBombardierBuff = wan.CheckUnitBuff(nil, wan.traitData.Bombardier.traitkey)
        if checkBombardierBuff then
            cBombardier = nBombardierUnitCap
        end
    end

    local cExplosiveShotUnitOverflow = wan.AdjustSoftCapUnitOverflow(nExplosiveShotSoftCap, countValidUnit)
    local cExplosiveShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cExplosiveShotInstantDmg = cExplosiveShotInstantDmg
        + (cThunderingHoovesInstandDmg * cExplosiveShotCritValue)

    cExplosiveShotDotDmg = cExplosiveShotDotDmg

    cExplosiveShotInstantDmgAoE = cExplosiveShotInstantDmgAoE
        + (nExplosiveShotDmg * cExplosiveShotUnitOverflow * cBombardier * cExplosiveShotCritValue)
        + (cThunderingHoovesInstandDmgAoE * cExplosiveShotCritValue)

    cExplosiveShotDotDmgAoE = cExplosiveShotDotDmgAoE

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

            local nStompValues = wan.GetTraitDescriptionNumbers(wan.traitData.Stomp.entryid, { 1, 2 })
            nStompDmg = nStompValues[1]
            nStompDmgAoE = nStompValues[2]
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

        nBombardierUnitCap = wan.GetTraitDescriptionNumbers(wan.traitData.Bombardier.entryid, { 1 })

        nThunderingHooves = wan.GetTraitDescriptionNumbers(wan.traitData.ThunderingHooves.entryid, { 1 }) * 0.01

        nUnerringVision = wan.GetTraitDescriptionNumbers(wan.traitData.UnerringVision.entryid, { 2 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameExplosiveShot, CheckAbilityValue, abilityActive)
    end
end)