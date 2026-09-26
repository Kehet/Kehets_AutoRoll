-- Rule model: condition types, operators, item inspection and rule evaluation
local _, ns = ...

local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
local GetDetailedItemLevelInfo = C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
local GetItemClassInfo = C_Item and C_Item.GetItemClassInfo or GetItemClassInfo

ns.ACTIONS = {
    need = { label = "Need", rollType = 1, color = "|cFF33FF33" },
    greed = { label = "Greed", rollType = 2, color = "|cFFFFD100" },
    disenchant = { label = "Disenchant", rollType = 3, color = "|cFFA335EE" },
    pass = { label = "Pass", rollType = 0, color = "|cFF9D9D9D" },
    manual = { label = "Roll manually", color = "|cFFFFFFFF" },
}
ns.ACTION_ORDER = { "need", "greed", "disenchant", "pass", "manual" }

ns.OPERATORS = {
    ["<"] = { label = "less than", test = function(a, b) return a < b end },
    ["<="] = { label = "at most", test = function(a, b) return a <= b end },
    ["=="] = { label = "is", test = function(a, b) return a == b end },
    ["~="] = { label = "is not", test = function(a, b) return a ~= b end },
    [">="] = { label = "at least", test = function(a, b) return a >= b end },
    [">"] = { label = "greater than", test = function(a, b) return a > b end },
    contains = {
        label = "contains",
        test = function(a, b) return a:lower():find(b:lower(), 1, true) ~= nil end,
    },
    notContains = {
        label = "does not contain",
        test = function(a, b) return a:lower():find(b:lower(), 1, true) == nil end,
    },
}

-- Operators offered for each kind of condition value. Boolean conditions have no operator.
ns.OPERATOR_SETS = {
    number = { "<", "<=", "==", "~=", ">=", ">" },
    quality = { "<", "<=", "==", "~=", ">=", ">" },
    select = { "==", "~=" },
    text = { "contains", "notContains" },
}

local ITEM_CLASSES = { 0, 1, 2, 3, 4, 7, 9, 12, 15, 16, 17 }

local function ItemClassValues()
    local values = {}
    for _, classID in ipairs(ITEM_CLASSES) do
        local name = GetItemClassInfo(classID)
        if name then
            values[classID] = name
        end
    end
    return values
end

local function QualityValues()
    local values = {}
    for quality = 0, 7 do
        local color = ITEM_QUALITY_COLORS[quality]
        local name = _G["ITEM_QUALITY" .. quality .. "_DESC"]
        if color and name then
            values[quality] = color.hex .. name .. "|r"
        end
    end
    return values
end

ns.CONDITIONS = {
    canNeed = {
        label = "Can roll Need",
        desc = "Need is not available when your class cannot use the item.",
        kind = "boolean",
        default = false,
    },
    canGreed = { label = "Can roll Greed", kind = "boolean", default = false },
    canDisenchant = {
        label = "Can roll Disenchant",
        desc = "Needs an enchanter with enough skill in the group.",
        kind = "boolean",
        default = true,
    },
    bindOnPickup = { label = "Binds when picked up", kind = "boolean", default = true },
    ownArmorType = {
        label = "Your armor type",
        desc = "Cloth, leather, mail or plate gear of the heaviest armor type your character has learned, for example mail for a shaman."
            .. " Never matches items without an armor type, such as rings, necks, trinkets, cloaks, shields and off-hands.",
        kind = "boolean",
        default = false,
    },
    equippable = {
        label = "You can equip",
        desc = "Gear that your character can wear now. Gear with red text in its tooltip, such as the wrong armor type,"
            .. " weapon type, class or level, counts as No. Items that are not gear, and bags, also count as No.",
        kind = "boolean",
        default = true,
    },
    itemLevel = { label = "Item level", kind = "number", op = "<", default = 0 },
    equippedDiff = {
        label = "Item level vs equipped",
        desc = "The item level minus the item level you wear in that slot. Below 0 means the item is worse than what you wear."
            .. " For rings, trinkets and one-handed weapons the weaker of the two slots is used. An empty slot counts as item level 0."
            .. " Never matches items that cannot be equipped.",
        kind = "number",
        op = "<",
        default = 0,
    },
    quality = { label = "Quality", kind = "quality", op = ">=", default = 4, values = QualityValues },
    itemClass = { label = "Item type", kind = "select", op = "==", default = 4, values = ItemClassValues },
    name = { label = "Name", kind = "text", op = "contains", default = "" },
}
ns.CONDITION_ORDER = {
    "canNeed", "canGreed", "canDisenchant", "bindOnPickup", "equippable", "ownArmorType",
    "itemLevel", "equippedDiff", "quality", "itemClass", "name",
}

ns.DEFAULT_RULES = {
    {
        name = "Cannot need",
        enabled = true,
        action = "greed",
        conditions = { { type = "canNeed", value = false } },
    },
    {
        name = "Not equippable armor",
        enabled = true,
        action = "greed",
        conditions = {
            { type = "itemClass", op = "==", value = 4 },
            { type = "ownArmorType", value = false },
        },
    },
    {
        name = "Not equippable weapon",
        enabled = true,
        action = "greed",
        conditions = {
            { type = "itemClass", op = "==", value = 2 },
            { type = "equippable", value = false },
        },
    },
}

function ns.NewCondition(conditionType)
    local condition = {}
    ns.ResetCondition(condition, conditionType or "itemLevel")
    return condition
end

-- Change the type of a condition and reset its operator and value to fit the new type
function ns.ResetCondition(condition, conditionType)
    local def = ns.CONDITIONS[conditionType]
    condition.type = conditionType
    condition.op = def.op
    condition.value = def.default
end

-- Inventory slots each equip location can go to
local EQUIP_SLOTS = {
    INVTYPE_HEAD = { INVSLOT_HEAD },
    INVTYPE_NECK = { INVSLOT_NECK },
    INVTYPE_SHOULDER = { INVSLOT_SHOULDER },
    INVTYPE_BODY = { INVSLOT_BODY },
    INVTYPE_CHEST = { INVSLOT_CHEST },
    INVTYPE_ROBE = { INVSLOT_CHEST },
    INVTYPE_WAIST = { INVSLOT_WAIST },
    INVTYPE_LEGS = { INVSLOT_LEGS },
    INVTYPE_FEET = { INVSLOT_FEET },
    INVTYPE_WRIST = { INVSLOT_WRIST },
    INVTYPE_HAND = { INVSLOT_HAND },
    INVTYPE_FINGER = { INVSLOT_FINGER1, INVSLOT_FINGER2 },
    INVTYPE_TRINKET = { INVSLOT_TRINKET1, INVSLOT_TRINKET2 },
    INVTYPE_CLOAK = { INVSLOT_BACK },
    INVTYPE_WEAPON = { INVSLOT_MAINHAND, INVSLOT_OFFHAND },
    INVTYPE_2HWEAPON = { INVSLOT_MAINHAND },
    INVTYPE_WEAPONMAINHAND = { INVSLOT_MAINHAND },
    INVTYPE_WEAPONOFFHAND = { INVSLOT_OFFHAND },
    INVTYPE_SHIELD = { INVSLOT_OFFHAND },
    INVTYPE_HOLDABLE = { INVSLOT_OFFHAND },
    -- Mists of Pandaria moved ranged weapons to the main hand
    INVTYPE_RANGED = { INVSLOT_MAINHAND },
    INVTYPE_RANGEDRIGHT = { INVSLOT_MAINHAND },
    INVTYPE_THROWN = { INVSLOT_MAINHAND },
    INVTYPE_TABARD = { INVSLOT_TABARD },
}

local TWO_HANDED = {
    INVTYPE_2HWEAPON = true,
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
}

local SCAN_TOOLTIP_NAME = "KehetsAutoRollScanTooltip"
local scanTooltip

-- Hidden tooltip for reading what the game shows about an item
local function GetScanTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", SCAN_TOOLTIP_NAME, nil, "GameTooltipTemplate")
    end
    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    return scanTooltip
end

-- The "Item Level N" line of a worn item's tooltip, which shows the scaled level of heirlooms
local function GetTooltipItemLevel(slot)
    if not ITEM_LEVEL then
        return nil
    end
    local pattern = "^" .. ITEM_LEVEL:gsub("%%d", "(%%d+)")
    local tooltip = GetScanTooltip()
    tooltip:SetInventoryItem("player", slot)
    for lineIndex = 1, tooltip:NumLines() do
        local line = _G[SCAN_TOOLTIP_NAME .. "TextLeft" .. lineIndex]
        local level = line and line:GetText() and line:GetText():match(pattern)
        if level then
            return tonumber(level)
        end
    end
end

-- Item level and link of the item worn in a slot. An empty slot is item level 0.
-- Heirloom links can report the base level 1, so the level the game shows is tried first.
local function GetSlotItemLevel(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then
        return 0
    end

    if C_Item and C_Item.GetCurrentItemLevel and ItemLocation and ItemLocation.CreateFromEquipmentSlot then
        local level = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slot))
        if level and level > 1 then
            return level, link
        end
    end

    local level = GetDetailedItemLevelInfo(link) or 0
    if level <= 1 then
        level = GetTooltipItemLevel(slot) or level
    end
    return level, link
end

local function IsTwoHandEquipped()
    local link = GetInventoryItemLink("player", INVSLOT_MAINHAND)
    if not link then
        return false
    end
    local _, _, _, equipLoc = GetItemInfoInstant(link)
    return TWO_HANDED[equipLoc] == true
end

-- Item level and link of the weakest item worn in the slots this equip location fits, or nil if it cannot be equipped
function ns.GetEquippedItemLevel(equipLoc)
    local slots = EQUIP_SLOTS[equipLoc]
    if not slots then
        return nil
    end

    local lowest, lowestLink
    for _, slot in ipairs(slots) do
        local level, link
        if slot == INVSLOT_OFFHAND and not GetInventoryItemLink("player", slot) and IsTwoHandEquipped() then
            -- A two-hander fills the empty off hand too
            level, link = GetSlotItemLevel(INVSLOT_MAINHAND)
        else
            level, link = GetSlotItemLevel(slot)
        end
        if not lowest or level < lowest then
            lowest, lowestLink = level, link
        end
    end
    return lowest, lowestLink
end

-- The game colors requirements the character does not meet red in the tooltip:
-- armor or weapon type, class, level, profession. That is the most reliable "can I use this" check.
function ns.HasRedText(link)
    local scanTooltip = GetScanTooltip()
    scanTooltip:SetHyperlink(link)

    for lineIndex = 1, scanTooltip:NumLines() do
        for _, side in ipairs({ "Left", "Right" }) do
            local line = _G[SCAN_TOOLTIP_NAME .. "Text" .. side .. lineIndex]
            if line and line:IsShown() and line:GetText() then
                local r, g, b = line:GetTextColor()
                if r > 0.99 and g < 0.2 and b < 0.2 then
                    return true
                end
            end
        end
    end
    return false
end

local ARMOR_CLASS = 4
local ARMOR_TYPES = { cloth = 1, leather = 2, mail = 3, plate = 4 }

-- Armor proficiency spells, heaviest first
local ARMOR_SPELLS = {
    { spellID = 750, armorType = ARMOR_TYPES.plate },
    { spellID = 8737, armorType = ARMOR_TYPES.mail },
    { spellID = 9077, armorType = ARMOR_TYPES.leather },
}

-- Used if the proficiency spells cannot be read
local CLASS_ARMOR_TYPES = {
    WARRIOR = ARMOR_TYPES.plate,
    PALADIN = ARMOR_TYPES.plate,
    DEATHKNIGHT = ARMOR_TYPES.plate,
    HUNTER = ARMOR_TYPES.mail,
    SHAMAN = ARMOR_TYPES.mail,
    ROGUE = ARMOR_TYPES.leather,
    DRUID = ARMOR_TYPES.leather,
    MONK = ARMOR_TYPES.leather,
}

-- Heaviest armor type the character has learned. Checked each time, because it can change with level.
function ns.GetOwnArmorType()
    if IsPlayerSpell then
        for _, proficiency in ipairs(ARMOR_SPELLS) do
            if IsPlayerSpell(proficiency.spellID) then
                return proficiency.armorType
            end
        end
    end
    local _, class = UnitClass("player")
    return CLASS_ARMOR_TYPES[class] or ARMOR_TYPES.cloth
end

-- True or false for cloth, leather, mail and plate gear, nil for everything else. Cloaks are cloth for every class.
local function IsOwnArmorType(classID, subclassID, equipLoc)
    if classID ~= ARMOR_CLASS or equipLoc == "INVTYPE_CLOAK" then
        return nil
    end
    if not subclassID or subclassID < ARMOR_TYPES.cloth or subclassID > ARMOR_TYPES.plate then
        return nil
    end
    return subclassID == ns.GetOwnArmorType()
end

-- Call back once the item data is in the client cache, so item level and name are known
function ns.WhenItemLoaded(link, callback)
    if Item and Item.CreateFromItemLink then
        local item = Item:CreateFromItemLink(link)
        if not item:IsItemEmpty() then
            item:ContinueOnItemLoad(callback)
            return
        end
    end
    callback()
end

-- Collect the facts rules are tested against. roll holds what the loot roll reports.
function ns.DescribeItem(link, roll)
    local name, _, quality, _, _, _, _, _, _, _, _, _, _, bindType = GetItemInfo(link)
    local _, _, _, equipLoc, _, classID, subclassID = GetItemInfoInstant(link)
    local itemLevel = GetDetailedItemLevelInfo(link)
    local equippedLevel, equippedLink = ns.GetEquippedItemLevel(equipLoc)

    local item = {
        link = link,
        name = roll.name or name,
        quality = roll.quality or quality,
        bindOnPickup = roll.bindOnPickup,
        canNeed = roll.canNeed,
        canGreed = roll.canGreed,
        canDisenchant = roll.canDisenchant,
        itemClass = classID,
        equippable = EQUIP_SLOTS[equipLoc] ~= nil and not ns.HasRedText(link),
        ownArmorType = IsOwnArmorType(classID, subclassID, equipLoc),
        itemLevel = itemLevel,
        equippedLevel = equippedLevel,
        equippedLink = equippedLink,
    }
    if item.bindOnPickup == nil then
        item.bindOnPickup = bindType == 1
    end
    if itemLevel and equippedLevel then
        item.equippedDiff = itemLevel - equippedLevel
    end
    return item
end

function ns.ConditionMatches(condition, item)
    local def = ns.CONDITIONS[condition.type]
    local actual = item[condition.type]
    if not def or actual == nil then
        return false
    end

    if def.kind == "boolean" then
        return actual == condition.value
    end

    local operator = ns.OPERATORS[condition.op]
    if not operator or condition.value == nil then
        return false
    end
    return operator.test(actual, condition.value)
end

-- A rule matches when every condition does. A rule without conditions matches every item.
function ns.RuleMatches(rule, item)
    for _, condition in ipairs(rule.conditions) do
        if not ns.ConditionMatches(condition, item) then
            return false
        end
    end
    return true
end

function ns.IsActionAvailable(action, item)
    if action == "need" then
        return item.canNeed
    elseif action == "greed" then
        return item.canGreed
    elseif action == "disenchant" then
        return item.canDisenchant
    end
    return ns.ACTIONS[action] ~= nil
end

local function YesNo(value)
    if value == nil then
        return "?"
    end
    return value and "yes" or "no"
end

-- One line with the facts the rules saw, for finding out why a rule did or did not match
function ns.DescribeFacts(item)
    local equipped = "not equippable"
    if item.equippedLevel then
        equipped = string.format("equipped %s %d (%+d)",
            item.equippedLink or "nothing", item.equippedLevel, item.equippedDiff or 0)
    end
    return string.format("Need %s, Greed %s, Disenchant %s, you can equip %s, your armor type %s, item level %s, %s, binds on pickup %s",
        YesNo(item.canNeed), YesNo(item.canGreed), YesNo(item.canDisenchant), YesNo(item.equippable), YesNo(item.ownArmorType),
        tostring(item.itemLevel or "?"), equipped, YesNo(item.bindOnPickup))
end

-- Why a rule does not decide the roll for this item, or nil if it does
function ns.ExplainRule(rule, item)
    if not rule.enabled then
        return "disabled"
    end
    for _, condition in ipairs(rule.conditions) do
        if not ns.ConditionMatches(condition, item) then
            return "no match: " .. ns.DescribeCondition(condition)
        end
    end
    if not ns.IsActionAvailable(rule.action, item) then
        local action = ns.ACTIONS[rule.action]
        return (action and action.label or tostring(rule.action)) .. " is not available for this item"
    end
end

-- First enabled rule that matches and whose roll is available wins
function ns.Evaluate(rules, item)
    for index, rule in ipairs(rules) do
        if rule.enabled and ns.RuleMatches(rule, item) and ns.IsActionAvailable(rule.action, item) then
            return rule, index
        end
    end
end

local function FormatValue(condition, def)
    if def.kind == "text" then
        return '"' .. tostring(condition.value) .. '"'
    elseif def.values then
        return def.values()[condition.value] or tostring(condition.value)
    end
    return tostring(condition.value)
end

function ns.DescribeCondition(condition)
    local def = ns.CONDITIONS[condition.type]
    if not def then
        return "unknown condition"
    end
    if def.kind == "boolean" then
        return def.label .. " is " .. (condition.value and "Yes" or "No")
    end
    local operator = ns.OPERATORS[condition.op]
    return def.label .. " " .. (operator and operator.label or "?") .. " " .. FormatValue(condition, def)
end

function ns.DescribeRule(rule)
    local action = ns.ACTIONS[rule.action]
    local actionText = action and (action.color .. action.label .. "|r") or "?"
    if #rule.conditions == 0 then
        return "Always " .. actionText
    end

    local parts = {}
    for _, condition in ipairs(rule.conditions) do
        table.insert(parts, ns.DescribeCondition(condition))
    end
    return "If " .. table.concat(parts, " and ") .. ", then " .. actionText
end
