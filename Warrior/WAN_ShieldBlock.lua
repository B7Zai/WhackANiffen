local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nShieldBlock = 0

-- Init trait data

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ShieldBlock.id)
    then
        wan.UpdateMechanicData(wan.spellData.ShieldBlock.basename)
        return
    end

    local cShieldBlock = 0

    local currentTime = GetTime()
    local isTanking = wan.IsTanking()
    local checkShieldBlockBuff = wan.CheckUnitBuff(nil, wan.spellData.ShieldBlock.formattedName)
    local cShieldBlockExpiration = checkShieldBlockBuff and checkShieldBlockBuff.expirationTime - currentTime or 0
    if isTanking and (not checkShieldBlockBuff or cShieldBlockExpiration < 1.2) then
        cShieldBlock = cShieldBlock + nShieldBlock
    end

    local abilityValue = math.floor(cShieldBlock)
    wan.UpdateMechanicData(wan.spellData.ShieldBlock.basename, abilityValue, wan.spellData.ShieldBlock.icon, wan.spellData.ShieldBlock.name)
end


local frameShieldBlock = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            nShieldBlock = wan.AbilityPercentageToValue(10)
        end
    end)
end
frameShieldBlock:RegisterEvent("ADDON_LOADED")
frameShieldBlock:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ShieldBlock.known and wan.spellData.ShieldBlock.id
        wan.BlizzardEventHandler(frameShieldBlock, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameShieldBlock, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameShieldBlock, CheckAbilityValue, abilityActive)
    end
end)
