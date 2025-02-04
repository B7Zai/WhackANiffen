local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nFireBlastDmg = 0

-- Init trait datat


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.FireBlast.id)
    then
        wan.UpdateAbilityData(wan.spellData.FireBlast.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(wan.spellData.FireBlast.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.FireBlast.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cFireBlastInstantDmg = 0
    local cFireBlastDotDmg = 0
    local cFireBlastInstantDmgAoE = 0
    local cFireBlastDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cFireBlastCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cFireBlastInstantDmg = cFireBlastInstantDmg
        + (nFireBlastDmg* cFireBlastCritValue)

    cFireBlastDotDmg = cFireBlastDotDmg 

    cFireBlastInstantDmgAoE = cFireBlastInstantDmgAoE

    cFireBlastDotDmgAoE = cFireBlastDotDmgAoE

    local cFireBlastDmg = cFireBlastInstantDmg + cFireBlastDotDmg + cFireBlastInstantDmgAoE + cFireBlastDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cFireBlastDmg)
    wan.UpdateAbilityData(wan.spellData.FireBlast.basename, abilityValue, wan.spellData.FireBlast.icon, wan.spellData.FireBlast.name)
end

-- Init frame 
local frameFireBlast = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nFireBlastDmg = wan.GetSpellDescriptionNumbers(wan.spellData.FireBlast.id, { 1 })
        end
    end)
end
frameFireBlast:RegisterEvent("ADDON_LOADED")
frameFireBlast:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FireBlast.known and wan.spellData.FireBlast.id
        wan.BlizzardEventHandler(frameFireBlast, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFireBlast, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        --nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFireBlast, CheckAbilityValue, abilityActive)
    end
end)