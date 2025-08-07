local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local aBloodshedData, nBloodshedDmg = {}, 0

-- Init trait data


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsPetUsable()
    or not wan.IsSpellUsable(aBloodshedData.id)
    then
        wan.UpdateAbilityData(aBloodshedData.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(aBloodshedData.id)
    if not isValidUnit then
        wan.UpdateAbilityData(aBloodshedData.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critChanceModBase = 0
    local critDamageMod = 0
    local critDamageModBase = 0

    local cBloodshedInstantDmg = 0
    local cBloodshedDotDmg = 0
    local cBloodshedInstantDmgAoE = 0
    local cBloodshedDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cBloodshedDotDmg = 0
    local checkBloodshedDebuff = wan.CheckUnitDebuff(nil, aBloodshedData.formattedName)
    if not checkBloodshedDebuff then
        local dotPotency = wan.CheckDotPotency()
        cBloodshedDotDmg = cBloodshedDotDmg + (nBloodshedDmg * dotPotency)
    end

    local cBloodshedCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cBloodshedInstantDmg = cBloodshedInstantDmg

    cBloodshedDotDmg = cBloodshedDotDmg
        + (cBloodshedDotDmg * cBloodshedCritValue)

    cBloodshedInstantDmgAoE = cBloodshedInstantDmgAoE

    cBloodshedDotDmgAoE = cBloodshedDotDmgAoE

    local cBloodshedDmg = cBloodshedInstantDmg + cBloodshedDotDmg + cBloodshedInstantDmgAoE + cBloodshedDotDmgAoE
    local cdPotency = wan.CheckOffensiveCooldownPotency(cBloodshedDmg, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cBloodshedDmg) or 0
    wan.UpdateAbilityData(aBloodshedData.basename, abilityValue, aBloodshedData.icon, aBloodshedData.name)
end

-- Init frame 
local frameBloodshed = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBloodshedDmg = wan.GetSpellDescriptionNumbers(aBloodshedData.id, { 1 })
        end
    end)
end
frameBloodshed:RegisterEvent("ADDON_LOADED")
frameBloodshed:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        aBloodshedData = wan.spellData.Bloodshed

        abilityActive = aBloodshedData.known and aBloodshedData.id
        wan.BlizzardEventHandler(frameBloodshed, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBloodshed, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBloodshed, CheckAbilityValue, abilityActive)
    end
end)