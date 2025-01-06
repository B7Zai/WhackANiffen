local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nKillCommandDmg = 0

-- Init trait data
local nGoForTheThroat = 0
local nKillCleave = 0
local nAMurderOfCrows, nAMurderOfCrowsStacks, nAMurderofCrownsStacksCap = 0, 0, 0
local nKillerInstinct, nKillerInstinctThreshold = 0, 0
local nBloodshed = 0
local nVenomousBite = 0
local nViciousHunt = 0
local nFrenziedTear = 0
local nPhantomPain = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsPetUsable()
    or not wan.IsSpellUsable(wan.spellData.KillCommand.id)
    then
        wan.UpdateAbilityData(wan.spellData.KillCommand.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, _ ,idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.KillCommand.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.KillCommand.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cKillCommandInstantDmg = nKillCommandDmg
    local cKillCommandDotDmg = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    -- animal companion trait layer
    local cAnimalCompanion = 1
    if wan.traitData.AnimalCompanion.known then
        cAnimalCompanion = cAnimalCompanion * 2
    end

    -- go for the throat trait layer
    if wan.traitData.GofortheThroat.known then
        local cGoForTheThroat = nGoForTheThroat
        critDamageMod = critDamageMod + (wan.CritChance * cGoForTheThroat)
    end

    -- a murder of crows trait layer
    local cAMurderOfCrows = 0
    if wan.traitData.AMurderofCrows.known and wan.auraData.player.buff_AMurderofCrows then
        local cAMurderofCrownsStacks = wan.auraData.player.buff_AMurderofCrows.applications

        if cAMurderofCrownsStacks == nAMurderofCrownsStacksCap then
            cAMurderOfCrows = cAMurderOfCrows + nAMurderOfCrows
        end
    end

    -- killec instinct trait layer
    local cKillerInstinct = 1
    if wan.traitData.cKillerInstinct.known then
        local targetPercentHealth = UnitPercentHealthFromGUID(targetGUID) or 1

        if nKillerInstinctThreshold > targetPercentHealth then
            cKillerInstinct = cKillerInstinct + nKillerInstinct
        end
    end

    -- bloodshed trait layer
    local cBloodshed = 1
    if wan.traitData.Bloodshed.known then
        local checkBloodshedDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.traitData.Bloodshed.traitkey]

        if checkBloodshedDebuff then
            cBloodshed = cBloodshed + nBloodshed
        end

        -- venomous bite trait layer
        if wan.traitData.VenomousBite.known then
            cBloodshed = cBloodshed + nVenomousBite
        end
    end

    -- vicious hunt trait layer
    local cViciousHunt = 0
    if wan.traitData.ViciousHunt.known and wan.auraData.player["buff_" .. wan.traitData.ViciousHunt.traitkey] then
        cViciousHunt = cViciousHunt + nViciousHunt
    end

    -- frenzied tear trait layer
    local cFrenziedTear = 1
    if wan.traitData.FrenziedTear.known and wan.auraData.player["buff_" .. wan.traitData.FrenziedTear.traitkey] then
        cFrenziedTear = cFrenziedTear + nFrenziedTear
    end

    local cKillCommandInstantAoEDmg = 0
    local countPhantomPain = 0
    if wan.traitData.KillCleave.known or wan.traitData.PhantomPain.known then

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                if wan.auraData.player.buff_BeastCleave then
                    
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    local cUnitKillerInstinct = 1
                    if wan.traitData.cKillerInstinct.known then
                        local targetPercentHealth = UnitPercentHealthFromGUID(nameplateGUID) or 1

                        if nKillerInstinctThreshold > targetPercentHealth then
                            cUnitKillerInstinct = cUnitKillerInstinct + nKillerInstinct
                        end
                    end

                    local cUnitBloodshed = 1
                    if wan.traitData.ShowerofBlood.known then
                        local checkBloodshedDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.traitData.Bloodshed.traitkey]

                        if checkBloodshedDebuff then
                            cUnitBloodshed = cUnitBloodshed + nBloodshed
                        end
                    end

                    local cKillCleaveDmg = nKillCommandDmg * cAnimalCompanion * nKillCleave * checkUnitPhysicalDR * cUnitKillerInstinct * cUnitBloodshed

                    cKillCommandInstantAoEDmg = cKillCommandInstantAoEDmg + cKillCleaveDmg
                end

                if wan.traitData.PhantomPain.known then
                    local checkUnitBlackArrowDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.traitData.BlackArrow.traitkey]
                    if checkUnitBlackArrowDebuff then
                        countPhantomPain = countPhantomPain + 1
                    end
                end
            end
        end
    end

    -- Remove physical layer
    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()

    -- Crit layer
    local cKillCommandCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cKillCommandDotCritValue = wan.ValueFromCritical(wan.CritChance)

    cKillCommandInstantDmg = ((cKillCommandInstantDmg * cKillCommandCritValue * cKillerInstinct * cBloodshed) + (cViciousHunt * cKillCommandDotCritValue)) * checkPhysicalDR
    cKillCommandDotDmg = (cKillCommandDotDmg + cAMurderOfCrows) * checkPhysicalDR * cKillCommandDotCritValue

    local cPhantomPain = 0
    if wan.traitData.PhantomPain.known then
        local checkBlackArrowDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.traitData.BlackArrow.traitkey]
        if checkBlackArrowDebuff then
            cPhantomPain = cPhantomPain + (cKillCommandInstantDmg * nPhantomPain * countPhantomPain)
        end
    end

    cKillCommandInstantAoEDmg = (cKillCommandInstantAoEDmg * cFrenziedTear * cKillCommandCritValue) + cPhantomPain

    local cKillCommandDmg = cKillCommandInstantDmg + cKillCommandDotDmg + cKillCommandInstantAoEDmg

    -- Update ability data
    local abilityValue = math.floor(cKillCommandDmg)
    wan.UpdateAbilityData(wan.spellData.KillCommand.basename, abilityValue, wan.spellData.KillCommand.icon, wan.spellData.KillCommand.name)
end

-- Init frame 
local frameKillCommand = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nKillCommandDmg = wan.GetSpellDescriptionNumbers(wan.spellData.KillCommand.id, { 1 })

            local nAMurderOfCrowsValues = wan.GetTraitDescriptionNumbers(wan.traitData.AMurderofCrows.entryid, { 1, 2 })
            nAMurderOfCrowsStacks = nAMurderOfCrowsValues[1]
            nAMurderofCrownsStacksCap = math.max((nAMurderOfCrowsStacks - 1), 0)
            nAMurderOfCrows = nAMurderOfCrowsValues[2]

            nViciousHunt = wan.GetTraitDescriptionNumbers(wan.traitData.ViciousHunt.entryid, { 1 })
        end
    end)
end
frameKillCommand:RegisterEvent("ADDON_LOADED")
frameKillCommand:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.KillCommand.known and wan.spellData.KillCommand.id
        wan.BlizzardEventHandler(frameKillCommand, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameKillCommand, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nGoForTheThroat = wan.GetTraitDescriptionNumbers(wan.traitData.GofortheThroat.entryid, { 1 }) * 0.01

        nKillCleave = wan.GetTraitDescriptionNumbers(wan.traitData.BeastCleave.entryid, { 1 }) * 0.01

        local nKillerInstinctValues = wan.GetTraitDescriptionNumbers(wan.traitData.KillerInstinct.entryid, { 1, 2 }, wan.traitData.KillerInstinct.rank)
        nKillerInstinct = nKillerInstinctValues[1] * 0.01
        nKillerInstinctThreshold = nKillerInstinctValues[2] * 0.01

        nBloodshed = wan.GetTraitDescriptionNumbers(wan.traitData.Bloodshed.entryid, { 3 }) * 0.01

        nVenomousBite = wan.GetTraitDescriptionNumbers(wan.traitData.VenomousBite.entryid, { 1 }) * 0.01

        nFrenziedTear = wan.GetTraitDescriptionNumbers(wan.traitData.FrenziedTear.entryid, { 1 }) * 0.01

        nPhantomPain = wan.GetTraitDescriptionNumbers(wan.traitData.PhantomPain.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameKillCommand, CheckAbilityValue, abilityActive)
    end
end)