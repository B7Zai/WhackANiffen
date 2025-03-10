local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nDiebytheSword = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.DiebytheSword.id)
    then
        wan.UpdateMechanicData(wan.spellData.DiebytheSword.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cDiebytheSword = nDiebytheSword

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cDiebytheSword, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.DiebytheSword.basename, abilityValue, wan.spellData.DiebytheSword.icon, wan.spellData.DiebytheSword.name)
end

-- Init frame 
local frameDiebytheSword = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nDiebytheSword = wan.DefensiveCooldownToValue(wan.spellData.DiebytheSword.id)
        end
    end)
end
frameDiebytheSword:RegisterEvent("ADDON_LOADED")
frameDiebytheSword:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.DiebytheSword.known and wan.spellData.DiebytheSword.id
        wan.BlizzardEventHandler(frameDiebytheSword, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameDiebytheSword, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.DiebytheSword.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.DiebytheSword.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDiebytheSword, CheckAbilityValue, abilityActive)
    end
end)
