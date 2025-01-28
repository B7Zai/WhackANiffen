local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nBlessingofSacrifice = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
     or not wan.IsSpellUsable(wan.spellData.BlessingofSacrifice.id)
    then
        wan.UpdateSupportData(nil, wan.spellData.BlessingofSacrifice.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] and groupUnitGUID ~= playerGUID and not wan.auraData[groupUnitToken]["buff_" .. wan.spellData.BlessingofSacrifice.basename] then

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cBlessingofSacrifice = wan.UnitDefensiveCooldownToValue(wan.spellData.BlessingofSacrifice.id, groupUnitToken)

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cBlessingofSacrifice, currentPercentHealth)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.BlessingofSacrifice.basename, abilityValue, wan.spellData.BlessingofSacrifice.icon, wan.spellData.BlessingofSacrifice.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.BlessingofSacrifice.basename)
            end
        end
    end
end

-- Init frame 
local frameBlessingofSacrifice = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        end
    end)
end
frameBlessingofSacrifice:RegisterEvent("ADDON_LOADED")
frameBlessingofSacrifice:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BlessingofSacrifice.known and wan.spellData.BlessingofSacrifice.id
        wan.BlizzardEventHandler(frameBlessingofSacrifice, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBlessingofSacrifice, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.BlessingofSacrifice.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.BlessingofSacrifice.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBlessingofSacrifice, CheckAbilityValue, abilityActive)
    end
end)
