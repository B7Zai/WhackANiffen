local _, wan = ...

local frameRegrowth = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init data
    local abilityActive = false
    local nRegrowthInstantHeal, nRegrowthHotHeal, nRegrowthHeal = 0, 0, 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_Prowl
            or (wan.auraData.player.buff_CatForm and not wan.auraData.player.buff_PredatorySwiftness)
            or (wan.auraData.player.buff_BearForm and not wan.auraData.player.buff_DreamofCenarius)
            or wan.auraData.player.buff_FrenziedRegeneration or wan.HealThreshold() <= nRegrowthHeal
            or not wan.IsSpellUsable(wan.spellData.Regrowth.id)
        then
            wan.UpdateMechanicData(wan.spellData.Regrowth.basename)
            return
        end

        -- Base values
        local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Regrowth.id, wan.spellData.Regrowth.castTime)
        local cRegrowtHotHeal = (not wan.auraData.player.buff_Regrowth and nRegrowthHotHeal) or 0 -- Hot values
        local cRegrowthHeal = (nRegrowthInstantHeal + cRegrowtHotHeal * castEfficiency)

        -- Crit layer
        cRegrowthHeal = cRegrowthHeal * wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        local abilityValue = math.floor(cRegrowthHeal) or 0
        wan.UpdateMechanicData(wan.spellData.Regrowth.basename, abilityValue, wan.spellData.Regrowth.icon, wan.spellData.Regrowth.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local regrowthValues = wan.GetSpellDescriptionNumbers(wan.spellData.Regrowth.id, { 1, 2 })
            nRegrowthInstantHeal = regrowthValues[1]
            nRegrowthHotHeal = regrowthValues[2]
            nRegrowthHeal = regrowthValues[1] + regrowthValues[2]
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Regrowth.known and wan.spellData.Regrowth.id
            wan.BlizzardEventHandler(frameRegrowth, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameRegrowth, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameRegrowth, CheckAbilityValue, abilityActive)
        end
    end)
end

frameRegrowth:RegisterEvent("ADDON_LOADED")
frameRegrowth:SetScript("OnEvent", OnEvent)