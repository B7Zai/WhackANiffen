local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nMultiShotDmg, nMultiShotSoftCap = 0, 0

-- Init trait data
local nPenetratingShots = 0
local nShrapnelShot = 0
local nSymphonicArsenal, nSymphonicArsenalUnitCap = 0, 0
local nUnerringVision = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.MultiShot.id)
    then
        wan.UpdateAbilityData(wan.spellData.MultiShot.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.MultiShot.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.MultiShot.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cMultiShotInstantDmg = 0
    local cMultiShotDotDmg = 0
    local cMultiShotInstantDmgAoE = 0
    local cMultiShotDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local checkTrickShotsBuff = wan.CheckUnitBuff(nil, wan.traitData.TrickShots.traitkey)
    local cMultiShotUnitOverflow = wan.SoftCapOverflow(nMultiShotSoftCap, countValidUnit)
    local cMultiShotInstantDmgBaseAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkPhysicalDR = not checkTrickShotsBuff and wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken) or 1

        cMultiShotInstantDmgBaseAoE = cMultiShotInstantDmgBaseAoE + (nMultiShotDmg * checkPhysicalDR * cMultiShotUnitOverflow)
    end

    ---- MARKSMAN TRAITS ----

    if wan.traitData.PenetratingShots.known then
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    local cShrapnelShot = 1
    if wan.traitData.ShrapnelShot.known then
        local formattedDebuffName = wan.traitData.ShrapnelShot.traitkey
        local countDebuff = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkShrapnelShotDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

            if checkShrapnelShotDebuff then
                countDebuff = countDebuff + 1
            end
        end

        if countDebuff > 0 then
            cShrapnelShot = cShrapnelShot + ((nShrapnelShot * countDebuff) / countValidUnit)
        end
    end

    if wan.traitData.UnerringVision.known then
        local checkTrueshotBuff = wan.CheckUnitBuff(nil, wan.spellData.Trueshot.formattedName)
        if checkTrueshotBuff then
            critDamageMod = critDamageMod + nUnerringVision
            critDamageModBase = critDamageModBase + nUnerringVision
        end
    end

    ---- SENTINEL TRAITS ----
    
    local cSymphonicArsenalInstantDmgAoE = 0
    if wan.traitData.SymphonicArsenal.known then
        local cSymphonicArsenalUnitCap = math.min(countValidUnit, nSymphonicArsenalUnitCap)
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkSentinelDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.traitData.Sentinel.traitkey)
            if checkSentinelDebuff then
                cSymphonicArsenalInstantDmgAoE = cSymphonicArsenalInstantDmgAoE + (nSymphonicArsenal * cSymphonicArsenalUnitCap)
            end
        end
    end

    local cMultiShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cMultiShotInstantDmg = cMultiShotInstantDmg
        + (cMultiShotInstantDmgBaseAoE * cMultiShotCritValue * cShrapnelShot)

    cMultiShotDotDmg = cMultiShotDotDmg

    cMultiShotInstantDmgAoE = cMultiShotInstantDmgAoE 
        + (cSymphonicArsenalInstantDmgAoE * cMultiShotCritValue)

    cMultiShotDotDmgAoE = cMultiShotDotDmgAoE

    local cMultiShotDmg = cMultiShotInstantDmg + cMultiShotDotDmg + cMultiShotInstantDmgAoE + cMultiShotDotDmgAoE

    if (wan.traitData.BeastCleave.known or wan.traitData.TrickShots.known) and countValidUnit > 2 then
        local currentTime = GetTime()
        local checkEnablerBuff = wan.CheckUnitBuff(nil, wan.traitData.BeastCleave.traitkey) or wan.CheckUnitBuff(nil, wan.traitData.TrickShots.traitkey)
        local addonUpdateRate = (wan.Options.UpdateRate.Toggle and wan.Options.UpdateRate.Slider * 0.01) or 0.4
        local expirationTime = (checkEnablerBuff and checkEnablerBuff.expirationTime - currentTime) or math.huge
        if not checkEnablerBuff or expirationTime < addonUpdateRate then
            cMultiShotDmg = cMultiShotDmg * countValidUnit
        end
    end

    local abilityValue = math.floor(cMultiShotDmg)
    wan.UpdateAbilityData(wan.spellData.MultiShot.basename, abilityValue, wan.spellData.MultiShot.icon, wan.spellData.MultiShot.name)
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

            local nSymphonicArsenalValues = wan.GetTraitDescriptionNumbers(wan.traitData.SymphonicArsenal.entryid, { 1, 2 })
            nSymphonicArsenal = nSymphonicArsenalValues[1]
            nSymphonicArsenalUnitCap = nSymphonicArsenalValues[2]
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
        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01

        nShrapnelShot = wan.GetTraitDescriptionNumbers(wan.traitData.ShrapnelShot.entryid, { 1 }) * 0.01

        nUnerringVision = wan.GetTraitDescriptionNumbers(wan.traitData.UnerringVision.entryid, { 2 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMultiShot, CheckAbilityValue, abilityActive)
    end
end)