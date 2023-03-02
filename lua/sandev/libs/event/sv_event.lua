-- Events base

-- Send all custom events to a player or all players
function SEv.Event:SendCustomEnts(ply)
    if not self.instance.devMode then return end

    local sendTab = {}
    local currentChunksID = tostring(sendTab)

    self.lastSentChunksID = currentChunksID

    for eventName, eventEntlist in pairs(self.customEntityList) do
        for ent, entRenderInfo in pairs(eventEntlist) do
            if not ent:IsValid() then
                self.customEntityList[ent] = nil
            else
                table.insert(sendTab, self:GetEntityRenderInfo(ent))
            end
        end
    end

    local sendTab = util.Compress(util.TableToJSON(sendTab))
    local totalSize = string.len(sendTab)
    local chunkSize = 3000 -- 3KB
    local totalChunks = math.ceil(totalSize / chunkSize)

    for i = 1, totalChunks, 1 do
        local startByte = chunkSize * (i - 1) + 1
        local remaining = totalSize - (startByte - 1)
        local endByte = remaining < chunkSize and (startByte - 1) + remaining or chunkSize * i
        local chunk = string.sub(sendTab, startByte, endByte)

        timer.Simple(i * 0.1, function()
            if self.lastSentChunksID ~= currentChunksID then return end

            local isLastChunk = i == totalChunks

            net.Start(self.instance.id .. "_event_send_all_render_cl")
            net.WriteString(currentChunksID)
            net.WriteUInt(#chunk, 16)
            net.WriteData(chunk, #chunk)
            net.WriteBool(isLastChunk)
            if ply then
                net.Send(ply)
            else
                net.Broadcast()
            end
        end)
    end
end

-- Exposed interface to change events tier
local undoingInvalidTier = false
function SEv.Event:ChangeTier(oldTier, newTier, forceNewTier)
    if undoingInvalidTier then
        undoingInvalidTier = false
        return
    end

    local maxTier = self:GetMaxPossibleTier()
    oldTier = tonumber(oldTier)
    newTier = tonumber(newTier)

    if not isnumber(newTier) or (newTier ~= math.floor(newTier)) or not (forceNewTier or self.instance.devMode) and (newTier < 1 or newTier > 4) then
        undoingInvalidTier = true
        RunConsoleCommand(self.instance.id .. "_tier", oldTier)
        print("Invalid tier. Choose between 1 and 4.")

        return
    end

    if oldTier ~= newTier or forceNewTier then
        if not (forceNewTier or self.instance.devMode) and newTier > maxTier then
            undoingInvalidTier = true
            RunConsoleCommand(self.instance.id .. "_tier", oldTier)
            print("Sorry, not enough power to increase the tier.")
    
            return
        end

        self:InitializeTier()

        if oldTier then -- A single person managed to run this with an uninitialized oldTier, so I added a check.
            print("gm_construct 13 beta " .. (forceNewTier and "forced" or (oldTier > newTier) and "decreased" or "increased") .. " to tier " .. newTier .. ".")
        end
    end
end

-- Reset the map
function SEv.Event:Reset()
    SEv.Map:BlockCleanup(false)
    self:RemoveAll()
    self.Memory:Reset()
    hook.Run(self.instance.id .. "_reset")

    local pesistentFolder = self.instance.dataFolder .. "/persistent"
    if file.Exists(pesistentFolder, "DATA") then
        local files, dirs = file.Find(pesistentFolder .. "/*", "DATA")

        for k, filename in ipairs(files) do
            file.Delete(pesistentFolder .. "/" .. filename)
        end
    end

    timer.Simple(0.3, function()
        game.CleanUpMap()

        timer.Simple(1, function()
            tier = GetConVar(self.instance.id .. "_tier"):GetInt(1)

            if tier == 1 then
                self:ChangeTier(1, 1, true)
            else
                GetConVar(self.instance.id .. "_tier"):SetInt(1)
            end
        end)
    end)
end

-- Instance init
function SEv.Event:InitSv(instance)
    -- New players, devMode: ask for entities information to enable rendering their areas
    net.Receive(instance.id .. "_event_request_all_render_sv", function(len, ply)
        instance.Event:SendCustomEnts(ply)
    end)

    -- Cvar callbacks
    cvars.AddChangeCallback(instance.id .. "_tier", function(cvarName, oldTier, newTier)
        instance.Event:ChangeTier(oldTier, newTier)
    end)

    concommand.Add(instance.id .. "_reset", function(ply, cmd, args)
        if args[1] ~= "yes" then
            print("If you want to force the map back to its initial state, type \"" .. instance.id .. "_reset yes\".")
        else
            instance.Event:Reset()
            print("The map has been deeply cleaned, but restart it if you find any remains.")
        end
    end)

    instance.Event.InitSv = nil
end