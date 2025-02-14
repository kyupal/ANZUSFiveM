QBCore.Functions = {}
QBCore.Player_Buckets = {}
QBCore.Entity_Buckets = {}
QBCore.UsableItems = {}

-- Getters
-- Get your player first and then trigger a function on them
-- ex: local player = QBCore.Functions.GetPlayer(source)
-- ex: local example = player.Functions.functionname(parameter)

function QBCore.Functions.GetCoords(entity)
    local coords = GetEntityCoords(entity, false)
    local heading = GetEntityHeading(entity)
    return vector4(coords.x, coords.y, coords.z, heading)
end

function QBCore.Functions.GetIdentifier(source, idtype)
    local identifiers = GetPlayerIdentifiers(source)
    for _, identifier in pairs(identifiers) do
        if string.find(identifier, idtype) then
            return identifier
        end
    end
    return nil
end

function QBCore.Functions.GetSource(identifier)
    for src, _ in pairs(QBCore.Players) do
        local idens = GetPlayerIdentifiers(src)
        for _, id in pairs(idens) do
            if identifier == id then
                return src
            end
        end
    end
    return 0
end

function QBCore.Functions.GetPlayer(source)
    if type(source) == 'number' then
        return QBCore.Players[source]
    else
        return QBCore.Players[QBCore.Functions.GetSource(source)]
    end
end

function QBCore.Functions.GetPlayerByCitizenId(citizenid)
    for src in pairs(QBCore.Players) do
        if QBCore.Players[src].PlayerData.citizenid == citizenid then
            return QBCore.Players[src]
        end
    end
    return nil
end

function QBCore.Functions.GetOfflinePlayerByCitizenId(citizenid)
    return QBCore.Player.GetOfflinePlayer(citizenid)
end

function QBCore.Functions.GetPlayerByPhone(number)
    for src in pairs(QBCore.Players) do
        if QBCore.Players[src].PlayerData.phone_number == number then
            return QBCore.Players[src]
        end
    end
    return nil
end

function QBCore.Functions.GetPlayers()
    local sources = {}
    for k in pairs(QBCore.Players) do
        sources[#sources + 1] = k
    end
    return sources
end

-- Will return an array of QB Player class instances
-- unlike the GetPlayers() wrapper which only returns IDs
function QBCore.Functions.GetQBPlayers()
    return QBCore.Players
end

--- Gets a list of all on duty players of a specified job and the number
function QBCore.Functions.GetDutyCountJob(job)
    local players = {}
    local count = 0
    for src, Player in pairs(QBCore.Players) do
        if Player.PlayerData.job.name == job then
            if Player.PlayerData.job.onduty then
                players[#players + 1] = src
                count += 1
            end
        end
    end
    return count, players
end

--- Gets a list of all on duty players of a specified job type and the number
function QBCore.Functions.GetDutyCountType(type)
    local players = {}
    local count = 0
    for src, Player in pairs(QBCore.Players) do
        if Player.PlayerData.job.type == type then
            if Player.PlayerData.job.onduty then
                players[#players + 1] = src
                count += 1
            end
        end
    end
    return count, players
end

-- Routing buckets (Only touch if you know what you are doing)

-- Returns the objects related to buckets, first returned value is the player buckets, second one is entity buckets
function QBCore.Functions.GetBucketObjects()
    return QBCore.Player_Buckets, QBCore.Entity_Buckets
end

-- Will set the provided player id / source into the provided bucket id
function QBCore.Functions.SetPlayerBucket(source --[[ int ]] , bucket --[[ int ]])
    if not (source or bucket) then return false end

    SetPlayerRoutingBucket(source, bucket)
    QBCore.Player_Buckets[source] = bucket
    return true
end

-- Will set any entity into the provided bucket, for example peds / vehicles / props / etc.
function QBCore.Functions.SetEntityBucket(entity --[[ int ]] , bucket --[[ int ]])
    if not (entity or bucket) then return false end

    SetEntityRoutingBucket(entity, bucket)
    QBCore.Entity_Buckets[entity] = bucket
    return true
end

-- Will return an array of all the player ids inside the current bucket
function QBCore.Functions.GetPlayersInBucket(bucket --[[ int ]])
    local curr_bucket_pool = {}
    if not (QBCore.Player_Buckets or next(QBCore.Player_Buckets)) then
        return false
    end

    for k, v in pairs(QBCore.Player_Buckets) do
        if v == bucket then
            curr_bucket_pool[#curr_bucket_pool + 1] = k
        end
    end

    return curr_bucket_pool
end

-- Will return an array of all the entities inside the current bucket (not for player entities, use GetPlayersInBucket for that)
function QBCore.Functions.GetEntitiesInBucket(bucket --[[ int ]])
    local curr_bucket_pool = {}
    if QBCore.Entity_Buckets and next(QBCore.Entity_Buckets) then
        for k, v in pairs(QBCore.Entity_Buckets) do
            if v == bucket then
                curr_bucket_pool[#curr_bucket_pool + 1] = k
            end
        end
        return curr_bucket_pool
    else
        return false
    end
end

-- Server side vehicle creation with optional callback
-- the CreateVehicle RPC still uses the client for creation so players must be near
function QBCore.Functions.SpawnVehicle(source, model, coords, warp)
    local ped = GetPlayerPed(source)
    model = type(model) == 'string' and joaat(model) or model
    if not coords then coords = GetEntityCoords(ped) end
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, true, true)
    while not DoesEntityExist(veh) do Wait(0) end
    if warp then
        while GetVehiclePedIsIn(ped, false) ~= veh do
            Wait(0)
            TaskWarpPedIntoVehicle(ped, veh, -1)
        end
    end
    while NetworkGetEntityOwner(veh) ~= source do Wait(0) end
    return veh
end

-- Server side vehicle creation with optional callback
-- The CreateVehicleServerSetter native uses only the server to create a vehicle instead of using the client as well
function QBCore.Functions.CreateVehicle(source, model, coords, warp)
    model = type(model) == 'string' and joaat(model) or model
    if not coords then coords = GetEntityCoords(GetPlayerPed(source)) end
    if not CreateVehicleServerSetter then
        error('^1CreateVehicleServerSetter is not available on your artifact, please use artifact 5904 or above to be able to use this^0')
        return
    end
    local tempVehicle = CreateVehicle(model, 0, 0, 0, 0, true, true)
    while not DoesEntityExist(tempVehicle) do Wait(0) end
    local vehicleType = GetVehicleType(tempVehicle)
    DeleteEntity(tempVehicle)
    local veh = CreateVehicleServerSetter(model, vehicleType, coords.x, coords.y, coords.z, coords.w)
    while not DoesEntityExist(veh) do Wait(0) end
    if warp then TaskWarpPedIntoVehicle(GetPlayerPed(source), veh, -1) end
    return veh
end

-- Callback Functions --

-- Client Callback
function QBCore.Functions.TriggerClientCallback(name, source, cb, ...)
    QBCore.ClientCallbacks[name] = cb
    TriggerClientEvent('QBCore:Client:TriggerClientCallback', source, name, ...)
end

-- Server Callback
function QBCore.Functions.CreateCallback(name, cb)
    QBCore.ServerCallbacks[name] = cb
end

function QBCore.Functions.TriggerCallback(name, source, cb, ...)
    if not QBCore.ServerCallbacks[name] then return end
    QBCore.ServerCallbacks[name](source, cb, ...)
end

-- Items

function QBCore.Functions.CreateUseableItem(item, data)
    QBCore.UsableItems[item] = data
end

function QBCore.Functions.CanUseItem(item)
    return QBCore.UsableItems[item]
end

function QBCore.Functions.UseItem(source, item)
    if GetResourceState('qb-inventory') == 'missing' then return end
    exports['qb-inventory']:UseItem(source, item)
end

-- Kick Player

function QBCore.Functions.Kick(source, reason, setKickReason, deferrals)
    reason = '\n' .. reason .. '\n🔸 Check our Discord for further information: ' .. QBCore.Config.Server.Discord
    if setKickReason then
        setKickReason(reason)
    end
    CreateThread(function()
        if deferrals then
            deferrals.update(reason)
            Wait(2500)
        end
        if source then
            DropPlayer(source, reason)
        end
        for _ = 0, 4 do
            while true do
                if source then
                    if GetPlayerPing(source) >= 0 then
                        break
                    end
                    Wait(100)
                    CreateThread(function()
                        DropPlayer(source, reason)
                    end)
                end
            end
            Wait(5000)
        end
    end)
end

-- Check if player is whitelisted, kept like this for backwards compatibility or future plans

function QBCore.Functions.IsWhitelisted(source)
    if not QBCore.Config.Server.Whitelist then return true end
    if QBCore.Functions.HasPermission(source, QBCore.Config.Server.WhitelistPermission) then return true end
    return false
end

-- Setting & Removing Permissions

function QBCore.Functions.AddPermission(source, permission)
    if not IsPlayerAceAllowed(source, permission) then
        ExecuteCommand(('add_principal player.%s qbcore.%s'):format(source, permission))
        QBCore.Commands.Refresh(source)
    end
end

function QBCore.Functions.RemovePermission(source, permission)
    if permission then
        if IsPlayerAceAllowed(source, permission) then
            ExecuteCommand(('remove_principal player.%s qbcore.%s'):format(source, permission))
            QBCore.Commands.Refresh(source)
        end
    else
        for _, v in pairs(QBCore.Config.Server.Permissions) do
            if IsPlayerAceAllowed(source, v) then
                ExecuteCommand(('remove_principal player.%s qbcore.%s'):format(source, v))
                QBCore.Commands.Refresh(source)
            end
        end
    end
end

-- Checking for Permission Level

function QBCore.Functions.HasPermission(source, permission)
    if type(permission) == "string" then
        if IsPlayerAceAllowed(source, permission) then return true end
    elseif type(permission) == "table" then
        for _, permLevel in pairs(permission) do
            if IsPlayerAceAllowed(source, permLevel) then return true end
        end
    end

    return false
end

function QBCore.Functions.GetPermission(source)
    local src = source
    local perms = {}
    for _, v in pairs(QBCore.Config.Server.Permissions) do
        if IsPlayerAceAllowed(src, v) then
            perms[v] = true
        end
    end
    return perms
end

-- Opt in or out of admin reports

function QBCore.Functions.IsOptin(source)
    local license = QBCore.Functions.GetIdentifier(source, 'license')
    if not license or not QBCore.Functions.HasPermission(source, 'admin') then return false end
    local Player = QBCore.Functions.GetPlayer(source)
    return Player.PlayerData.optin
end

function QBCore.Functions.ToggleOptin(source)
    local license = QBCore.Functions.GetIdentifier(source, 'license')
    if not license or not QBCore.Functions.HasPermission(source, 'admin') then return end
    local Player = QBCore.Functions.GetPlayer(source)
    Player.PlayerData.optin = not Player.PlayerData.optin
    Player.Functions.SetPlayerData('optin', Player.PlayerData.optin)
end

-- Check if player is banned

function QBCore.Functions.IsPlayerBanned(identifiers)
    local result = nil
    if not identifiers.license2 then
        result = MySQL.single.await('SELECT * FROM bans b INNER JOIN users u ON b.userid = u.userid WHERE u.license = ?', { identifiers.license })
    else
        result = MySQL.single.await('SELECT * FROM bans b INNER JOIN users u ON b.userid = u.userid WHERE u.license2 = ?', { identifiers.license2 })
    end
    if not result then return false end
    if os.time() < result.expire then
        local timeTable = os.date('*t', tonumber(result.expire))
        return true, 'You have been banned from the server:\n' .. result.reason .. '\nYour ban expires ' .. timeTable.day .. '/' .. timeTable.month .. '/' .. timeTable.year .. ' ' .. timeTable.hour .. ':' .. timeTable.min .. '\n'
    else
        MySQL.query('DELETE FROM bans WHERE id = ?', { result.id })
    end
    return false
end

-- Check for duplicate license

function QBCore.Functions.IsLicenseInUse(license)
    local players = GetPlayers()
    for _, player in pairs(players) do
        local identifiers = GetPlayerIdentifiers(player)
        for _, id in pairs(identifiers) do
            if string.find(id, 'license2') then
                if id == license then
                    return true
                end
            end
        end
    end
    return false
end

-- Utility functions

function QBCore.Functions.HasItem(source, items, amount)
    if GetResourceState('qb-inventory') == 'missing' then return end
    return exports['qb-inventory']:HasItem(source, items, amount)
end

function QBCore.Functions.Notify(source, text, type, length)
    TriggerClientEvent('QBCore:Notify', source, text, type, length)
end

---@class PlayerIdentifiers
---@field license string
---@field license2 string Preferred identifier; should always refer to Rockstar Social Club ID.
---@field discord? string
---@field fivem? string
---@field steam? string

---Return all identifiers for the given source.
---@param source number | string
---@return PlayerIdentifiers
function QBCore.Functions.GetIdentifiers(source)
    ---@cast source string
    local identifiers = {}

    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local prefix, identifier = string.strsplit(':', GetPlayerIdentifier(source, i))

        if prefix ~= 'ip' then
            identifiers[prefix] = identifier
        end
    end

    identifiers.license2 = identifiers.license2 or identifiers.license

    return identifiers
end

-- Database functions

local INSERT_USER = 'INSERT INTO `users` (`username`, `license`, `license2`, `steam`, `fivem`, `discord`) VALUES (?, ?, ?, ?, ?, ?)'
---Create a new user when a player first joins the server, and return their userid.
---@param username string
---@param identifiers {[string]: string}
---@return number?
function QBCore.Functions.CreateUser(username, identifiers)
    return MySQL.insert.await(INSERT_USER,
        { username, identifiers.license, identifiers.license2, identifiers.steam or '', identifiers.fivem or '', identifiers.discord or ''}) --[[@as number?]]
end

local SELECT_USERID = string.format('SELECT `userid` FROM `users` WHERE %s = ?', 'license2')
local SELECT_USERID_DESC = string.format('%s %s', SELECT_USERID, 'ORDER BY `userid` DESC')
---Select the userid for a player based on their identifier.
---@param identifier string
---@param newestFirst? boolean
---@return number?
function QBCore.Functions.getUserFromIdentifier(identifier, newestFirst)
    if not identifier then return nil end -- Sometimes the identifier is nil, so we need to check for that.
    return MySQL.scalar.await(newestFirst and SELECT_USERID_DESC or SELECT_USERID, { identifier })
end

local SELECT_CHARACTERS = 'SELECT p.citizenid, p.charinfo, p.money, p.job FROM `users` u INNER JOIN `characters` p ON u.`userid` = p.`userid` WHERE u.`license2` = ?'
---Select all characters owned for a player based on their identifier
---@param identifier string
---@return table
function QBCore.Functions.getCharactersFromLicense(identifier)
    return MySQL.query.await(SELECT_CHARACTERS, { identifier }) or {}
end
