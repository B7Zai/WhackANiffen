local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nBulkExtraction = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.BulkExtraction.id)
    then
        wan.UpdateMechanicData(wan.spellData.BulkExtraction.basename)
        return
    end

    local currentPercentHealth = wan.CheckUnitPercentHealth(playerGUID)
    local cBulkExtraction = nBulkExtraction

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cBulkExtraction, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.BulkExtraction.basename, abilityValue, wan.spellData.BulkExtraction.icon, wan.spellData.BulkExtraction.name)
end

-- Init frame 
local frameBulkExtraction = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBulkExtraction = wan.DefensiveCooldownToValue(wan.spellData.BulkExtraction.id)
        end
    end)
end
frameBulkExtraction:RegisterEvent("ADDON_LOADED")
frameBulkExtraction:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.BulkExtraction.isPassive and wan.spellData.BulkExtraction.known and wan.spellData.BulkExtraction.id
        wan.BlizzardEventHandler(frameBulkExtraction, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBulkExtraction, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBulkExtraction, CheckAbilityValue, abilityActive)
    end
end)
