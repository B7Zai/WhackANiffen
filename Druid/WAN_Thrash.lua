local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local sThrashDebuff, nTrashInstantDmg, nThrashDotDmg = "Thrash", 0, 0

-- Init trait data
local bBloodtalons, sBloodtalons, nBloodtalonsTimer, runBloodtalons = false, "Bloodtalons", 0, true

-- Ability value calculation
local function CheckAbilityValue()
     -- Early exits
    if not wan.PlayerState.Status 
        or not wan.IsSpellUsable(wan.spellData.Thrash.id)
    then
        wan.UpdateAbilityData(wan.spellData.Thrash.basename)
        return
    end

    -- Check for valid unit
    local _, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Thrash.maxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.Thrash.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critChanceModBase = 0
    local critDamageMod = 0
    local critDamageModBase = 0

    local cThrashInstantDmg = 0
    local cThrashDotDmg = 0
    local cThrashInstantDmgAoE = 0
    local cThrashDotDmgAoE = 0

    local cThrashInstantDmgBaseAoE = 0
    local cThrashDotDmgBaseAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        cThrashInstantDmgBaseAoE = cThrashInstantDmgBaseAoE + nTrashInstantDmg

        local checkThrashDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sThrashDebuff)
        if not checkThrashDebuff then
            local dotPotency = wan.CheckDotPotency(nTrashInstantDmg, nameplateUnitToken)

            cThrashDotDmgBaseAoE = cThrashDotDmgBaseAoE + (nThrashDotDmg * dotPotency)
        end
    end

    ---- FERAL TRAITS ----

    if bBloodtalons then
        if not wan.IsTimerRunning then
            runBloodtalons = true
        end

        local checkBloodtalonsBuff = wan.CheckUnitBuff(nil, sBloodtalons)
        if not checkBloodtalonsBuff and not runBloodtalons then
            wan.UpdateAbilityData(wan.spellData.Thrash.basename)
            return
        end
    end

    -- Crit layer
    local cThrashCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cThrashInstantDmg = cThrashInstantDmg
        + (cThrashInstantDmgBaseAoE * cThrashCritValue)

    cThrashDotDmg = cThrashDotDmg
        + (cThrashDotDmgBaseAoE * cThrashCritValue)

    cThrashInstantDmgAoE = cThrashInstantDmgAoE

    cThrashDotDmgAoE = cThrashDotDmgAoE

    local cThrashDmg = cThrashInstantDmg + cThrashDotDmg + cThrashInstantDmgAoE + cThrashDotDmgAoE

     -- Update ability data
    local abilityValue = math.floor(cThrashDmg)
    wan.UpdateAbilityData(wan.spellData.Thrash.basename, abilityValue, wan.spellData.Thrash.icon, wan.spellData.Thrash.name)
end

local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)

        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local thrashValues = wan.GetSpellDescriptionNumbers(wan.spellData.Thrash.id, { 1, 2 })
            nTrashInstantDmg = thrashValues[1]
            nThrashDotDmg = thrashValues[2]
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and bBloodtalons then
            if spellID == wan.spellData.Thrash.id then
                wan.SetTimer(nBloodtalonsTimer)

                if wan.IsTimerRunning then
                    runBloodtalons = false
                end
            end
        end
    end)
end

local frameThrash = CreateFrame("Frame")
frameThrash:RegisterEvent("ADDON_LOADED")
frameThrash:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Thrash.known and wan.spellData.Thrash.id
        wan.BlizzardEventHandler(frameThrash, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameThrash, CheckAbilityValue, abilityActive)

        sThrashDebuff = wan.spellData.Thrash.formattedName
    end

    if event == "TRAIT_DATA_READY" then

        bBloodtalons = wan.traitData.Bloodtalons.known
        sBloodtalons = wan.traitData.Bloodtalons.traitkey
        nBloodtalonsTimer = wan.GetTraitDescriptionNumbers(wan.traitData.Bloodtalons.entryid, { 2 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameThrash, CheckAbilityValue, abilityActive)
    end
end)