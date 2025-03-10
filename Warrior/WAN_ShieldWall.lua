local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nShieldWall = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.ShieldWall.id)
    then
        wan.UpdateMechanicData(wan.spellData.ShieldWall.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cShieldWall = nShieldWall

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cShieldWall, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.ShieldWall.basename, abilityValue, wan.spellData.ShieldWall.icon, wan.spellData.ShieldWall.name)
end

-- Init frame 
local frameShieldWall = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nShieldWall = wan.DefensiveCooldownToValue(wan.spellData.ShieldWall.id, 180000)
        end
    end)
end
frameShieldWall:RegisterEvent("ADDON_LOADED")
frameShieldWall:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ShieldWall.known and wan.spellData.ShieldWall.id
        wan.BlizzardEventHandler(frameShieldWall, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameShieldWall, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.ShieldWall.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.ShieldWall.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameShieldWall, CheckAbilityValue, abilityActive)
    end
end)
