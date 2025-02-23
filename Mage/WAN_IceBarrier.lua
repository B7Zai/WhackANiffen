local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nIceBarrier = 0

-- Init trait data


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or (wan.PlayerState.Resting and not wan.PlayerState.Combat)
        or not wan.IsSpellUsable(wan.spellData.IceBarrier.id)
    then
        wan.UpdateMechanicData(wan.spellData.IceBarrier.basename)
        return
    end

    local formattedBuffName = wan.spellData.IceBarrier.basename
    local checkIceBarrierBuff = wan.CheckUnitBuff(nil, formattedBuffName)
    local bIceBarrierDesaturation = false
    if checkIceBarrierBuff then
        local checkTime = GetTime()
        local nBarrierDurationThreshold = checkIceBarrierBuff.duration / 4
        local nBarrierRemainingTime = checkIceBarrierBuff.expirationTime - checkTime
        if nBarrierRemainingTime > nBarrierDurationThreshold then
            wan.UpdateMechanicData(wan.spellData.IceBarrier.basename)
            return
        end

        bIceBarrierDesaturation = true
    end

    -- Base values
    local cBarrier = nIceBarrier

    local nAbilityValue = math.floor(cBarrier)

    wan.UpdateMechanicData(wan.spellData.IceBarrier.basename, nAbilityValue, wan.spellData.IceBarrier.icon, wan.spellData.IceBarrier.name, bIceBarrierDesaturation)
end


local frameIceBarrier = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            nIceBarrier = wan.GetSpellDescriptionNumbers(wan.spellData.IceBarrier.id, { 1 })

        end
    end)
end
frameIceBarrier:RegisterEvent("ADDON_LOADED")
frameIceBarrier:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.IceBarrier.known and wan.spellData.IceBarrier.id
        wan.BlizzardEventHandler(frameIceBarrier, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameIceBarrier, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameIceBarrier, CheckAbilityValue, abilityActive)
    end
end)
