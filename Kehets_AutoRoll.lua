local _, ns = ...

local AutoRoll = LibStub("AceAddon-3.0"):NewAddon("Kehet's AutoRoll", "AceConsole-3.0", "AceEvent-3.0")
ns.AutoRoll = AutoRoll

-- Rules are not part of the AceDB defaults: AceDB merges default tables back in on every load,
-- which would bring back rules the user deleted. They are seeded by EnsureRules instead.
local defaultSavedVariables = {
    profile = {
        enabled = true,
        announce = true,
        autoConfirm = true,
        autoConfirmDisenchant = true,
        dryRun = false,
        debug = false,
    },
}

-- Rolls this addon made, so only their bind-on-pickup and disenchant confirmations are accepted automatically
local pendingRolls = {}

function AutoRoll:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("KehetsAutoRollDB", defaultSavedVariables, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileUpdated")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileUpdated")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileUpdated")
    self:EnsureRules()

    self:SetupOptions()

    self:RegisterChatCommand("autoroll", "HandleSlashCommand")
    self:RegisterChatCommand("kar", "HandleSlashCommand")
end

function AutoRoll:OnEnable()
    self:Print("Enabled")
    self:RegisterEvent("START_LOOT_ROLL")
    self:RegisterEvent("CONFIRM_LOOT_ROLL")
    self:RegisterEvent("CANCEL_LOOT_ROLL")
end

function AutoRoll:EnsureRules()
    if not self.db.profile.rules then
        self.db.profile.rules = CopyTable(ns.DEFAULT_RULES)
    end
    ns.MigrateRules(self.db.profile.rules)
end

function AutoRoll:OnProfileUpdated()
    self:EnsureRules()
    self:RefreshOptions()
end

function AutoRoll:START_LOOT_ROLL(event, rollID)
    if not self.db.profile.enabled then
        return
    end

    local link = GetLootRollItemLink(rollID)
    if not link then
        return
    end

    local _, name, _, quality, bindOnPickup, canNeed, canGreed, canDisenchant = GetLootRollItemInfo(rollID)
    local roll = {
        name = name,
        quality = quality,
        bindOnPickup = bindOnPickup and true or false,
        canNeed = canNeed and true or false,
        canGreed = canGreed and true or false,
        canDisenchant = canDisenchant and true or false,
    }

    ns.WhenItemLoaded(link, function()
        self:HandleRoll(rollID, ns.DescribeItem(link, roll))
    end)
end

function AutoRoll:HandleRoll(rollID, item)
    local rule, index = ns.Evaluate(self.db.profile.rules, item)
    if not rule then
        self:Announce("No rule matched " .. item.link .. ", roll manually")
        if self.db.profile.debug then
            self:ExplainRules(item)
        end
        return
    end

    local action = ns.ACTIONS[rule.action]
    self:Announce(string.format("%s%s|r %s (rule %d: %s)", action.color, action.label, item.link, index, rule.name))

    if action.rollType and not self.db.profile.dryRun then
        pendingRolls[rollID] = true
        RollOnLoot(rollID, action.rollType)
    end
end

-- Why each rule did not match, printed as debug output after "No rule matched"
function AutoRoll:ExplainRules(item)
    local rolls, details = ns.DescribeFacts(item)
    self:Debug(item.link .. ": " .. rolls)
    self:Debug("  " .. details)
    for index, rule in ipairs(self.db.profile.rules) do
        self:Debug(string.format("  %d. %s: %s", index, rule.name, ns.ExplainRule(rule, item) or "matches"))
    end
end

-- Rolls that need confirmation, such as on bind-on-pickup items, ask here. Mists of Pandaria Classic
-- has no separate disenchant event, so a Disenchant roll is told apart by its roll type.
function AutoRoll:CONFIRM_LOOT_ROLL(event, rollID, rollType)
    if not pendingRolls[rollID] then
        return
    end

    local confirm = self.db.profile.autoConfirm
    if rollType == ns.ACTIONS.disenchant.rollType then
        confirm = self.db.profile.autoConfirmDisenchant
    end
    if not confirm then
        return
    end

    ConfirmLootRoll(rollID, rollType)
    StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID)
end

function AutoRoll:CANCEL_LOOT_ROLL(event, rollID)
    pendingRolls[rollID] = nil
end

-- Dry run always prints, since chat is the only place it shows what it would have done
function AutoRoll:Announce(message)
    if self.db.profile.dryRun then
        self:Print("|cFF9D9D9D[Dry run]|r " .. message)
    elseif self.db.profile.announce then
        self:Print(message)
    end
end

-- Debug output prints whenever debug is on, also when Print rolls to chat is off
function AutoRoll:Debug(message)
    self:Print("|cFF66B2FF[Debug]|r " .. message)
end

-- Show which rule would handle an item, assuming every roll type is available
function AutoRoll:TestItem(link)
    if not link or not link:find("|Hitem:") then
        self:Print("Usage: /autoroll test <shift-click an item>")
        return
    end

    ns.WhenItemLoaded(link, function()
        local item = ns.DescribeItem(link, { canNeed = true, canGreed = true, canDisenchant = true })
        local rule, index = ns.Evaluate(self.db.profile.rules, item)

        local rolls, details = ns.DescribeFacts(item)
        self:Print(link .. ": " .. rolls)
        self:Print("  " .. details)
        if rule then
            local action = ns.ACTIONS[rule.action]
            self:Print(string.format("Would %s%s|r (rule %d: %s)", action.color, action.label, index, rule.name))
        else
            self:Print("No rule matches, you would roll manually")
            for ruleIndex, testRule in ipairs(self.db.profile.rules) do
                self:Print(string.format("  %d. %s: %s", ruleIndex, testRule.name, ns.ExplainRule(testRule, item)))
            end
        end
        self:Print("The test assumes Need, Greed and Disenchant are all available.")
    end)
end

function AutoRoll:PrintRules()
    local rules = self.db.profile.rules
    if #rules == 0 then
        self:Print("No rules. Add them with /autoroll config.")
        return
    end
    for index, rule in ipairs(rules) do
        local state = rule.enabled and "" or " |cFF9D9D9D(disabled)|r"
        self:Print(string.format("%d. %s%s: %s", index, rule.name, state, ns.DescribeRule(rule)))
    end
end

function AutoRoll:HandleSlashCommand(input)
    local command, rest = input:match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()

    if command == "" or command == "config" then
        self:OpenOptions()
    elseif command == "on" or command == "off" then
        self.db.profile.enabled = command == "on"
        self:RefreshOptions()
        self:Print(self.db.profile.enabled and "Automatic rolling on." or "Automatic rolling off.")
    elseif command == "dry" then
        self.db.profile.dryRun = not self.db.profile.dryRun
        self:RefreshOptions()
        self:Print(self.db.profile.dryRun and "Dry run on: rolls are printed but not made." or "Dry run off.")
    elseif command == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:RefreshOptions()
        self:Print(self.db.profile.debug and "Debug output on: unmatched rolls show why each rule did not match." or "Debug output off.")
    elseif command == "rules" then
        self:PrintRules()
    elseif command == "test" then
        self:TestItem(rest)
    else
        self:Print("Unknown command.")
        self:Print(" '/autoroll' to open the settings")
        self:Print(" '/autoroll on' or '/autoroll off' to turn automatic rolling on or off")
        self:Print(" '/autoroll dry' to turn dry run on or off")
        self:Print(" '/autoroll debug' to turn debug output on or off")
        self:Print(" '/autoroll rules' to list the rules in chat")
        self:Print(" '/autoroll test <item link>' to see which rule an item would match")
    end
end
