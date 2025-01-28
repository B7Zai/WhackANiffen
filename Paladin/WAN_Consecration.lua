local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nConsecrationDmg, nConsecrationMaxRange = 0, 11

-- Init trait data
local nConsecratedGroundRangeMod = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player["buff_" .. wan.spellData.Consecration.basename]
        or not wan.IsSpellUsable(wan.spellData.Consecration.id)
    then
        wan.UpdateAbilityData(wan.spellData.Consecration.basename)
        return
    end

    for i = 1, 4 do
        local _, totemName = GetTotemInfo(i)
        if totemName and totemName == wan.spellData.Consecration.name then
            wan.UpdateAbilityData(wan.spellData.Consecration.basename)
            return
        end
    end

    local cConsecrationMaxRange = 11
    if wan.traitData.ConsecratedGround.known then
        cConsecrationMaxRange = cConsecrationMaxRange + (nConsecrationMaxRange * nConsecratedGroundRangeMod)
    end

    -- Check for valid unit
    local _, countValidUnit, idValidUnit  = wan.ValidUnitBoolCounter(nil, cConsecrationMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.Consecration.basename)
        return
    end

    local critChanceMod = 0
    local critDamageMod = 0

    local cConsecrationInstantDmg = 0
    local cConsecrationDotDmg = 0
    local cConsecrationInstantDmgAoE = 0
    local cConsecrationDotDmgAoE = 0

    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        cConsecrationInstantDmgAoE = cConsecrationInstantDmgAoE + (nConsecrationDmg * checkPotency)
    end

    local cConsecrationCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    
    cConsecrationInstantDmg = cConsecrationInstantDmg

    cConsecrationDotDmg = cConsecrationDotDmg 

    cConsecrationInstantDmgAoE = cConsecrationInstantDmgAoE

    cConsecrationDotDmgAoE = cConsecrationDotDmgAoE * cConsecrationCritValue

    local cConsecrationDmg = cConsecrationInstantDmg + cConsecrationDotDmg + cConsecrationInstantDmgAoE + cConsecrationDotDmgAoE

    local abilityValue = math.floor(cConsecrationDmg)
    wan.UpdateAbilityData(wan.spellData.Consecration.basename, abilityValue, wan.spellData.Consecration.icon, wan.spellData.Consecration.name)
end

-- Init frame 
local frameConsecration = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            nConsecrationDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Consecration.id, { 1 })
        end
    end)
end
frameConsecration:RegisterEvent("ADDON_LOADED")
frameConsecration:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings & data update on traits
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Consecration.known and wan.spellData.Consecration.id
        wan.BlizzardEventHandler(frameConsecration, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameConsecration, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nConsecratedGroundRangeMod = wan.GetTraitDescriptionNumbers(wan.traitData.ConsecratedGround.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameConsecration, CheckAbilityValue, abilityActive)
    end
end)