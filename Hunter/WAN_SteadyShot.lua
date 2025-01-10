local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nSteadyShotDmg = 0

-- Init trait datat
local nPenetratingShots = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.SteadyShot.id)
    then
        wan.UpdateAbilityData(wan.spellData.SteadyShot.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(wan.spellData.SteadyShot.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.SteadyShot.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cSteadyShotInstantDmg = nSteadyShotDmg
    local cSteadyShotDotDmg = 0
    local cSteadyShotInstantDmgAoE = 0
    local cSteadyShotDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cPenetratingShots = 0
    if wan.traitData.PenetratingShots.known then
        cPenetratingShots = cPenetratingShots + (wan.CritChance * nPenetratingShots)
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    local canMoveCast = true
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.SteadyShot.id, wan.spellData.SteadyShot.castTime, canMoveCast)
    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cSteadyShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cSteadyShotInstantDmg = cSteadyShotInstantDmg * checkPhysicalDR * cSteadyShotCritValue
    cSteadyShotDotDmg = cSteadyShotDotDmg 
    cSteadyShotInstantDmgAoE = cSteadyShotInstantDmgAoE
    cSteadyShotDotDmgAoE = cSteadyShotDotDmgAoE

    local cSteadyShotDmg = (cSteadyShotInstantDmg + cSteadyShotDotDmg + cSteadyShotInstantDmgAoE + cSteadyShotDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cSteadyShotDmg)
    wan.UpdateAbilityData(wan.spellData.SteadyShot.basename, abilityValue, wan.spellData.SteadyShot.icon, wan.spellData.SteadyShot.name)
end

-- Init frame 
local frameSteadyShot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nSteadyShotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.SteadyShot.id, { 1 })

        end
    end)
end
frameSteadyShot:RegisterEvent("ADDON_LOADED")
frameSteadyShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.SteadyShot.known and wan.spellData.SteadyShot.id
        wan.BlizzardEventHandler(frameSteadyShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSteadyShot, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSteadyShot, CheckAbilityValue, abilityActive)
    end
end)