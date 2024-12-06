local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameLifebloom = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nLifebloomInstantHeal, nLifebloomHotHeal, nLifebloomHeal = 0, 0, 0

    -- Init trait data
    local nThrivingVegetation = 0
    local sGerminationKey = "RejuvenationGermination"

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
            or not wan.IsSpellUsable(wan.spellData.Rejuvenation.id)
        then
            wan.UpdateMechanicData(wan.spellData.Rejuvenation.basename)
            wan.GroupUnitHealThreshold()
            return
        end

        local cRejuvenationInstantHeal = 0
        local cRejuvenationHotHeal = nLifebloomHotHeal

        --add Thriving Vegetation trait layer
        if wan.traitData.ThrivingVegetation.known then
            local cThrivingVegetation = nLifebloomHotHeal * nThrivingVegetation
            cRejuvenationInstantHeal = cRejuvenationInstantHeal + cThrivingVegetation
        end

        -- add Germination trait layer
        local cGerminationHotHeal = 0
        if wan.traitData.Germination.known then
            cGerminationHotHeal = nLifebloomHotHeal
        end

        -- define crit layer
        local critValue = wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then

            cRejuvenationHotHeal = cRejuvenationHotHeal * critValue
            cGerminationHotHeal = cGerminationHotHeal * critValue
            cRejuvenationInstantHeal = cRejuvenationInstantHeal * critValue

            -- max healing value
            local cRejuvenationHeal = cRejuvenationInstantHeal + cRejuvenationHotHeal + cGerminationHotHeal

            -- max hot value
            wan.HotValue[wan.spellData.Rejuvenation.basename] = math.floor(cRejuvenationHotHeal)
            wan.HotValue[sGerminationKey] = math.floor(cGerminationHotHeal)

            local hotKeys = {wan.spellData.Rejuvenation.basename, sGerminationKey}
            local abilityValue = math.floor(cRejuvenationHeal) or 0
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()
            local groupUnitTokenHeal = wan.GroupUnitHealThreshold(idValidGroupUnit, abilityValue, wan.HotValue, hotKeys)
            wan.UpdateHealingData(groupUnitTokenHeal, wan.spellData.Rejuvenation.basename, abilityValue, wan.spellData.Rejuvenation.icon, wan.spellData.Rejuvenation.name)
        else
            -- define max healing value
            local cRejuvenationHealThreshold = cRejuvenationInstantHeal + cRejuvenationHotHeal  + cGerminationHotHeal

            -- define current healing value
            local cGermination = wan.auraData.player["buff_" .. sGerminationKey] and cGerminationHotHeal or 0
            local cRejuvenationHotValue = wan.auraData.player.buff_Rejuvenation and nLifebloomHotHeal or 0
            local cRejuvenationHeal = cRejuvenationInstantHeal + cRejuvenationHotValue + cGermination

            -- add crit layer
            cRejuvenationHeal = cRejuvenationHeal * critValue

            local abilityValue =  wan.HealThreshold() > cRejuvenationHealThreshold and math.floor(cRejuvenationHeal) or 0
            wan.UpdateMechanicData(wan.spellData.Rejuvenation.basename, abilityValue, wan.spellData.Rejuvenation.icon, wan.spellData.Rejuvenation.name)
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nLifebloomHotHeal = wan.GetSpellDescriptionNumbers(wan.spellData.Rejuvenation.id, { 1 })
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Rejuvenation.known and wan.spellData.Rejuvenation.id
            wan.BlizzardEventHandler(frameLifebloom, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameLifebloom, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nThrivingVegetation = wan.GetTraitDescriptionNumbers(wan.traitData.ThrivingVegetation.entryid, { 1 }) * 0.01
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameLifebloom, CheckAbilityValue, abilityActive)
        end
    end)
end

frameLifebloom:RegisterEvent("ADDON_LOADED")
frameLifebloom:SetScript("OnEvent", AddonLoad)