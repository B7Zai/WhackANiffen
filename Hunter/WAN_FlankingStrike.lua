local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nFlankingStrike = 0

-- Init trait data
local nHowlOfThePack = 0


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.FlankingStrike.id)
    then
        wan.UpdateAbilityData(wan.spellData.FlankingStrike.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.FlankingStrike.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.FlankingStrike.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cFlankingStrikeInstantDmg = 0
    local cFlankingStrikeDotDmg = 0
    local cFlankingStrikeInstantDmgAoE = 0
    local cFlankingStrikeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- PACK LEADER TRAITS ----

    if wan.traitData.HowlofthePack.known then
        local checkHowlOfThePackBuff = wan.auraData.player["buff_" .. wan.traitData.HowlofthePack.traitkey]
        if checkHowlOfThePackBuff then
            local stacksHowlOfThePack = checkHowlOfThePackBuff.applications
            critDamageMod = critDamageMod + (nHowlOfThePack * stacksHowlOfThePack)
        end
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cFlankingStrikeCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cFlankingStrikeInstantDmg = cFlankingStrikeInstantDmg + (nFlankingStrike * checkPhysicalDR * cFlankingStrikeCritValue)
    cFlankingStrikeDotDmg = cFlankingStrikeDotDmg
    cFlankingStrikeInstantDmgAoE = cFlankingStrikeInstantDmgAoE
    cFlankingStrikeDotDmgAoE = cFlankingStrikeDotDmgAoE

    local cFlankingStrikeDmg = cFlankingStrikeInstantDmg + cFlankingStrikeDotDmg + cFlankingStrikeInstantDmgAoE + cFlankingStrikeDotDmgAoE
    local cdPotency = wan.CheckOffensiveCooldownPotency(cFlankingStrikeDmg, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cFlankingStrikeDmg) or 0
    wan.UpdateAbilityData(wan.spellData.FlankingStrike.basename, abilityValue, wan.spellData.FlankingStrike.icon, wan.spellData.FlankingStrike.name)
end

-- Init frame 
local frameFlankingStrike = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nFlankingStrike = wan.GetSpellDescriptionNumbers(wan.spellData.FlankingStrike.id, { 1 })
        end
    end)
end
frameFlankingStrike:RegisterEvent("ADDON_LOADED")
frameFlankingStrike:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FlankingStrike.known and wan.spellData.FlankingStrike.id
        wan.BlizzardEventHandler(frameFlankingStrike, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFlankingStrike, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nHowlOfThePack = wan.GetTraitDescriptionNumbers(wan.traitData.HowlofthePack.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFlankingStrike, CheckAbilityValue, abilityActive)
    end
end)