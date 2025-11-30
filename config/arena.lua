Game = {
    uno = {
        start = vector3(288.1491, -1601.0288, 31.2597),
        uno = vector3(-3304.8625, -2001.8826, 257.0356),
        due = vector3(-3304.6270, -1955.6007, 257.0353)
    }
}

PVP = {
    ESX = true,
    Afk = true,
    Round = 5,
    Weapon = 'WEAPON_PISTOL_MK2',
    Ammo = 'ammo-9',
    
    Translate_Start = "Premi [E] Per Iniziare",
    Translate_GameStarted = "Partita iniziata /leave per abbandonare | Sei Contro",
    Translate_Stop = "Premi [E] Per Uscire dall'attesa!",
    Translate_Coda = "Sei entrato in attesa!",
    Translate_EnterMatch = "Stai partecipando al Match #:",
    Translate_EnterMatch2 = "Il Tuo Avversario è: ",
    Translate_Stopped = "Partita Finita!",
    
    -- Impostazioni NPC
    NPC = {
        Enabled = true,
        Model = 's_m_y_ammucity_01',
        Coords = vector3(288.1491, -1601.0288, 31.2597),
        Scenario = 'WORLD_HUMAN_CLIPBOARD',
        Marker = {
            Type = -1,
            Size = vector3(0.3, 0.3, 0.2),
            Color = {r = 255, g = 0, b = 0, a = 100},
            DrawDistance = 20.0
        }
    }
}

-- Funzione di rianimazione migliorata
Revive = function()
    local playerPed = PlayerPedId()
    SetEntityHealth(playerPed, GetEntityMaxHealth(playerPed))
    ClearPedBloodDamage(playerPed)
    ResetPedMovementClipset(playerPed, 0)
    ResetPedWeaponMovementClipset(playerPed)
    ResetPedStrafeClipset(playerPed)
    SetPedArmour(playerPed, 0)
    TriggerEvent('atx_death:revivePlayer')
end

-- Notifica unificata
Notifica = function(msg)
    if ESX then
        ESX.ShowNotification(msg)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end