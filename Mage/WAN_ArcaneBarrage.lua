local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nArcaneBarrageDmg = 0

-- Init trait data
local nOverflowingEnergy = 0


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ArcaneBarrage.id)
    then
        wan.UpdateAbilityData(wan.spellData.ArcaneBarrage.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(wan.spellData.ArcaneBarrage.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ArcaneBarrage.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cArcaneBarrageInstantDmg = 0
    local cArcaneBarrageDotDmg = 0
    local cArcaneBarrageInstantDmgAoE = 0
    local cArcaneBarrageDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    local cArcaneBarrageCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cArcaneBarrageInstantDmg = cArcaneBarrageInstantDmg
        + (nArcaneBarrageDmg* cArcaneBarrageCritValue)

    cArcaneBarrageDotDmg = cArcaneBarrageDotDmg 

    cArcaneBarrageInstantDmgAoE = cArcaneBarrageInstantDmgAoE

    cArcaneBarrageDotDmgAoE = cArcaneBarrageDotDmgAoE

    local cArcaneBarrageDmg = cArcaneBarrageInstantDmg + cArcaneBarrageDotDmg + cArcaneBarrageInstantDmgAoE + cArcaneBarrageDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cArcaneBarrageDmg)
    wan.UpdateAbilityData(wan.spellData.ArcaneBarrage.basename, abilityValue, wan.spellData.ArcaneBarrage.icon, wan.spellData.ArcaneBarrage.name)
end

-- Init frame 
local frameArcaneBarrage = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nArcaneBarrageDmg = wan.GetSpellDescriptionNumbers(wan.spellData.ArcaneBarrage.id, { 1 })
        end
    end)
end
frameArcaneBarrage:RegisterEvent("ADDON_LOADED")
frameArcaneBarrage:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ArcaneBarrage.known and wan.spellData.ArcaneBarrage.id
        wan.BlizzardEventHandler(frameArcaneBarrage, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameArcaneBarrage, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArcaneBarrage, CheckAbilityValue, abilityActive)
    end
end)