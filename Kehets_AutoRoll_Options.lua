-- Settings window: general toggles, the rule editor and AceDB profiles
local _, ns = ...
local AutoRoll = ns.AutoRoll

local APP_NAME = "KehetsAutoRoll"
local DISPLAY_NAME = "Kehet's AutoRoll"

local BOOLEAN_VALUES = { yes = "Yes", no = "No" }
local BOOLEAN_SORTING = { "yes", "no" }

function AutoRoll:RefreshOptions()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(APP_NAME)
end

function AutoRoll:OpenOptions()
    LibStub("AceConfigDialog-3.0"):Open(APP_NAME)
end

local function SelectRule(index)
    LibStub("AceConfigDialog-3.0"):SelectGroup(APP_NAME, "rules", "rule" .. index)
end

local function ActionValues()
    local values = {}
    for key, action in pairs(ns.ACTIONS) do
        values[key] = action.label
    end
    return values
end

local function ConditionTypeValues()
    local values = {}
    for key, def in pairs(ns.CONDITIONS) do
        values[key] = def.label
    end
    return values
end

local function OperatorValues(kind)
    local values = {}
    for _, key in ipairs(ns.OPERATOR_SETS[kind] or {}) do
        values[key] = ns.OPERATORS[key].label
    end
    return values
end

-- The value widget depends on the kind of condition
local function BuildValueOption(condition, def)
    local option = { name = "Value", order = 3, width = 0.9 }

    if def.kind == "boolean" then
        option.type = "select"
        option.values = BOOLEAN_VALUES
        option.sorting = BOOLEAN_SORTING
        option.get = function() return condition.value and "yes" or "no" end
        option.set = function(_, value)
            condition.value = value == "yes"
            AutoRoll:RefreshOptions()
        end
    elseif def.kind == "number" then
        option.type = "input"
        option.get = function() return tostring(condition.value or "") end
        option.set = function(_, value)
            condition.value = tonumber(value)
            AutoRoll:RefreshOptions()
        end
        option.validate = function(_, value)
            return tonumber(value) ~= nil or "Enter a number."
        end
    elseif def.kind == "text" then
        option.type = "input"
        option.get = function() return condition.value or "" end
        option.set = function(_, value)
            condition.value = value
            AutoRoll:RefreshOptions()
        end
    else
        option.type = "select"
        option.values = def.values
        option.get = function() return condition.value end
        option.set = function(_, value)
            condition.value = value
            AutoRoll:RefreshOptions()
        end
    end

    return option
end

local function BuildConditionGroup(rule, conditionIndex)
    local condition = rule.conditions[conditionIndex]
    local def = ns.CONDITIONS[condition.type]
    if not def then
        -- Saved by a newer version or damaged; start over with a known type
        ns.ResetCondition(condition, "itemLevel")
        def = ns.CONDITIONS[condition.type]
    end

    return {
        type = "group",
        inline = true,
        name = "Condition " .. conditionIndex,
        order = 10 + conditionIndex,
        args = {
            type = {
                type = "select",
                name = "Check",
                desc = def.desc,
                order = 1,
                width = 1.1,
                values = ConditionTypeValues,
                sorting = ns.CONDITION_ORDER,
                get = function() return condition.type end,
                set = function(_, value)
                    ns.ResetCondition(condition, value)
                    AutoRoll:RefreshOptions()
                end,
            },
            op = {
                type = "select",
                name = "Comparison",
                order = 2,
                width = 0.8,
                values = OperatorValues(def.kind),
                sorting = ns.OPERATOR_SETS[def.kind],
                hidden = def.kind == "boolean",
                get = function() return condition.op end,
                set = function(_, value)
                    condition.op = value
                    AutoRoll:RefreshOptions()
                end,
            },
            value = BuildValueOption(condition, def),
            remove = {
                type = "execute",
                name = "Remove",
                order = 4,
                width = 0.5,
                func = function()
                    table.remove(rule.conditions, conditionIndex)
                    AutoRoll:RefreshOptions()
                end,
            },
        },
    }
end

local function BuildRuleGroup(rules, index)
    local rule = rules[index]
    local label = index .. ". " .. rule.name
    if not rule.enabled then
        label = "|cFF9D9D9D" .. label .. "|r"
    end

    local group = {
        type = "group",
        name = label,
        order = 10 + index,
        args = {
            summary = {
                type = "description",
                name = ns.DescribeRule(rule),
                fontSize = "medium",
                order = 1,
            },
            enabled = {
                type = "toggle",
                name = "Enabled",
                order = 2,
                width = "full",
                get = function() return rule.enabled end,
                set = function(_, value)
                    rule.enabled = value
                    AutoRoll:RefreshOptions()
                end,
            },
            name = {
                type = "input",
                name = "Name",
                order = 3,
                get = function() return rule.name end,
                set = function(_, value)
                    rule.name = value
                    AutoRoll:RefreshOptions()
                end,
            },
            action = {
                type = "select",
                name = "Roll",
                desc = "If the roll is not available for this item, for example Need on an item your class cannot use, the next rule is tried."
                    .. " Roll manually stops here and leaves the roll to you.",
                order = 4,
                values = ActionValues,
                sorting = ns.ACTION_ORDER,
                get = function() return rule.action end,
                set = function(_, value)
                    rule.action = value
                    AutoRoll:RefreshOptions()
                end,
            },
            conditionsHeader = {
                type = "header",
                name = "Conditions (all must match)",
                order = 10,
            },
            addCondition = {
                type = "execute",
                name = "Add condition",
                order = 100,
                func = function()
                    table.insert(rule.conditions, ns.NewCondition())
                    AutoRoll:RefreshOptions()
                end,
            },
            ruleHeader = {
                type = "header",
                name = "",
                order = 200,
            },
            moveUp = {
                type = "execute",
                name = "Move up",
                order = 201,
                width = 0.7,
                disabled = index == 1,
                func = function()
                    rules[index], rules[index - 1] = rules[index - 1], rules[index]
                    AutoRoll:RefreshOptions()
                    SelectRule(index - 1)
                end,
            },
            moveDown = {
                type = "execute",
                name = "Move down",
                order = 202,
                width = 0.7,
                disabled = index == #rules,
                func = function()
                    rules[index], rules[index + 1] = rules[index + 1], rules[index]
                    AutoRoll:RefreshOptions()
                    SelectRule(index + 1)
                end,
            },
            delete = {
                type = "execute",
                name = "Delete rule",
                order = 203,
                width = 0.7,
                confirm = true,
                confirmText = "Delete the rule \"" .. rule.name .. "\"?",
                func = function()
                    table.remove(rules, index)
                    AutoRoll:RefreshOptions()
                    LibStub("AceConfigDialog-3.0"):SelectGroup(APP_NAME, "rules")
                end,
            },
        },
    }

    if #rule.conditions == 0 then
        group.args.noConditions = {
            type = "description",
            name = "No conditions: this rule matches every item.",
            order = 11,
        }
    end
    for conditionIndex = 1, #rule.conditions do
        group.args["condition" .. conditionIndex] = BuildConditionGroup(rule, conditionIndex)
    end

    return group
end

local function BuildRulesGroup()
    local rules = AutoRoll.db.profile.rules

    local group = {
        type = "group",
        name = "Rules",
        order = 2,
        childGroups = "tree",
        args = {
            help = {
                type = "description",
                name = "When loot drops, the rules are checked from top to bottom. The first enabled rule whose conditions all match"
                    .. " decides the roll. If no rule matches, you roll yourself.\n",
                fontSize = "medium",
                order = 1,
            },
            add = {
                type = "execute",
                name = "Add rule",
                order = 2,
                func = function()
                    table.insert(rules, {
                        name = "New rule",
                        enabled = true,
                        action = "greed",
                        conditions = { ns.NewCondition() },
                    })
                    AutoRoll:RefreshOptions()
                    SelectRule(#rules)
                end,
            },
            resetRules = {
                type = "execute",
                name = "Restore default rules",
                order = 3,
                confirm = true,
                confirmText = "Replace all rules with the default rules?",
                func = function()
                    AutoRoll.db.profile.rules = CopyTable(ns.DEFAULT_RULES)
                    AutoRoll:RefreshOptions()
                end,
            },
        },
    }

    for index = 1, #rules do
        group.args["rule" .. index] = BuildRuleGroup(rules, index)
    end

    return group
end

local function CreateOptionsTable()
    local profile = AutoRoll.db.profile

    return {
        type = "group",
        name = DISPLAY_NAME,
        childGroups = "tab",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Roll automatically",
                        desc = "Roll on group loot with your rules. Same as /autoroll on and /autoroll off.",
                        order = 1,
                        width = "full",
                        get = function() return profile.enabled end,
                        set = function(_, value) profile.enabled = value end,
                    },
                    announce = {
                        type = "toggle",
                        name = "Print rolls to chat",
                        desc = "Print each automatic roll and the rule that made it.",
                        order = 2,
                        width = "full",
                        get = function() return profile.announce end,
                        set = function(_, value) profile.announce = value end,
                    },
                    autoConfirm = {
                        type = "toggle",
                        name = "Confirm bind-on-pickup rolls",
                        desc = "Accept the \"this item will bind to you\" question for rolls this addon makes."
                            .. " Rolls you make yourself still ask.",
                        order = 3,
                        width = "full",
                        get = function() return profile.autoConfirm end,
                        set = function(_, value) profile.autoConfirm = value end,
                    },
                    dryRun = {
                        type = "toggle",
                        name = "Dry run",
                        desc = "Check the rules and print what would be rolled, but do not roll. Same as /autoroll dry.",
                        order = 4,
                        width = "full",
                        get = function() return profile.dryRun end,
                        set = function(_, value) profile.dryRun = value end,
                    },
                },
            },
            rules = BuildRulesGroup(),
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(AutoRoll.db),
        },
    }
end

function AutoRoll:SetupOptions()
    LibStub("AceConfig-3.0"):RegisterOptionsTable(APP_NAME, CreateOptionsTable)
    LibStub("AceConfigDialog-3.0"):SetDefaultSize(APP_NAME, 800, 600)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(APP_NAME, DISPLAY_NAME)
end
