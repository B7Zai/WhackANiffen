local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nDragonsBreathDmg, nDragonsBreathMaxRange = 0, 12

-- Init trait data
local nOverflowingEnergy = 0
local nAlexstraszasFuryCritDmg = 0
local nFiresIre = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.DragonsBreath.id)
    then
        wan.UpdateAbilityData(wan.spellData.DragonsBreath.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nDragonsBreathMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.DragonsBreath.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cDragonsBreathInstantDmg = 0
    local cDragonsBreathDotDmg = 0
    local cDragonsBreathInstantDmgAoE = 0
    local cDragonsBreathDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    ---- FIRE TRAITS ----

    if wan.traitData.AlexstraszasFury.known then
        critChanceMod = critChanceMod + 100
        critDamageMod = critDamageMod + nAlexstraszasFuryCritDmg
    end

    if wan.traitData.Combustion.known then
        local checkCombustionBuff = wan.CheckUnitBuff(nil, wan.spellData.Combustion.formattedName)
        if checkCombustionBuff then
            critChanceMod = critChanceMod + 100

            if wan.traitData.FiresIre.known then
                critDamageMod = critDamageMod + nFiresIre
            end
        end
    end
    
    local cDragonsBreathCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cDragonsBreathInstantDmg = cDragonsBreathInstantDmg

    cDragonsBreathDotDmg = cDragonsBreathDotDmg

    cDragonsBreathInstantDmgAoE = cDragonsBreathInstantDmgAoE
        + (nDragonsBreathDmg * countValidUnit * cDragonsBreathCritValue)

    cDragonsBreathDotDmgAoE = cDragonsBreathDotDmgAoE

    local cDragonsBreathDmg = cDragonsBreathInstantDmg + cDragonsBreathDotDmg + cDragonsBreathInstantDmgAoE + cDragonsBreathDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cDragonsBreathDmg)
    wan.UpdateAbilityData(wan.spellData.DragonsBreath.basename, abilityValue, wan.spellData.DragonsBreath.icon, wan.spellData.DragonsBreath.name)
end

-- Init frame 
local frameDragonsBreath = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nDragonsBreathDmg = wan.GetSpellDescriptionNumbers(wan.spellData.DragonsBreath.id, { 1 })
        end
    end)
end
frameDragonsBreath:RegisterEvent("ADDON_LOADED")
frameDragonsBreath:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.DragonsBreath.known and wan.spellData.DragonsBreath.id
        wan.BlizzardEventHandler(frameDragonsBreath, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameDragonsBreath, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        nAlexstraszasFuryCritDmg = wan.GetTraitDescriptionNumbers(wan.traitData.AlexstraszasFury.entryid, { 1 })

        nFiresIre = wan.GetTraitDescriptionNumbers(wan.traitData.FiresIre.entryid, { 2 }, wan.traitData.FiresIre.rank)
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDragonsBreath, CheckAbilityValue, abilityActive)
    end
end)