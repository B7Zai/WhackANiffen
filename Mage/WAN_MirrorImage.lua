local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nMirrorImage = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.MirrorImage.id)
    then
        wan.UpdateMechanicData(wan.spellData.MirrorImage.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cMirrorImage = nMirrorImage

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cMirrorImage, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.MirrorImage.basename, abilityValue, wan.spellData.MirrorImage.icon, wan.spellData.MirrorImage.name)
end

-- Init frame 
local frameMirrorImage = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nMirrorImage = wan.DefensiveCooldownToValue(wan.spellData.MirrorImage.id)
        end
    end)
end
frameMirrorImage:RegisterEvent("ADDON_LOADED")
frameMirrorImage:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.MirrorImage.known and wan.spellData.MirrorImage.id
        wan.BlizzardEventHandler(frameMirrorImage, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameMirrorImage, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.MirrorImage.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.MirrorImage.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMirrorImage, CheckAbilityValue, abilityActive)
    end
end)
