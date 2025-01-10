local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nVolleyInstantDmg = 0

-- Init trait data
local nPenetratingShots = 0
local nSalvoUnitCap = 0
local nExplosiveShotDmg, nExplosiveShotSoftCap = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Volley.id)
    then
        wan.UpdateAbilityData(wan.spellData.Volley.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Volley.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Volley.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cVolleyInstantDmg = 0
    local cVolleyDotDmg = 0
    local cVolleyInstantDmgAoE = 0
    local cVolleyDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)
        local dotPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        cVolleyInstantDmgAoE = cVolleyInstantDmgAoE + (nVolleyInstantDmg * checkPhysicalDR * dotPotency)
    end

    local cPenetratingShots = 0
    if wan.traitData.PenetratingShots.known then
        cPenetratingShots = cPenetratingShots + (wan.CritChance * nPenetratingShots)
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    local cSalvoInstantDmgAoE = 0
    if wan.traitData.Salvo.known and wan.auraData.player["buff_" .. wan.traitData.Salvo.traitkey] then
        local cExplosiveShotUnitOverflow = wan.AdjustSoftCapUnitOverflow(nExplosiveShotSoftCap, countValidUnit)
        local cSalvoUnitCap = math.min(nSalvoUnitCap, countValidUnit)

        cSalvoInstantDmgAoE = cSalvoInstantDmgAoE + (nExplosiveShotDmg * cExplosiveShotUnitOverflow * cSalvoUnitCap)
    end

    -- Crit layer
    local cVolleyCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cVolleyInstantDmg = cVolleyInstantDmg
    cVolleyDotDmg = cVolleyDotDmg
    cVolleyInstantDmgAoE = (cVolleyInstantDmgAoE + cSalvoInstantDmgAoE) * cVolleyCritValue
    cVolleyDotDmgAoE = cVolleyDotDmgAoE

    local cVolleyDmg = cVolleyInstantDmg + cVolleyDotDmg + cVolleyInstantDmgAoE + cVolleyDotDmgAoE
    local cdPotency = wan.CheckOffensiveCooldownPotency(cVolleyDmg, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cVolleyDmg) or 0
    wan.UpdateAbilityData(wan.spellData.Volley.basename, abilityValue, wan.spellData.Volley.icon, wan.spellData.Volley.name)
end

-- Init frame 
local frameVolley = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nVolleyInstantDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Volley.id, { 2 })

            local nExplosiveShotValues = wan.GetSpellDescriptionNumbers(wan.spellData.ExplosiveShot.id, { 2, 4 })
            nExplosiveShotDmg = nExplosiveShotValues[1]
            nExplosiveShotSoftCap = nExplosiveShotValues[2]
        end
    end)
end
frameVolley:RegisterEvent("ADDON_LOADED")
frameVolley:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Volley.known and wan.spellData.Volley.id
        wan.BlizzardEventHandler(frameVolley, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameVolley, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01

        nSalvoUnitCap = wan.GetTraitDescriptionNumbers(wan.traitData.Salvo.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameVolley, CheckAbilityValue, abilityActive)
    end
end)