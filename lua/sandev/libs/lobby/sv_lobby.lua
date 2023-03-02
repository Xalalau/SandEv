-- Mingenet: An automatic matchmaking system

--[[
    Welcome to my stupid system that connects players using databases with terrible delay!

    The whole fun here is in pushing the game boundaries and players' ideas. No personal
    data is transmitted and no obscure payloads are returned. The code is all documented and
    full of tests to leave no doubt!

    Also, don't mess with the functions! The values they use are calculated to make the
    connection viable. Manually decreasing intervals will just return repeated information
    and overload the poor server.

    Thanks,
    - Xalalau Xubilozo

    ________________________________________________________________________________________

    ### ABOUT THIS SYSTEM ###

    The main purpose of this file is to initialize the lobby server, also called Mingenet, and keep the
    players synchronized with the time windows when the different interactions will be accepted. The service
    is running on my own host and it's able to start multiple simultaneous lobbies with a nice multiplayer
    support. To be more specific, it can connect as many games with as many players as I want (until GMod
    freezes, of course). For example:

     singleplayer    multiplayer     multiplayer    pure non-sense
    |           |   | pa        |   |      p-   |   | pa   p-   |
    |           | + |           | + |           | = |           |
    |  p1       |   |        pb |   |           |   |  p1    pb |
    |           |   | pc        |   |    p_     |   | pc p_     |

    That's it. I hope you enjoy!

    Server files (summing up):

        ping -> info -> apply -> check -> play

        ping.php  : check if the server and it's database are accessible, return the current number of players
        info.php  : initialize a new lobby, create and control the waiting list, return the timing information
        apply.php : move the players form the waiting list to the candidate list
        check.php : randomly select players, cleans the candidate list, return if the player was selected
        play.php  : connects the selected players on each lobby until the encounter is over

        When I finish the system and the events I'll release these files.
        [Update] https://github.com/Xalalau/mingenet
                 There it is. Obviously you can improve the system a lot, so enjoy.
]]

-- Print some nice messages
function SEv.Lobby:PrintStatus(message)
    if self.instance.devMode then
        net.Start("sev_lobby_debug_text")
        net.WriteString(message)
        net.Broadcast()
    end
end

-- Select a server
function SEv.Lobby:SelectBestServer(tryingServerId, lastPlayersQuantity, lastBestServer)
    if not tryingServerId then
        self.isEnabled = true
        self:PrintStatus("Searching for the best server...")
        tryingServerId = 1
    end

    local function SelectNext()
        if not self.isEnabled then return end

        local nextServer = self.servers[tryingServerId + 1] and (tryingServerId + 1) or -1
        self:SelectBestServer(nextServer, lastPlayersQuantity, lastBestServer)
    end

    if tryingServerId ~= -1 and lastPlayersQuantity ~= 1 then
        hook.Run(self.instance.id .."_lobby_select_server")

        http.Post(self.servers[tryingServerId] .. "ping.php?db=" .. self.selectedServerDB,
            {},
            function(body, length, headers, code)
                local result = body

                if self.printResponses then
                    print(body)
                end

                if result == "-1" then
                    self:PrintStatus(self.servers[tryingServerId] .. " database is down. Trying the next server...")
                    SelectNext()
                else
                    result = tonumber(result)

                    if not lastPlayersQuantity or result > 0 and result < lastPlayersQuantity then
                        lastBestServer = self.servers[tryingServerId]
                        lastPlayersQuantity = result
                    end

                    SelectNext()
                end
            end,
            function(message)
                SelectNext()
            end
        )
    else
        if not lastPlayersQuantity then
            self:PrintStatus("All servers are down. Disabling event...")
            self:Exit()
        else
            self.selectedServerLink = lastBestServer
            self:PrintStatus("Selected " .. lastBestServer .. " database " .. self.selectedServerDB .. " with currently " .. lastPlayersQuantity .. " entries registered.")
            self:GetInfo()
        end
    end
end

function SEv.Lobby:GetInfo()
    if not self.isEnabled then return end
    hook.Run(self.instance.id .."_lobby_get_info")

    self:PrintStatus("Getting server info...")

    local plyData = { 
        gameID = tostring(self.gameID),
        map = game.GetMap(),
        version = self.version,
        plyNum = tostring(#player.GetHumans())
    }

    http.Post(self.selectedServerLink .. "info.php?db=" .. self.selectedServerDB,
        plyData,
        function(body, length, headers, code)
            local lobbyInfo = util.JSONToTable(body)

            if self.printResponses then
                print(body)
            end

            if lobbyInfo and lobbyInfo["is_updated"] and not lobbyInfo["force_disconnect"] then
                self:PrintStatus("Success.")

                local delayTolerance = 2 -- Tolerance lets us steal a little time from the invader spawn to allow the connection. Sadly it's necessary due to delays coming from http communication and rounding off seconds in the server.

                local tooEarly = lobbyInfo["next_lobby_s"] > lobbyInfo["accept_info_s"] + lobbyInfo["start_checks_s"]
                local tooLate = lobbyInfo["next_lobby_s"] < lobbyInfo["accept_info_s"] + lobbyInfo["start_checks_s"] - delayTolerance
                local inTime = not(tooEarly or tooLate)

                if self.isNewEntry or not inTime then
                    self:SyncWithServerTimes(lobbyInfo, tooEarly, tooLate, inTime)
                else
                    if lobbyInfo["cur_entries_num"] > 1 then
                        self:ApplyIn(lobbyInfo, delayTolerance)
                    else
                        local timeUntilNewLobby = lobbyInfo["next_lobby_s"] + 1
                        self:PrintStatus("Not enouth players. Waiting " .. timeUntilNewLobby .. "s to start a new lobby...")

                        timer.Create(self.instance.id .."_lobby_wait_until_next_one", timeUntilNewLobby, 1, function()
                            self:GetInfo()
                        end)
                    end
                end

                if self.isNewEntry then
                    self.isNewEntry = false
                end
            else
                if lobbyInfo then
                    if not lobbyInfo["is_updated"] then
                        PrintMessage(HUD_PRINTTALK, "Attention! The mingebags addon has been updated and you need to restart the game to download the files. The addon will not work until you do this.")
                    end

                    if lobbyInfo["force_disconnect"] then
                        print("The mingebags are temporarily rejecting you.")
                    end
                end

                self:PrintStatus("Error.")
                self:Exit()
            end
        end,
        function(message)
            if not self.isEnabled then return end

            self:PrintStatus("Server is down.")
            self:Exit()
            self:SelectBestServer()
        end
    )
end

-- Sync with the server lobby times
function SEv.Lobby:SyncWithServerTimes(lobbyInfo, tooEarly, tooLate, inTime)
    if not self.isEnabled then return end
    -- The server is waiting for the player application phase
    if tooEarly then
        -- Seconds to the moment all players start the lobby checking phase
        local timeStartSendingInfo = lobbyInfo["next_lobby_s"] - (lobbyInfo["accept_info_s"] + lobbyInfo["start_checks_s"])

        -- Extra sync to combat desync
        if timeStartSendingInfo > lobbyInfo["extra_sync_s"] then
            hook.Run(self.instance.id .."_lobby_sync_extra")

            local timeExtraSync = timeStartSendingInfo - lobbyInfo["extra_sync_s"]

            self:PrintStatus("Start syncing with server times. Waiting " .. timeExtraSync .. " seconds...")

            timer.Create(self.instance.id .."_lobby_extra_sync", timeExtraSync, 1, function()
                self:PrintStatus("Syncing done.")
                self:GetInfo()
            end)
        -- Wait until the exact moment of the check phase and setup lobby checking
        else
            hook.Run(self.instance.id .."_lobby_sync")

            self:PrintStatus("Waiting " .. timeStartSendingInfo .. " seconds for the application stage...")

            timer.Create(self.instance.id .."_lobby_start_sending_info", timeStartSendingInfo, 1, function()
                self:PrintStatus("Syncing done.")
                self:GetInfo()
            end)
        end
    -- The server is in the player selection phase. 
    elseif tooLate or self.isNewEntry and inTime then
        hook.Run(self.instance.id .."_lobby_sync_late")

        self:PrintStatus("Too late to sync! Trying again in " .. (lobbyInfo["next_lobby_s"] + 1) .. " seconds.")

        timer.Create(self.instance.id .."_lobby_too_late", lobbyInfo["next_lobby_s"] + 1, 1, function()
            self:GetInfo()
        end)
    end
end

-- Apply for a spot in the next lobby
function SEv.Lobby:ApplyIn(lobbyInfo, delayTolerance)
    if not self.isEnabled then return end
    hook.Run(self.instance.id .."_lobby_apply_in")

    local timeUntilStartChecks = lobbyInfo["accept_info_s"]
    local infoDispersion = math.random(delayTolerance, timeUntilStartChecks) - delayTolerance
    timeUntilStartChecks = timeUntilStartChecks - infoDispersion

    -- Refresh the player's information before the server decides the lobby (avoiding too many requests at the same time)
    timer.Create(self.instance.id .."_lobby_info_dispersion", infoDispersion, 1, function()
        local entryData = {
            gameID = tostring(self.gameID),
            map = game.GetMap(),
            plyNum = tostring(#player.GetHumans())
        }

        http.Post(self.selectedServerLink .. "apply.php?db=" .. self.selectedServerDB,
            entryData,
            function(body, length, headers, code)
                local result = body

                if self.printResponses then
                    print(body)
                end

                if result == "1" then
                    self:PrintStatus("Success.")
                    self:Check(lobbyInfo, timeUntilStartChecks, delayTolerance)
                else
                    self:PrintStatus("Error.")
                    self:Exit()
                end
            end,
            function(message)
                if not self.isEnabled then return end

                self:PrintStatus("Server is down.")
                self:Exit()
                self:SelectBestServer()
            end
        )
    end)

    self:PrintStatus("Applying for the lobby in " .. tostring(math.Round(infoDispersion, 2)) .. "s with " .. lobbyInfo["cur_entries_num"] .. " entries registered...")
end

-- Check if the server selected this player for the next lobby (avoiding too many requests at the same time)
function SEv.Lobby:Check(lobbyInfo, timeUntilStartChecks, delayTolerance)
    if not self.isEnabled then return end
    hook.Run(self.instance.id .."_lobby_check")

    local checkDispersion = math.random(delayTolerance, lobbyInfo["start_checks_s"]) - delayTolerance
    local timeUntilLobbyStarts = lobbyInfo["start_checks_s"] - checkDispersion

    self:PrintStatus("Checking if you'll be randomly selected for the lobby in " .. tostring(math.Round((timeUntilStartChecks + checkDispersion), 1)) .. "s...")

    self.lobbyChecks = self.lobbyChecks + 1

    timer.Create(self.instance.id .."_lobby_check", timeUntilStartChecks + checkDispersion, 1, function()
        local entryData = {
            gameID = tostring(self.gameID)
        }

        http.Post(self.selectedServerLink .. "check.php?db=" .. self.selectedServerDB,
            entryData,
            function(body, length, headers, code)
                local result = body

                if self.printResponses then
                    print(body)
                end

                -- If the player has been selected, start exchanging information at the exact moment the lobby opens
                if result == "1" then
                    self:PrintStatus("YEP. Waiting " .. tostring(math.Round(timeUntilLobbyStarts, 2)) .. "s to join...")

                    timer.Create(self.instance.id .."_lobby_success_join", timeUntilLobbyStarts, 1, function()
                        self:Join(lobbyInfo["tick_s"], lobbyInfo["playing_time_s"], delayTolerance)
                    end)

                    timer.Remove(self.instance.id .."_lobby_apply_in")
                else
                    if self.lobbyChecks == self.lobbyChecksLimit then
                        self:PrintStatus("The player failed to join " .. self.lobbyChecksLimit .. " times. Stopping the event...")
                        self:Exit()
                    else
                        local reeteringDispersion = math.random(1, 10)
                        local timeUntilReenter = timeUntilLobbyStarts + reeteringDispersion

                        self:PrintStatus("NOPE. Re-entering the lobby creation system in " .. timeUntilReenter .. "s...")

                        timer.Create(self.instance.id .."_lobby_fail_join", timeUntilReenter, 1, function()
                            self:GetInfo()
                        end)
                    end
                end
            end,
            function(message)
                if not self.isEnabled then return end

                self:PrintStatus("Server is down.")
                self:Exit()
                self:SelectBestServer()
            end
        )
    end)
end

-- Join the starting lobby
-- Note: The server (and not this function) defines who is in the lobby!
function SEv.Lobby:Join(tick_s, playing_time_s, delayTolerance, localMode)
    if not self.isEnabled and not localMode then return end
    hook.Run(self.instance.id .."_lobby_play")

    self:PrintStatus("Joining the lobby and starting event...")

    -- Player management

    local plyList = {}

    local function GetPlyData(ply)
        plyList[tostring(ply:EntIndex())] = plyList[tostring(ply:EntIndex())] or {}
        return plyList[tostring(ply:EntIndex())]
    end

    for k, ply in ipairs(player.GetHumans()) do
        ply:SetNWInt(self.instance.id .."_lobby", 0)
    end

    -- Simulate damage

    hook.Add("EntityTakeDamage", self.instance.id .."_lobby_check_invader_damage", function(target, dmginfo)
        if target:GetClass() == self.invaderClass then
            local attacker = dmginfo:GetAttacker()

            if attacker and attacker:IsValid() and attacker:IsPlayer() and attacker:GetNWInt(self.instance.id .."_lobby") == 1 then
                if math.random(1, 100) <= 50 then
                    target.sev_hit_counter = target.sev_hit_counter or 0
                    target.sev_hit_counter = target.sev_hit_counter + 1

                    if target.sev_hit_counter > 5 then
                        GetPlyData(attacker)["invaderInjured"] = target:GetName()
                    end
                end
            end
        end
    end)

    -- Firing

    hook.Add("KeyPress", self.instance.id .."_lobby_check_key_pressed", function(ply, key)
        if key == IN_ATTACK then
            local mode = 1
            local weapon = ply:GetActiveWeapon()
            if weapon and weapon:IsValid() and weapon:GetClass() == "weapon_physgun" then
                mode = 2
            end

            GetPlyData(ply)["isFiring"] = mode
        end
    end)

    hook.Add("KeyRelease", self.instance.id .."_lobby_check_key_released", function(ply, key)
        if key == IN_ATTACK then
            GetPlyData(ply)["stoppedFiring"] = 1 -- This is so that I always send at least 1 shot. People release mouse 1 too fast.
        end
    end)

    -- Chat

    hook.Add("PlayerSay", self.instance.id .."_lobby_check_message", function(ply)
        GetPlyData(ply)["usedChat"] = 1
    end)

    -- Alert

    local alertedPlayers = false

    -- Start event

    local microDispersion = math.random(0, 1000) / 10000
    local toleranceRepetitions = delayTolerance / tick_s
    local safetyRepetitions = 5
    local repetitions = playing_time_s / tick_s + toleranceRepetitions + safetyRepetitions

    timer.Create(self.instance.id .."_lobby_join_dispersion", microDispersion, 1, function()
        if not self.isEnabled and not localMode then return end

        timer.Create(self.instance.id .."_lobby_connect_lobby", tick_s, repetitions, function()
            -- Gather the important information

            local entryData = {}

            for k, ply in ipairs(player.GetHumans()) do
                local plyData = GetPlyData(ply)

                local plyPos = ply:GetPos()
                plyPos = tostring(math.Round(plyPos.x, 2)) .. "," .. tostring(math.Round(plyPos.y, 2)) .. "," .. tostring(math.Round(plyPos.z, 2))
    
                local plyAng
                if ply:InVehicle() then
                    plyAng = ply:GetVehicle():LocalToWorldAngles(ply:EyeAngles())
                else
                    plyAng = ply:EyeAngles()
                end
                plyAng = tostring(math.Round(plyAng.x, 2)) .. "," .. tostring(math.Round(plyAng.y, 2)) .. "," .. tostring(math.Round(plyAng.z, 2))

                local usedChat = plyData["usedChat"] or 0
                local isFiring = plyData["isFiring"] or 0
                local stoppedFiring = plyData["stoppedFiring"] or 0
                local invaderInjured = plyData["invaderInjured"] or ""

                local key = tostring(ply:EntIndex())
                local value = util.TableToJSON({
                    gameID = tostring(self.gameID),
                    pos = plyPos,
                    ang = plyAng,
                    used_chat = tostring(usedChat),
                    is_firing = tostring(isFiring),
                    invader_injured = invaderInjured
                })

                entryData[key] = value

                if plyData["invaderInjured"] then
                    plyData["invaderInjured"] = nil
                end

                if plyData["usedChat"] then
                    plyData["usedChat"] = nil
                end

                if plyData["isFiring"] and plyData["stoppedFiring"] then
                    plyData["isFiring"] = nil
                    plyData["stoppedFiring"] = nil
                end
            end

            -- Update encounter

            if localMode then
                for entIndex, plyData in pairs(entryData) do
                    local ply = ents.GetByIndex(tonumber(entIndex))

                    if ply:GetNWInt(self.instance.id .."_lobby") == 0 then
                        ply:SetNWInt(self.instance.id .."_lobby", 1)
                    end

                    local pos = string.Explode(",", plyData.pos, false)
                    local ang = string.Explode(",", plyData.ang, false)

                    plyData.pos = Vector(pos[1] - 100, pos[2] + 100, pos[3])                        
                    plyData.ang = Angle(ang[1], ang[2], ang[3])
                    plyData.is_firing = tonumber(plyData.is_firing)
                    plyData.used_chat = plyData.used_chat == "1"
                    plyData.invader_injured = nil
                    plyData.status = 0

                    local fakeData = {
                        ['players'] = {},
                        ['invaders'] = { [tostring(ply:EntIndex())] = plyData }
                    }

                    hook.Run(self.instance.id .."_lobby_data", fakeData, tick_s, playing_time_s)
                end
            else
                http.Post(self.selectedServerLink .. "play.php?db=" .. self.selectedServerDB,
                    entryData,
                    function(body, length, headers, code)
                        local result = body
                        local data = util.JSONToTable(result)

                        if self.printResponses then
                            print(body)
                        end

                        if not data or not self.isEnabled then return end

                        -- Enter lobby + no godmode
                        for k, ply in ipairs(player.GetHumans()) do
                            if ply:GetNWInt(self.instance.id .."_lobby") == 0 then
                                ply:SetNWInt(self.instance.id .."_lobby", 1)
                            end

                            ply:GodDisable()
                        end

                        -- Format and use data
                        if data['players'] then
                            local toRemove = {}
                            for entIndex, invaderData in pairs(data['invaders']) do
                                if invaderData.status ~= "ongoing" then
                                elseif not invaderData.pos then
                                    table.insert(toRemove, entIndex)
                                else
                                    local pos = string.Explode(",", invaderData.pos, false)
                                    local ang = string.Explode(",", invaderData.ang, false)

                                    invaderData.pos = Vector(pos[1], pos[2], pos[3])
                                    invaderData.ang = Angle(ang[1], ang[2], ang[3])
                                    invaderData.is_firing = tonumber(invaderData.is_firing)
                                    invaderData.used_chat = invaderData.used_chat == "1"
                                end
                            end
                            if next(toRemove) then
                                for k, entIndex in ipairs(toRemove) do
                                    data['invaders'][entIndex] = nil
                                end
                            end

                            hook.Run(self.instance.id .."_lobby_data", data, tick_s, playing_time_s)
                        end

                        -- Inform the server about the start of the lobby
                        -- This runs as soon as there is invader information available
                        if not alertedPlayers and data['invaders'] and table.Count(data['invaders']) > 0 then
                            hook.Run(self.instance.id .."_lobby_event_started", data)
                            alertedPlayers = true
                        end

                        -- Lobby result (maxtime, unsolved, survived, nolobby, defeated)
                        if data['result'] then
                            self:Exit()
                            hook.Run(self.instance.id .."_lobby_result", data['result'])
                        end

                        -- Safety stop (the timer is suposed to always stop before it ends)
                        if timer.RepsLeft(self.instance.id .."_lobby_connect_lobby") == 0 then
                            self:Exit()
                            hook.Run(self.instance.id .."_lobby_result", "maxtime")
                        end
                    end,
                    function(message)
                        if not self.isEnabled then return end

                        self:PrintStatus("Server is down.")
                        self:Exit()
                        self:SelectBestServer()
                    end
                )
            end
        end)
    end)

    -- Finish event
    timer.Create(self.instance.id .."_lobby_disconnect_lobby", playing_time_s + microDispersion, 1, function()
        timer.Remove(self.instance.id .."_lobby_connect_lobby")
    end)
end

-- Force disconnect the player from the Mingenet
function SEv.Lobby:ForceDisconnect()
    if not self.isEnabled then return end

    timer.Remove(self.instance.id .."_lobby_connect_lobby")

    local entryData = {}

    for k, ply in ipairs(player.GetHumans()) do
        local key = tostring(ply:EntIndex())
        local value = util.TableToJSON({
            gameID = tostring(self.gameID),
            disconnected = "true"
        })

        entryData[key] = value
    end

    if self.selectedServerLink ~= "" then
        http.Post(self.selectedServerLink .. "play.php?db=" .. self.selectedServerDB,
            entryData,
            function(body, length, headers, code)
                self:PrintStatus("Forced to stop.")

                if self.printResponses then
                    print(body)
                end

                return
            end
        )
    end

    hook.Run(self.instance.id .."_lobby_result", "stopped")
    self:Exit()
end

-- Fully stop the lobby system
function SEv.Lobby:Exit()
    hook.Run(self.instance.id .."_lobby_exit")

    self.isEnabled = false
    self.isNewEntry = true
    self.selectedServerLink = ""
    self.lobbyChecks = 0
    timer.Remove(self.instance.id .."_lobby_connect_lobby")
    timer.Remove(self.instance.id .."_lobby_disconnect_lobby")
    timer.Remove(self.instance.id .."_lobby_check_invader_damage")
    timer.Remove(self.instance.id .."_lobby_wait_until_next_one")
    timer.Remove(self.instance.id .."_lobby_extra_sync")
    timer.Remove(self.instance.id .."_lobby_start_sending_info")
    timer.Remove(self.instance.id .."_lobby_too_late")
    timer.Remove(self.instance.id .."_lobby_info_dispersion")
    timer.Remove(self.instance.id .."_lobby_check")
    timer.Remove(self.instance.id .."_lobby_success_join")
    timer.Remove(self.instance.id .."_lobby_fail_join")
    timer.Remove(self.instance.id .."_lobby_join_dispersion")
    hook.Remove("KeyPress", self.instance.id .."_lobby_check_key_pressed")
    hook.Remove("KeyRelease", self.instance.id .."_lobby_check_key_released")
    hook.Remove("OnPlayerChat", self.instance.id .."_lobby_check_message")
end