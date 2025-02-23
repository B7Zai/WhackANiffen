local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nMassBarrier = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.auraData.player.buff_IceBlock
        or wan.auraData.player.buff_PrismaticBarrier
        or wan.auraData.player.buff_BlazingBarrier
        or wan.auraData.player.buff_IceBarrier
        or wan.auraData.player["buff_" .. wan.spellData.Invisibility.formattedName]
        or wan.auraData.player.buff_MassInvisibility
        or not wan.IsSpellUsable(wan.spellData.MassBarrier.id)
    then
        wan.UpdateMechanicData(wan.spellData.MassBarrier.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cMassBarrier = nMassBarrier

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cMassBarrier, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.MassBarrier.basename, abilityValue, wan.spellData.MassBarrier.icon, wan.spellData.MassBarrier.name)
end

-- Init frame 
local frameMassBarrier = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nMassBarrier = wan.DefensiveCooldownToValue(wan.spellData.MassBarrier.id)
        end
    end)
end
frameMassBarrier:RegisterEvent("ADDON_LOADED")
frameMassBarrier:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.MassBarrier.known and wan.spellData.MassBarrier.id
        wan.BlizzardEventHandler(frameMassBarrier, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameMassBarrier, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.MassBarrier.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.MassBarrier.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMassBarrier, CheckAbilityValue, abilityActive)
    end
end)
