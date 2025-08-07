local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nBarrageCastTime, nBarrageDmg, nBarrageSoftCap = 0, 0, 0

-- Init trait data


-- Ability value calculation
local function CheckAbilityValue()

    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Barrage.id)
    then
        wan.UpdateAbilityData(wan.spellData.Barrage.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Barrage.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Barrage.basename)
        return
    end

    local canMoveCast = true
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Barrage.id, nBarrageCastTime, canMoveCast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.Barrage.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cBarrageInstantDmg = 0
    local cBarrageDotDmg = 0
    local cBarrageInstantAoEDmg = 0
    local cBarrageDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cBarrageUnitOverflow = wan.SoftCapOverflow(nBarrageSoftCap, countValidUnit)
    local cBarrageInstantDmgBaseAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

        cBarrageInstantDmgBaseAoE = cBarrageInstantDmgBaseAoE + (nBarrageDmg * checkPhysicalDR * cBarrageUnitOverflow)
    end

    local cBarrageCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cBarrageInstantDmg = cBarrageInstantDmg
        + (cBarrageInstantDmgBaseAoE * cBarrageCritValue)

    cBarrageDotDmg = cBarrageDotDmg

    cBarrageInstantAoEDmg = cBarrageInstantAoEDmg

    cBarrageDotDmgAoE = cBarrageDotDmgAoE

    local cBarrageDmg = (cBarrageInstantDmg + cBarrageDotDmg + cBarrageInstantAoEDmg + cBarrageDotDmgAoE) * castEfficiency

    local abilityValue = math.floor(cBarrageDmg)
    wan.UpdateAbilityData(wan.spellData.Barrage.basename, abilityValue, wan.spellData.Barrage.icon, wan.spellData.Barrage.name)
end

-- Init frame 
local frameBarrage = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nBarrageValues = wan.GetSpellDescriptionNumbers(wan.spellData.Barrage.id, { 1, 2, 3 })
            nBarrageCastTime = nBarrageValues[1] * 1000
            nBarrageDmg = nBarrageValues[2]
            nBarrageSoftCap = nBarrageValues[3]
        end
    end)
end
frameBarrage:RegisterEvent("ADDON_LOADED")
frameBarrage:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Barrage.known and wan.spellData.Barrage.id
        wan.BlizzardEventHandler(frameBarrage, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBarrage, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then  end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBarrage, CheckAbilityValue, abilityActive)
    end
end)