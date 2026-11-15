-- Settings pages in Options > AddOns: general toggles, the rule editor and profiles, built from native
-- frame templates. The message settings are a page of LibKehetsVerbosity-2.0 under the same category.
local _, ns = ...
local AutoRoll = ns.AutoRoll

local DISPLAY_NAME = "Kehet's AutoRoll"

-- The settings canvas is about 665 pixels wide at the default size of the settings panel
local PAGE_WIDTH = 640
local LIST_WIDTH = 170
local EDITOR_WIDTH = 420
local LIST_ROW_HEIGHT = 22
local MENU_MAX_HEIGHT = 400

local BOOLEAN_VALUES = { yes = "Yes", no = "No" }
local BOOLEAN_ORDER = { "yes", "no" }

local pages = {}
local selectedRule -- nil shows the overview with the quick rules

local function ShowTooltip(control)
    if control.tooltip then
        GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
        GameTooltip:SetText(control.tooltipTitle or "", 1, 1, 1)
        GameTooltip:AddLine(control.tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end
end

local function SetTooltip(control, title, text)
    control.tooltipTitle = title
    control.tooltip = text
    if not control.tooltipHooked then
        control.tooltipHooked = true
        control:HookScript("OnEnter", ShowTooltip)
        control:HookScript("OnLeave", GameTooltip_Hide)
    end
end

local CONFIRM_DIALOG = "KEHETS_AUTOROLL_CONFIRM"
StaticPopupDialogs[CONFIRM_DIALOG] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, onAccept)
        onAccept()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function Confirm(text, onAccept)
    StaticPopup_Show(CONFIRM_DIALOG, text, nil, onAccept)
end

-- Widgets

local function CreateText(parent, font, width)
    local text = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
    text:SetJustifyH("LEFT")
    if width then
        text:SetWidth(width)
    end
    return text
end

local function CreateButton(parent, label, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateCheckbox(parent, label, tooltip, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check.label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.label:SetText(label)
    check:SetScript("OnClick", onClick)
    SetTooltip(check, label, tooltip)
    return check
end

-- A title with a thin line after it, like the headers of the native settings
local function CreateHeader(parent, label)
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(EDITOR_WIDTH, 20)
    header.text = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header.text:SetPoint("LEFT")
    header.text:SetText(label)
    header.line = header:CreateTexture(nil, "ARTWORK")
    header.line:SetColorTexture(1, 1, 1, 0.2)
    header.line:SetHeight(1)
    header.line:SetPoint("LEFT", header.text, "RIGHT", 8, 0)
    header.line:SetPoint("RIGHT")
    return header
end

-- Enter or leaving the box saves the text, Escape puts the saved text back
local function CreateEditBox(parent, width, onCommit)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnEscapePressed", function(self)
        self.revert = true
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        if self.revert then
            self.revert = nil
            self:SetText(self.saved or "")
        elseif self:GetText() ~= self.saved then
            self.onCommit(self:GetText())
        end
    end)
    box.onCommit = onCommit
    return box
end

local function SetEditBoxText(box, text)
    box.saved = text
    if not box:HasFocus() then
        box:SetText(text)
        box:SetCursorPosition(0)
    end
end

-- Wrapped text reports its height through GetStringHeight
local function Height(region)
    return region.GetStringHeight and region:GetStringHeight() or region:GetHeight()
end

local function StripColors(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Values are { [key] = label }. They are listed in the given order, else by key for numbers or by label.
local function SortedEntries(values, order, byKey)
    local entries = {}
    if order then
        for _, key in ipairs(order) do
            if values[key] then
                table.insert(entries, { key = key, label = values[key] })
            end
        end
        return entries
    end
    for key, label in pairs(values) do
        table.insert(entries, { key = key, label = label, sortText = StripColors(label):lower() })
    end
    table.sort(entries, function(a, b)
        if byKey then
            return a.key < b.key
        end
        return a.sortText < b.sortText
    end)
    return entries
end

-- Dropdowns use the native menu system, like the dropdowns of the game windows
local function CreateDropdown(parent, width)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(width)
    return dropdown
end

-- getEntries returns { { key, label } }. A multi dropdown has checkboxes and stays open while they are toggled,
-- the others have radio buttons. A multi menu is not generated again while it is open, so a toggle keeps it open.
local function SetDropdown(dropdown, getEntries, isSelected, onSelect, multi)
    dropdown:SetDefaultText("|cFF9D9D9DNone|r")
    if multi and dropdown:IsMenuOpen() then
        return
    end
    dropdown:SetupMenu(function(_, root)
        root:SetScrollMode(MENU_MAX_HEIGHT)
        for _, entry in ipairs(getEntries()) do
            if multi then
                root:CreateCheckbox(entry.label, isSelected, onSelect, entry.key)
            else
                root:CreateRadio(entry.label, isSelected, onSelect, entry.key)
            end
        end
    end)
end

-- A dropdown of actions, such as the profile to copy from. It shows a fixed text instead of a selection.
local function SetActionDropdown(dropdown, text, getEntries, onPick)
    local entries = getEntries()
    dropdown:SetupMenu(function(_, root)
        root:SetScrollMode(MENU_MAX_HEIGHT)
        for _, entry in ipairs(entries) do
            root:CreateButton(entry.label, onPick, entry.key)
        end
    end)
    dropdown:OverrideText(text)
    dropdown:SetEnabled(#entries > 0)
end

-- A scroll frame with the minimal scroll bar of the game windows, hidden when there is nothing to scroll
local function CreateScrollArea(parent, width)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width, 1)
    scroll:SetScrollChild(content)

    scroll.ScrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    scroll.ScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 0)
    scroll.ScrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, 0)
    scroll.ScrollBar:SetHideIfUnscrollable(true)
    ScrollUtil.InitScrollFrameWithScrollBar(scroll, scroll.ScrollBar)
    return scroll, content
end

-- Rule values

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

local function ResolveValues(values)
    return type(values) == "function" and values() or values
end

local function FindRule(rules, name)
    for _, rule in ipairs(rules) do
        if rule.name == name then
            return rule
        end
    end
end

-- A quick rule button is disabled once all of its rules are in the list, matched by name
local function HasAllRules(rules, quickRules)
    for _, rule in ipairs(quickRules) do
        if not FindRule(rules, rule.name) then
            return false
        end
    end
    return true
end

local function SelectRule(index)
    selectedRule = index
    AutoRoll:RefreshOptions()
    if pages.rules and pages.rules.body.editorScroll then
        pages.rules.body.editorScroll:SetVerticalScroll(0)
    end
end

-- General tab

local GENERAL_TOGGLES = {
    {
        key = "enabled",
        label = "Roll automatically",
        desc = "Roll on group loot with your rules. Same as /autoroll on and /autoroll off.",
    },
    {
        key = "autoConfirm",
        label = "Confirm bind-on-pickup rolls",
        desc = "Accept the \"this item will bind to you\" question for rolls this addon makes."
            .. " Rolls you make yourself still ask.",
    },
    {
        key = "autoConfirmDisenchant",
        label = "Confirm disenchant rolls",
        desc = "Accept the \"the item will be disenchanted if you win\" question for rolls this addon makes."
            .. " Rolls you make yourself still ask.",
    },
    {
        key = "dryRun",
        label = "Dry run",
        desc = "Check the rules and print what would be rolled, but do not roll. Same as /autoroll dry.",
    },
}

local function BuildGeneralTab(tab)
    tab.toggles = {}
    for index, toggle in ipairs(GENERAL_TOGGLES) do
        local check = CreateCheckbox(tab, toggle.label, toggle.desc, function(self)
            AutoRoll.profile[toggle.key] = self:GetChecked() and true or false
        end)
        check:SetPoint("TOPLEFT", 16, -16 - (index - 1) * 30)
        check.key = toggle.key
        tab.toggles[index] = check
    end

    tab.messagesHelp = CreateText(tab, "GameFontHighlight", PAGE_WIDTH - 32)
    tab.messagesHelp:SetPoint("TOPLEFT", 20, -16 - #GENERAL_TOGGLES * 30 - 20)
    tab.messagesHelp:SetText("The rules are on the Rules page and the message settings on the Messages page,"
        .. " both listed under " .. DISPLAY_NAME .. ".")
end

local function RefreshGeneralTab(tab)
    for _, check in ipairs(tab.toggles) do
        check:SetChecked(AutoRoll.profile[check.key] and true or false)
    end
end

-- Rules tab: the rule list on the left, the overview or the selected rule on the right

local function InitListRow(row, entry)
    if not row.text then
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        row.selected = row:CreateTexture(nil, "BACKGROUND")
        row.selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.selected:SetBlendMode("ADD")
        row.selected:SetVertexColor(1, 0.82, 0)
        row.selected:SetAllPoints()

        row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.text:SetPoint("LEFT", 6, 0)
        row.text:SetPoint("RIGHT", -4, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)

        row:SetScript("OnClick", function(self)
            SelectRule(self.ruleIndex)
        end)
    end
    row.ruleIndex = entry.ruleIndex
    row.text:SetText(entry.label)
    row.selected:SetShown(entry.ruleIndex == selectedRule)
end

local function RefreshRuleList(tab, rules)
    local entries = { { label = "|cFFFFD100Overview and quick rules|r" } }
    for index, rule in ipairs(rules) do
        local label = index .. ". " .. rule.name
        if not rule.enabled then
            label = "|cFF9D9D9D" .. label .. "|r"
        end
        table.insert(entries, { label = label, ruleIndex = index })
    end
    tab.list:SetDataProvider(CreateDataProvider(entries), ScrollBoxConstants.RetainScrollPosition)
end

local function BuildOverview(tab)
    local overview = CreateFrame("Frame", nil, tab.editorContent)
    overview:SetAllPoints()
    tab.overview = overview

    overview.title = CreateText(overview, "GameFontNormalLarge", EDITOR_WIDTH)
    overview.title:SetText("Rules are checked in order, from top to bottom")

    overview.help = CreateText(overview, "GameFontHighlight", EDITOR_WIDTH)
    overview.help:SetText("When loot drops, rule 1 is checked first, then rule 2, and so on. The first enabled rule whose"
        .. " conditions all match decides the roll, and the rules below it are not checked. If no rule matches, you roll"
        .. " yourself. Use Move up and Move down on a rule to change the order.")

    overview.noRules = CreateText(overview, "GameFontHighlight", EDITOR_WIDTH)
    overview.noRules:SetText("No rules yet. Until you add one, the addon does not roll and you roll yourself.")

    overview.quickHeader = CreateHeader(overview, "Quick rules")

    overview.quickHelp = CreateText(overview, "GameFontHighlightSmall", EDITOR_WIDTH)
    overview.quickHelp:SetText("Add a ready-made rule. Halt rules go to the top of the list, so they are checked first,"
        .. " and the others go to the end. You can edit, reorder and delete them like any other rule.")

    overview.quickButtons = {}
    for quickIndex, quick in ipairs(ns.QUICK_RULES) do
        local button = CreateButton(overview, quick.label, 205, function()
            local rules = AutoRoll.profile.rules
            local position = quick.top and 1 or #rules + 1
            for _, rule in ipairs(quick.rules) do
                if not FindRule(rules, rule.name) then
                    table.insert(rules, position, CopyTable(rule))
                    position = position + 1
                end
            end
            AutoRoll:RefreshOptions()
        end)
        SetTooltip(button, quick.label, quick.desc)
        button.quick = quick
        overview.quickButtons[quickIndex] = button
    end
end

local function RefreshOverview(tab, rules)
    local overview = tab.overview
    local y = 0

    local function Place(region, gap)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", 0, y)
        y = y - Height(region) - (gap or 8)
    end

    Place(overview.title)
    Place(overview.help, 12)
    overview.noRules:SetShown(#rules == 0)
    if #rules == 0 then
        Place(overview.noRules, 12)
    end
    Place(overview.quickHeader, 4)
    Place(overview.quickHelp, 10)

    for quickIndex, button in ipairs(overview.quickButtons) do
        local column = (quickIndex - 1) % 2
        local row = math.floor((quickIndex - 1) / 2)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", column * 215, y - row * 28)
        button:SetEnabled(not HasAllRules(rules, button.quick.rules))
    end
    y = y - math.ceil(#overview.quickButtons / 2) * 28

    return -y + 8
end

local function GetConditionRow(editor, index)
    local row = editor.conditionRows[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, editor)
    row:SetSize(EDITOR_WIDTH, 72)

    row.title = CreateText(row, "GameFontNormalSmall")
    row.title:SetPoint("TOPLEFT", 2, 0)

    row.type = CreateDropdown(row, 180)
    row.type:SetPoint("TOPLEFT", 0, -14)
    row.op = CreateDropdown(row, 120)
    row.op:SetPoint("LEFT", row.type, "RIGHT", 8, 0)
    row.valueDropdown = CreateDropdown(row, 250)
    row.valueBox = CreateEditBox(row, 244, function(text)
        row.commitValue(text)
    end)
    row.remove = CreateButton(row, "Remove", 80, function()
        row.removeCondition()
    end)
    row.remove:SetPoint("TOPLEFT", 332, -14)

    editor.conditionRows[index] = row
    return row
end

local function RefreshConditionValue(row, condition, def)
    -- The value is on its own line under the check, since the settings canvas is narrow
    row.valueDropdown:ClearAllPoints()
    row.valueDropdown:SetPoint("TOPLEFT", 0, -44)
    row.valueBox:ClearAllPoints()
    row.valueBox:SetPoint("TOPLEFT", 6, -45)

    local operator = ns.OPERATORS[condition.op]
    local isSet = operator and operator.isSet
    local usesBox = not isSet and (def.kind == "number" or def.kind == "text")
    row.valueDropdown:SetShown(not usesBox)
    row.valueBox:SetShown(usesBox)

    if isSet then
        -- Several values can be picked; the condition matches any of them
        if type(condition.value) ~= "table" then
            condition.value = {}
        end
        SetDropdown(row.valueDropdown,
            function() return SortedEntries(ResolveValues(def.values), nil, def.kind == "quality") end,
            function(key) return condition.value[key] == true end,
            function(key)
                condition.value[key] = not condition.value[key] or nil
                AutoRoll:RefreshOptions()
            end,
            true)
    elseif def.kind == "boolean" then
        SetDropdown(row.valueDropdown,
            function() return SortedEntries(BOOLEAN_VALUES, BOOLEAN_ORDER) end,
            function(key) return (condition.value and "yes" or "no") == key end,
            function(key)
                condition.value = key == "yes"
                AutoRoll:RefreshOptions()
            end)
    elseif def.kind == "number" then
        SetEditBoxText(row.valueBox, tostring(condition.value or ""))
        row.commitValue = function(text)
            local number = tonumber(text)
            if not number then
                AutoRoll:Print("Enter a number.")
                row.valueBox:SetText(row.valueBox.saved)
                return
            end
            condition.value = number
            AutoRoll:RefreshOptions()
        end
    elseif def.kind == "text" then
        SetEditBoxText(row.valueBox, condition.value or "")
        row.commitValue = function(text)
            condition.value = text
            AutoRoll:RefreshOptions()
        end
    else
        SetDropdown(row.valueDropdown,
            function() return SortedEntries(ResolveValues(def.values), nil, def.kind == "quality") end,
            function(key) return condition.value == key end,
            function(key)
                condition.value = key
                AutoRoll:RefreshOptions()
            end)
    end
end

local function RefreshConditionRow(row, rule, conditionIndex)
    local condition = rule.conditions[conditionIndex]
    local def = ns.CONDITIONS[condition.type]
    if not def then
        -- Saved by a newer version or damaged; start over with a known type
        ns.ResetCondition(condition, "itemLevel")
        def = ns.CONDITIONS[condition.type]
    end

    row.title:SetText("Condition " .. conditionIndex)

    SetDropdown(row.type,
        function() return SortedEntries(ConditionTypeValues(), ns.CONDITION_ORDER) end,
        function(key) return condition.type == key end,
        function(key)
            ns.ResetCondition(condition, key)
            AutoRoll:RefreshOptions()
        end)
    SetTooltip(row.type, def.label, def.desc)

    row.op:SetShown(def.kind ~= "boolean")
    if def.kind ~= "boolean" then
        SetDropdown(row.op,
            function() return SortedEntries(OperatorValues(def.kind), ns.OPERATOR_SETS[def.kind]) end,
            function(key) return condition.op == key end,
            function(key)
                ns.SetOperator(condition, key)
                AutoRoll:RefreshOptions()
            end)
    end

    RefreshConditionValue(row, condition, def)

    row.removeCondition = function()
        table.remove(rule.conditions, conditionIndex)
        AutoRoll:RefreshOptions()
    end
end

local function BuildRuleEditor(tab)
    local editor = CreateFrame("Frame", nil, tab.editorContent)
    editor:SetAllPoints()
    tab.editor = editor

    editor.summary = CreateText(editor, "GameFontHighlight", EDITOR_WIDTH)
    editor.position = CreateText(editor, "GameFontHighlightSmall", EDITOR_WIDTH)

    editor.enabled = CreateCheckbox(editor, "Enabled", "Turn the rule on or off. A disabled rule is skipped.", function(self)
        editor.rule.enabled = self:GetChecked() and true or false
        AutoRoll:RefreshOptions()
    end)

    editor.nameLabel = CreateText(editor, "GameFontNormalSmall")
    editor.nameLabel:SetText("Name")
    editor.name = CreateEditBox(editor, 190, function(text)
        editor.rule.name = text
        AutoRoll:RefreshOptions()
    end)

    editor.actionLabel = CreateText(editor, "GameFontNormalSmall")
    editor.actionLabel:SetText("Roll")
    editor.action = CreateDropdown(editor, 170)
    SetTooltip(editor.action, "Roll", "If the roll is not available for this item, for example Need on an item your class"
        .. " cannot use, the next rule is tried. Roll manually stops here and leaves the roll to you.")

    editor.conditionsHeader = CreateHeader(editor, "Conditions (all must match)")
    editor.noConditions = CreateText(editor, "GameFontHighlight", EDITOR_WIDTH)
    editor.noConditions:SetText("No conditions: this rule matches every item.")
    editor.conditionRows = {}

    editor.addCondition = CreateButton(editor, "Add condition", 140, function()
        table.insert(editor.rule.conditions, ns.NewCondition())
        AutoRoll:RefreshOptions()
    end)

    editor.ruleHeader = CreateHeader(editor, "Rule")
    editor.moveUp = CreateButton(editor, "Move up", 120, function()
        local rules, index = AutoRoll.profile.rules, selectedRule
        rules[index], rules[index - 1] = rules[index - 1], rules[index]
        SelectRule(index - 1)
    end)
    editor.moveDown = CreateButton(editor, "Move down", 120, function()
        local rules, index = AutoRoll.profile.rules, selectedRule
        rules[index], rules[index + 1] = rules[index + 1], rules[index]
        SelectRule(index + 1)
    end)
    editor.delete = CreateButton(editor, "Delete rule", 120, function()
        local rule = editor.rule
        Confirm("Delete the rule \"" .. rule.name .. "\"?", function()
            local rules = AutoRoll.profile.rules
            for index, candidate in ipairs(rules) do
                if candidate == rule then
                    table.remove(rules, index)
                    break
                end
            end
            SelectRule(nil)
        end)
    end)
end

local function RefreshRuleEditor(tab, rules, index)
    local editor = tab.editor
    local rule = rules[index]
    editor.rule = rule
    local y = 0

    local function Place(region, x, gap)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", x or 0, y)
        y = y - Height(region) - (gap or 8)
    end

    editor.summary:SetText(ns.DescribeRule(rule))
    Place(editor.summary, 0, 6)
    editor.position:SetText(index == 1 and "|cFFFFD100Checked first.|r No other rule comes before it."
        or string.format("|cFFFFD100Checked as number %d of %d.|r If a rule above it matches, this rule is not checked.",
            index, #rules))
    Place(editor.position, 0, 10)

    Place(editor.enabled, -4, 6)
    editor.enabled:SetChecked(rule.enabled and true or false)

    editor.nameLabel:ClearAllPoints()
    editor.nameLabel:SetPoint("TOPLEFT", 2, y)
    editor.actionLabel:ClearAllPoints()
    editor.actionLabel:SetPoint("TOPLEFT", 214, y)
    y = y - 14
    editor.name:ClearAllPoints()
    editor.name:SetPoint("TOPLEFT", 6, y)
    SetEditBoxText(editor.name, rule.name)
    editor.action:ClearAllPoints()
    editor.action:SetPoint("TOPLEFT", 214, y + 1)
    SetDropdown(editor.action,
        function() return SortedEntries(ActionValues(), ns.ACTION_ORDER) end,
        function(key) return rule.action == key end,
        function(key)
            rule.action = key
            AutoRoll:RefreshOptions()
        end)
    y = y - 34

    Place(editor.conditionsHeader, 0, 6)
    editor.noConditions:SetShown(#rule.conditions == 0)
    if #rule.conditions == 0 then
        Place(editor.noConditions, 0, 10)
    end
    for conditionIndex = 1, #rule.conditions do
        local row = GetConditionRow(editor, conditionIndex)
        RefreshConditionRow(row, rule, conditionIndex)
        row:Show()
        Place(row, 0, 6)
    end
    for conditionIndex = #rule.conditions + 1, #editor.conditionRows do
        editor.conditionRows[conditionIndex]:Hide()
    end
    Place(editor.addCondition, 0, 16)

    Place(editor.ruleHeader, 0, 6)
    editor.moveUp:ClearAllPoints()
    editor.moveUp:SetPoint("TOPLEFT", 0, y)
    editor.moveUp:SetEnabled(index > 1)
    editor.moveDown:ClearAllPoints()
    editor.moveDown:SetPoint("LEFT", editor.moveUp, "RIGHT", 8, 0)
    editor.moveDown:SetEnabled(index < #rules)
    editor.delete:ClearAllPoints()
    editor.delete:SetPoint("LEFT", editor.moveDown, "RIGHT", 8, 0)
    y = y - 22

    return -y + 8
end

local function BuildRulesTab(tab)
    -- The rule list, like the list of the AddOns window
    tab.list = CreateFrame("Frame", nil, tab, "WowScrollBoxList")
    tab.list:SetPoint("TOPLEFT", 6, -6)
    tab.list:SetPoint("BOTTOMLEFT", 6, 40)
    tab.list:SetWidth(LIST_WIDTH)
    tab.listBar = CreateFrame("EventFrame", nil, tab, "MinimalScrollBar")
    tab.listBar:SetPoint("TOPLEFT", tab.list, "TOPRIGHT", 4, -3)
    tab.listBar:SetPoint("BOTTOMLEFT", tab.list, "BOTTOMRIGHT", 4, 2)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(LIST_ROW_HEIGHT)
    view:SetElementInitializer("Button", InitListRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(tab.list, tab.listBar, view)
    tab.listBar:SetHideIfUnscrollable(true)

    tab.divider = tab:CreateTexture(nil, "ARTWORK")
    tab.divider:SetColorTexture(1, 1, 1, 0.12)
    tab.divider:SetWidth(1)
    tab.divider:SetPoint("TOPLEFT", tab.list, "TOPRIGHT", 22, 0)
    tab.divider:SetPoint("BOTTOMLEFT", tab.list, "BOTTOMRIGHT", 22, 0)

    tab.add = CreateButton(tab, "Add rule", 120, function()
        local rules = AutoRoll.profile.rules
        table.insert(rules, {
            name = "New rule",
            enabled = true,
            action = "greed",
            conditions = { ns.NewCondition() },
        })
        SelectRule(#rules)
    end)
    tab.add:SetPoint("BOTTOMLEFT", 6, 10)

    tab.editorScroll, tab.editorContent = CreateScrollArea(tab, EDITOR_WIDTH)
    tab.editorScroll:SetPoint("TOPLEFT", tab.divider, "TOPRIGHT", 12, -6)
    tab.editorScroll:SetPoint("BOTTOMLEFT", tab.divider, "BOTTOMRIGHT", 12, -34)
    tab.editorScroll:SetWidth(EDITOR_WIDTH)

    BuildOverview(tab)
    BuildRuleEditor(tab)
end

local function RefreshRulesTab(tab)
    local rules = AutoRoll.profile.rules
    if selectedRule and not rules[selectedRule] then
        selectedRule = nil
    end

    RefreshRuleList(tab, rules)
    tab.overview:SetShown(selectedRule == nil)
    tab.editor:SetShown(selectedRule ~= nil)

    local height
    if selectedRule then
        height = RefreshRuleEditor(tab, rules, selectedRule)
    else
        height = RefreshOverview(tab, rules)
    end
    tab.editorContent:SetHeight(math.max(height, 1))
end

-- Profiles tab

local function BuildProfilesTab(tab)
    local width = PAGE_WIDTH - 32

    tab.help = CreateText(tab, "GameFontHighlight", width)
    tab.help:SetPoint("TOPLEFT", 20, -16)
    tab.help:SetText("Settings and rules are saved in profiles. By default all characters share the Default profile."
        .. " Pick another profile to give this character its own rules.")

    tab.current = CreateText(tab, "GameFontNormal", width)
    tab.current:SetPoint("TOPLEFT", tab.help, "BOTTOMLEFT", 0, -16)

    tab.useLabel = CreateText(tab, "GameFontNormalSmall")
    tab.useLabel:SetPoint("TOPLEFT", tab.current, "BOTTOMLEFT", 0, -20)
    tab.useLabel:SetText("Use profile")
    tab.use = CreateDropdown(tab, 240)
    tab.use:SetPoint("TOPLEFT", tab.useLabel, "BOTTOMLEFT", -2, -4)

    tab.newLabel = CreateText(tab, "GameFontNormalSmall")
    tab.newLabel:SetPoint("TOPLEFT", tab.useLabel, "TOPLEFT", 300, 0)
    tab.newLabel:SetText("New profile")
    tab.new = CreateEditBox(tab, 200, function() end)
    tab.new:SetPoint("TOPLEFT", tab.newLabel, "BOTTOMLEFT", 4, -5)
    tab.create = CreateButton(tab, "Create", 80, function()
        local name = strtrim(tab.new:GetText())
        tab.new:SetText("")
        tab.new.saved = ""
        if name ~= "" then
            AutoRoll:SetProfile(name)
        end
    end)
    tab.create:SetPoint("LEFT", tab.new, "RIGHT", 8, 0)
    tab.new:SetScript("OnEnterPressed", function()
        tab.create:Click()
    end)

    tab.copyLabel = CreateText(tab, "GameFontNormalSmall")
    tab.copyLabel:SetPoint("TOPLEFT", tab.useLabel, "BOTTOMLEFT", 0, -44)
    tab.copyLabel:SetText("Copy from")
    tab.copy = CreateDropdown(tab, 240)
    tab.copy:SetPoint("TOPLEFT", tab.copyLabel, "BOTTOMLEFT", -2, -4)
    SetTooltip(tab.copy, "Copy from", "Replace the settings and rules of the current profile with those of another profile.")

    tab.deleteLabel = CreateText(tab, "GameFontNormalSmall")
    tab.deleteLabel:SetPoint("TOPLEFT", tab.copyLabel, "TOPLEFT", 300, 0)
    tab.deleteLabel:SetText("Delete a profile")
    tab.delete = CreateDropdown(tab, 240)
    tab.delete:SetPoint("TOPLEFT", tab.deleteLabel, "BOTTOMLEFT", -2, -4)
    SetTooltip(tab.delete, "Delete a profile", "The profile in use cannot be deleted. Characters that use a deleted"
        .. " profile go back to Default.")

    tab.reset = CreateButton(tab, "Reset profile", 140, function()
        Confirm("Reset the profile \"" .. AutoRoll.profileName .. "\"? Its settings go back to the defaults and all"
            .. " of its rules are deleted.", function()
            AutoRoll:ResetProfile()
        end)
    end)
    tab.reset:SetPoint("TOPLEFT", tab.copy, "BOTTOMLEFT", 2, -24)
end

-- Profiles that hold saved data, other than the one in use
local function OtherProfileEntries()
    local entries = {}
    for _, name in ipairs(AutoRoll:GetProfileNames()) do
        if name ~= AutoRoll.profileName and AutoRoll.db.profiles[name] then
            table.insert(entries, { key = name, label = name })
        end
    end
    return entries
end

local function RefreshProfilesTab(tab)
    tab.current:SetText("Current profile: |cFFFFFFFF" .. AutoRoll.profileName .. "|r")

    SetDropdown(tab.use,
        function()
            local entries = {}
            for _, name in ipairs(AutoRoll:GetProfileNames()) do
                table.insert(entries, { key = name, label = name })
            end
            return entries
        end,
        function(name) return name == AutoRoll.profileName end,
        function(name)
            AutoRoll:SetProfile(name)
        end)

    SetActionDropdown(tab.copy, "|cFF9D9D9DChoose a profile|r", OtherProfileEntries, function(name)
        Confirm("Copy the profile \"" .. name .. "\" into \"" .. AutoRoll.profileName .. "\"? The rules of \""
            .. AutoRoll.profileName .. "\" are replaced.", function()
            AutoRoll:CopyProfile(name)
        end)
    end)

    SetActionDropdown(tab.delete, "|cFF9D9D9DChoose a profile|r", OtherProfileEntries, function(name)
        Confirm("Delete the profile \"" .. name .. "\"?", function()
            AutoRoll:DeleteProfile(name)
            AutoRoll:RefreshOptions()
        end)
    end)
end

-- Settings pages: Kehet's AutoRoll holds the general toggles, with Rules, Profiles and Messages under it

local PAGES = {
    { key = "general", build = BuildGeneralTab, refresh = RefreshGeneralTab },
    { key = "rules", label = "Rules", build = BuildRulesTab, refresh = RefreshRulesTab },
    { key = "profiles", label = "Profiles", build = BuildProfilesTab, refresh = RefreshProfilesTab },
}

-- A page with the title and divider of the native settings pages. The body is built when the page is first shown.
local function CreatePage(def)
    local page = CreateFrame("Frame")
    -- An unparented frame starts shown, so the settings panel's first Show() would not fire OnShow
    page:Hide()
    page.name = def.label or DISPLAY_NAME
    page.def = def

    page.title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    page.title:SetPoint("TOPLEFT", 7, -22)
    page.title:SetText(def.label or DISPLAY_NAME)

    page.divider = page:CreateTexture(nil, "ARTWORK")
    page.divider:SetAtlas("Options_HorizontalDivider", true)
    page.divider:SetPoint("TOP", 0, -50)

    page:SetScript("OnShow", function(self)
        if not self.body then
            self.body = CreateFrame("Frame", nil, self)
            self.body:SetPoint("TOPLEFT", 0, -56)
            self.body:SetPoint("BOTTOMRIGHT")
            def.build(self.body)
        end
        def.refresh(self.body)
    end)

    pages[def.key] = page
    return page
end

function AutoRoll:RefreshOptions()
    for _, def in ipairs(PAGES) do
        local page = pages[def.key]
        if page and page.body and page:IsVisible() then
            def.refresh(page.body)
        end
    end
end

function AutoRoll:OpenOptions()
    if self.settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(pages.general)
    end
end

function AutoRoll:SetupOptions()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(CreatePage(PAGES[1]), DISPLAY_NAME)
        for index = 2, #PAGES do
            Settings.RegisterCanvasLayoutSubcategory(category, CreatePage(PAGES[index]), PAGES[index].label)
        end
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory = category
        self:RegisterMessagePage(category)
    elseif InterfaceOptions_AddCategory then
        for _, def in ipairs(PAGES) do
            local page = CreatePage(def)
            if def.label then
                page.parent = DISPLAY_NAME
            end
            InterfaceOptions_AddCategory(page)
        end
        self:RegisterMessagePage()
    end
end
