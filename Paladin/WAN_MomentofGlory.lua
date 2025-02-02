local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nMomentofGlory = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.auraData.player["buff_" .. wan.spellData.DivineShield.basename]
        or wan.auraData.player["buff_" .. wan.spellData.BlessingofProtection.basename]
        or wan.auraData.player["buff_" .. wan.spellData.GuardianofAncientKings.basename]
        or not wan.IsSpellUsable(wan.spellData.MomentofGlory.id)
    then
        wan.UpdateMechanicData(wan.spellData.MomentofGlory.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cMomentofGlory = nMomentofGlory

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cMomentofGlory, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.MomentofGlory.basename, abilityValue, wan.spellData.MomentofGlory.icon, wan.spellData.MomentofGlory.name)
end

-- Init frame 
local frameMomentofGlory = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nMomentofGlory = wan.DefensiveCooldownToValue(wan.spellData.MomentofGlory.id)
        end
    end)
end
frameMomentofGlory:RegisterEvent("ADDON_LOADED")
frameMomentofGlory:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.MomentofGlory.known and wan.spellData.MomentofGlory.id
        wan.BlizzardEventHandler(frameMomentofGlory, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameMomentofGlory, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.MomentofGlory.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.MomentofGlory.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMomentofGlory, CheckAbilityValue, abilityActive)
    end
end)
