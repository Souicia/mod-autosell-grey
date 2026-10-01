-- AUTOSELL_GREY_LUA_V2
-- Settings/commands/manual bag cleanup only.
-- Corpse-loot Auto Sell is handled authoritatively in Player::StoreLootItem.

local AUTOSELL_LEVEL = 6
local UNLOCK_DELAY = 1000
local MAX_MONEY_AMOUNT = 2147483646

local PLAYER_EVENT_ON_LOGIN = 3
local PLAYER_EVENT_ON_LEVEL_CHANGE = 13
local PLAYER_EVENT_ON_COMMAND = 42

local function IsBot(player)
    return player and player.IsBot and player:IsBot()
end

local function SaveSettings(player, settings)
    local guid = player:GetGUIDLow()
    local enabledValue = settings.enabled and 1 or 0

    CharDBExecute(
        "REPLACE INTO character_autosell_settings " ..
        "(guid, enabled, chat_enabled) VALUES (" ..
        guid .. ", " ..
        enabledValue .. ", 1)"
    )
end

local function LoadSettings(player)
    local guid = player:GetGUIDLow()

    local settings = {
        enabled = player:GetLevel() >= AUTOSELL_LEVEL
    }

    local result = CharDBQuery(
        "SELECT enabled " ..
        "FROM character_autosell_settings " ..
        "WHERE guid = " .. guid
    )

    if result then
        settings.enabled = result:GetUInt32(0) == 1
    end

    return settings
end

local function GetSettings(player)
    return LoadSettings(player)
end

local function EnsureSettingsRow(player)
    if not player or IsBot(player) or player:GetLevel() < AUTOSELL_LEVEL then
        return
    end

    -- Preserve an existing ON/OFF choice; create the default ON row only
    -- when this character does not have one yet.
    local settings = GetSettings(player)
    SaveSettings(player, settings)
end

local function FormatMoney(amount)
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    local parts = {}

    if gold > 0 then
        table.insert(parts, gold .. "g")
    end

    if silver > 0 then
        table.insert(parts, silver .. "s")
    end

    if copper > 0 or #parts == 0 then
        table.insert(parts, copper .. "c")
    end

    return table.concat(parts, " ")
end

local function IsEligibleExistingGrey(player, item)
    if not item or item:GetQuality() ~= 0 then
        return false
    end

    local entry = item:GetEntry()

    if player:HasQuestForItem(entry) then
        return false
    end

    if item:GetSellPrice() <= 0 then
        return false
    end

    -- Match the core safety exclusions:
    -- class 12 = Quest, class 13 = Key,
    -- Flags 0x4 = HAS_LOOT, Flags 0x20 = NO_USER_DESTROY.
    local safeTemplate = WorldDBQuery(
        "SELECT 1 FROM item_template " ..
        "WHERE entry = " .. entry .. " " ..
        "AND class NOT IN (12, 13) " ..
        "AND StartQuest = 0 " ..
        "AND (Flags & 4) = 0 " ..
        "AND (Flags & 32) = 0 " ..
        "LIMIT 1"
    )

    return safeTemplate ~= nil
end

local function SellExistingGreys(player)
    if IsBot(player) then
        return
    end

    local itemsToSell = {}
    local totalItems = 0
    local totalMoney = 0

    local function QueueItem(item)
        if not IsEligibleExistingGrey(player, item) then
            return
        end

        local count = item:GetCount()
        local value = item:GetSellPrice() * count

        table.insert(itemsToSell, {
            item = item,
            count = count
        })

        totalItems = totalItems + count
        totalMoney = totalMoney + value
    end

    -- Backpack slots only, excluding equipped items and equipped bags.
    for slot = 23, 38 do
        QueueItem(player:GetItemByPos(255, slot))
    end

    -- Contents of the four equipped bags.
    for bagSlot = 19, 22 do
        local bag = player:GetItemByPos(255, bagSlot)

        if bag then
            for slot = 0, bag:GetBagSize() - 1 do
                QueueItem(player:GetItemByPos(bagSlot, slot))
            end
        end
    end

    if totalItems == 0 then
        player:SendBroadcastMessage(
            "No eligible grey items were found in your bags."
        )
        return
    end

    -- Do not destroy items if the full sale value cannot fit in the money cap.
    local currentMoney = player:GetCoinage()

    if totalMoney <= 0 or currentMoney >= (MAX_MONEY_AMOUNT - totalMoney) then
        player:SendBroadcastMessage(
            "Auto Sell could not sell these items because the full value could not be credited."
        )
        return
    end

    for _, record in ipairs(itemsToSell) do
        player:RemoveItem(record.item, record.count)
    end

    player:ModifyMoney(totalMoney)

    player:SendBroadcastMessage(
        "Sold " ..
        totalItems ..
        " existing grey item" ..
        (totalItems == 1 and "" or "s") ..
        " for " ..
        FormatMoney(totalMoney) ..
        "."
    )
end

local function CompleteAutosellUnlock(eventId, delay, repeats, player)
    if not player or IsBot(player) or player:GetLevel() < AUTOSELL_LEVEL then
        return
    end

    local settings = GetSettings(player)
    settings.enabled = true
    SaveSettings(player, settings)

    player:SendBroadcastMessage(
        "|cff00ff00Auto Sell unlocked!|r Grey items with a vendor value " ..
        "will now be sold automatically."
    )

    player:SendBroadcastMessage(
        "Use .autosell on or .autosell off to change this setting."
    )

    player:SendBroadcastMessage(
        "Use .autosell now to sell eligible grey items already in your bags."
    )
end

local function OnLogin(event, player)
    EnsureSettingsRow(player)
end

local function OnLevelChange(event, player, oldLevel)
    if IsBot(player) then
        return
    end

    if oldLevel < AUTOSELL_LEVEL and player:GetLevel() >= AUTOSELL_LEVEL then
        player:RegisterEvent(
            CompleteAutosellUnlock,
            UNLOCK_DELAY,
            1
        )
    end
end

local function OnCommand(event, player, command)
    if not player or IsBot(player) then
        return
    end

    command = command:lower()
    command = command:gsub("^%.", "")
    command = command:match("^%s*(.-)%s*$")

    local validCommand =
        command == "autosell" or
        command == "autosell now" or
        command == "autosell on" or
        command == "autosell off"

    if not validCommand then
        return
    end

    if player:GetLevel() < AUTOSELL_LEVEL then
        player:SendBroadcastMessage(
            "Auto Sell unlocks at level " .. AUTOSELL_LEVEL .. "."
        )
        return false
    end

    EnsureSettingsRow(player)

    if command == "autosell now" then
        SellExistingGreys(player)
        return false
    end

    local settings = GetSettings(player)

    if command == "autosell on" then
        settings.enabled = true
        SaveSettings(player, settings)
        player:SendBroadcastMessage("Auto Sell is now ON.")
        return false
    end

    if command == "autosell off" then
        settings.enabled = false
        SaveSettings(player, settings)
        player:SendBroadcastMessage("Auto Sell is now OFF.")
        return false
    end

    local autosellStatus = settings.enabled and "ON" or "OFF"

    player:SendBroadcastMessage(
        "Auto Sell is currently " .. autosellStatus .. "."
    )

    player:SendBroadcastMessage(
        "Usage: .autosell on, .autosell off, or .autosell now"
    )

    return false
end

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnLogin)
RegisterPlayerEvent(PLAYER_EVENT_ON_LEVEL_CHANGE, OnLevelChange)
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, OnCommand)