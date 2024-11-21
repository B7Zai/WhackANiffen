local _, wan = ...

local frameRaze = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init spell data
    local abilityActive = false
    local nRazeDmg = 0
    local maxRange = 8

    -- Init trait data
    local nVulnerableFlesh = 0

    -- Ability value calculation
    local function CheckAbilityValue()
         -- Early exits
        if not wan.PlayerState.Status or not wan.auraData.player.buff_BearForm
            or not wan.IsSpellUsable(wan.spellData.Raze.id)
        then
            wan.UpdateAbilityData(wan.spellData.Raze.basename)
            return
        end

        -- Check for valid unit
        local _, countValidUnit = wan.ValidUnitBoolCounter(nil, maxRange)
        if countValidUnit == 0 then
            wan.UpdateAbilityData(wan.spellData.Raze.basename)
            return
        end

        -- Base values
        local critChanceMod = 0
        local critDamageMod = 0
        local cRazeDmg = nRazeDmg * countValidUnit

        -- Vulnerable Flesh
        if wan.traitData.VulnerableFlesh.known then
            critChanceMod = critDamageMod + nVulnerableFlesh
        end

        -- Remove physical layer
        local checkPhysicalDRAoE = wan.CheckUnitPhysicalDamageReductionAoE(wan.classificationData, nil, maxRange)
        cRazeDmg = cRazeDmg * checkPhysicalDRAoE

        -- Crit layer
        cRazeDmg = cRazeDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

        -- Threat situation
        local isTanking = wan.IsTanking()

        local damageValue = not isTanking and math.floor(cRazeDmg) or 0 -- Update Ability Data

        wan.UpdateAbilityData(wan.spellData.Raze.basename, damageValue, wan.spellData.Raze.icon, wan.spellData.Raze.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nRazeDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Raze.id, { 1 })
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Raze.known and wan.spellData.Raze.id
            wan.BlizzardEventHandler(frameRaze, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameRaze, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nVulnerableFlesh = wan.GetTraitDescriptionNumbers(wan.traitData.VulnerableFlesh.entryid, { 1 }, wan.traitData.VulnerableFlesh.rank)
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameRaze, CheckAbilityValue, abilityActive)
        end
    end)
end

frameRaze:RegisterEvent("ADDON_LOADED")
frameRaze:SetScript("OnEvent", OnEvent)