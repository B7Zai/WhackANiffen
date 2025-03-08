local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nRallyingCry = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.CheckUnitDebuff(nil, wan.spellData.RallyingCry.formattedName)
    or not wan.IsSpellUsable(wan.spellData.RallyingCry.id)
    then
        wan.UpdateMechanicData(wan.spellData.RallyingCry.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()
        local groupAbilityValue = 0

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cRallyingCry = nRallyingCry 

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cRallyingCry, currentPercentHealth)
                groupAbilityValue = groupAbilityValue + abilityValue
            end
        end

        groupAbilityValue = groupAbilityValue >= nRallyingCry and groupAbilityValue or 0
        wan.UpdateMechanicData(wan.spellData.RallyingCry.basename, groupAbilityValue, wan.spellData.RallyingCry.icon, wan.spellData.RallyingCry.name)
    else
        -- Base defensive value
        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local cRallyingCry = nRallyingCry

        -- Update ability data
        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cRallyingCry, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.RallyingCry.basename, abilityValue, wan.spellData.RallyingCry.icon, wan.spellData.RallyingCry.name)
    end
end

-- Init frame 
local frameRallyingCry = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nRallyingCry = wan.DefensiveCooldownToValue(wan.spellData.RallyingCry.id)
        end
    end)
end
frameRallyingCry:RegisterEvent("ADDON_LOADED")
frameRallyingCry:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.RallyingCry.known and wan.spellData.RallyingCry.id
        wan.SetUpdateRate(frameRallyingCry, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameRallyingCry, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRallyingCry, CheckAbilityValue, abilityActive)
    end
end)