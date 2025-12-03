--[[
    ARENA PVP - SERVER
    Versione completamente riscritta
]]

ESX = nil

-- Variabili (definite prima)
local queue = {}
local matchId = 0
local leaderboard = {}

-- Funzione LoadLeaderboard (definita PRIMA di essere chiamata)
function LoadLeaderboard()
    MySQL.Async.fetchAll('SELECT * FROM pvp_leaderboard ORDER BY wins DESC, kills DESC LIMIT 10', {}, function(results)
        leaderboard = results or {}
        TriggerClientEvent('PVP:updateLeaderboard', -1, leaderboard)
    end)
end

-- Init ESX
Citizen.CreateThread(function()
    if PVP.ESX then
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Wait(100)
        if ESX == nil then
            ESX = exports.es_extended:getSharedObject()
        end
    end
end)

-- Database
MySQL.ready(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS pvp_leaderboard (
            identifier VARCHAR(60) PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            kills INT DEFAULT 0,
            wins INT DEFAULT 0,
            losses INT DEFAULT 0,
            matches INT DEFAULT 0
        )
    ]])
    print('[PVP] Database pronto')
    LoadLeaderboard()
end)

-- =====================
-- QUEUE SYSTEM
-- =====================

RegisterNetEvent('PVP:JoinQueue')
AddEventHandler('PVP:JoinQueue', function()
    local src = source
    
    -- Già in coda?
    for _, id in ipairs(queue) do
        if id == src then
            TriggerClientEvent('PVP:Notify', src, "Sei già in coda!")
            return
        end
    end
    
    table.insert(queue, src)
    TriggerClientEvent('PVP:Notify', src, "Sei entrato in coda!")
    BroadcastQueueCount()
    
    -- Match?
    if #queue >= 2 then
        local p1 = queue[1]
        local p2 = queue[2]
        table.remove(queue, 1)
        table.remove(queue, 1)
        
        StartMatch(p1, p2)
    end
end)

RegisterNetEvent('PVP:LeaveQueue')
AddEventHandler('PVP:LeaveQueue', function()
    local src = source
    for i = #queue, 1, -1 do
        if queue[i] == src then
            table.remove(queue, i)
        end
    end
    TriggerClientEvent('PVP:QueueLeft', src)
    BroadcastQueueCount()
end)

function BroadcastQueueCount()
    TriggerClientEvent('PVP:QueueUpdate', -1, #queue)
end

-- Rimuovi da coda se disconnette
AddEventHandler('playerDropped', function()
    local src = source
    for i = #queue, 1, -1 do
        if queue[i] == src then
            table.remove(queue, i)
        end
    end
    BroadcastQueueCount()
end)

-- =====================
-- MATCH SYSTEM
-- =====================

function StartMatch(p1, p2)
    matchId = matchId + 1
    
    -- Routing bucket separato
    SetPlayerRoutingBucket(p1, matchId)
    SetPlayerRoutingBucket(p2, matchId)
    
    -- Notifica client
    TriggerClientEvent('PVP:MatchFound', p1, p1, p2, p2)
    TriggerClientEvent('PVP:MatchFound', p2, p2, p1, p1)
    
    BroadcastQueueCount()
    
    -- Log Discord
    if PVPlogs and PVPlogs.Weebhooks ~= "" then
        local name1 = GetPlayerName(p1)
        local name2 = GetPlayerName(p2)
        SendDiscordLog("Match #" .. matchId .. " iniziato: " .. name1 .. " VS " .. name2)
    end
end

RegisterNetEvent('PVP:PlayerDied')
AddEventHandler('PVP:PlayerDied', function(enemyId)
    local src = source
    -- Revive entrambi i giocatori dal server
    TriggerClientEvent('OI_DeathClient:RevivePlayer', src)
    TriggerClientEvent('OI_DeathClient:RevivePlayer', enemyId)
    -- Chi è morto ha perso il round, l'altro ha vinto
    TriggerClientEvent('PVP:RoundLost', src)
    TriggerClientEvent('PVP:RoundWon', enemyId)
end)

RegisterNetEvent('PVP:LeaveMatch')
AddEventHandler('PVP:LeaveMatch', function(enemyId)
    local src = source
    EndMatch(src, enemyId)
end)

RegisterNetEvent('PVP:MatchEnd')
AddEventHandler('PVP:MatchEnd', function(myScore, enemyId)
    local src = source
    
    -- Calcola vincitore
    local iWon = myScore > (PVP.Round - myScore)
    
    -- Update stats
    UpdateStats(src, myScore, iWon and 1 or 0)
    UpdateStats(enemyId, PVP.Round - myScore, iWon and 0 or 1)
    
    EndMatch(src, enemyId)
end)

function EndMatch(p1, p2)
    -- Torna routing normale
    SetPlayerRoutingBucket(p1, 0)
    SetPlayerRoutingBucket(p2, 0)
    
    -- Revive entrambi i giocatori
    TriggerClientEvent('OI_DeathClient:RevivePlayer', p1)
    TriggerClientEvent('OI_DeathClient:RevivePlayer', p2)
    
    -- Notifica fine
    TriggerClientEvent('PVP:MatchEnded', p1)
    TriggerClientEvent('PVP:MatchEnded', p2)
    
    -- Rimuovi armi se ESX
    if PVP.ESX and ESX then
        local xP1 = ESX.GetPlayerFromId(p1)
        local xP2 = ESX.GetPlayerFromId(p2)
        if xP1 then xP1.removeInventoryItem(PVP.Weapon, 1) end
        if xP2 then xP2.removeInventoryItem(PVP.Weapon, 1) end
    end
end

-- =====================
-- STATS & LEADERBOARD
-- =====================

function UpdateStats(playerId, kills, win)
    local xPlayer = ESX and ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    local id = xPlayer.identifier
    local name = xPlayer.getName()
    
    MySQL.Async.execute([[
        INSERT INTO pvp_leaderboard (identifier, name, kills, wins, losses, matches)
        VALUES (@id, @name, @kills, @wins, @losses, 1)
        ON DUPLICATE KEY UPDATE
            name = @name,
            kills = kills + @kills,
            wins = wins + @wins,
            losses = losses + @losses,
            matches = matches + 1
    ]], {
        ['@id'] = id,
        ['@name'] = name,
        ['@kills'] = kills,
        ['@wins'] = win,
        ['@losses'] = win == 1 and 0 or 1
    }, function()
        LoadLeaderboard()
    end)
end

RegisterNetEvent('PVP:requestLeaderboard')
AddEventHandler('PVP:requestLeaderboard', function()
    TriggerClientEvent('PVP:updateLeaderboard', source, leaderboard)
end)

RegisterNetEvent('PVP:requestPlayerStats')
AddEventHandler('PVP:requestPlayerStats', function()
    local src = source
    local xPlayer = ESX and ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    MySQL.Async.fetchAll('SELECT * FROM pvp_leaderboard WHERE identifier = @id', {
        ['@id'] = xPlayer.identifier
    }, function(results)
        local stats = { wins = 0, losses = 0, kills = 0, matches = 0 }
        if results and results[1] then
            stats = results[1]
        end
        TriggerClientEvent('PVP:updatePlayerStats', src, stats)
    end)
end)

-- =====================
-- ESX WEAPON GIVE
-- =====================

RegisterNetEvent('PVP_esx')
AddEventHandler('PVP_esx', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        xPlayer.addInventoryItem(PVP.Weapon, 1)
        xPlayer.addInventoryItem(PVP.Ammo, 200)
    end
end)

-- =====================
-- DISCORD LOG
-- =====================

function SendDiscordLog(msg)
    if PVPlogs and PVPlogs.Weebhooks and PVPlogs.Weebhooks ~= "" then
        PerformHttpRequest(PVPlogs.Weebhooks, function() end, 'POST', json.encode({
            embeds = {{
                title = "Arena PVP",
                description = msg,
                color = 65535
            }}
        }), { ['Content-Type'] = 'application/json' })
    end
end
