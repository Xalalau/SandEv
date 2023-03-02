-- Send huge string
function SEv.Net:SendString(str, callbackName, ply)
    local chunksID = util.MD5(str)
    local compressedString = util.Compress(str)

    SEv.Net:SendData(chunksID, compressedString, callbackName, ply, true)
end

-- Send huge binary
function SEv.Net:SendData(chunksID, data, callbackName, toPly, isCompressedString)
    local chunksSubID = SysTime()

    local totalSize = string.len(data)
    local chunkSize = 64000 -- ~64KB max
    local totalChunks = math.ceil(totalSize / chunkSize)

    -- 3 minutes to remove possible memory leaks
    SEv.Net.sendTab[chunksID] = chunksSubID
    timer.Create(chunksID, 180, 1, function()
        SEv.Net.sendTab[chunksID] = nil
    end)

    for i = 1, totalChunks, 1 do
        local startByte = chunkSize * (i - 1) + 1
        local remaining = totalSize - (startByte - 1)
        local endByte = remaining < chunkSize and (startByte - 1) + remaining or chunkSize * i
        local chunk = string.sub(data, startByte, endByte)

        timer.Simple(i * 0.1, function()
            if SEv.Net.sendTab[chunksID] ~= chunksSubID then return end

            local isLastChunk = i == totalChunks

            net.Start("sev_net_send_string")
            net.WriteString(chunksID)
            net.WriteUInt(SEv.Net.sendTab[chunksID], 32)
            net.WriteUInt(#chunk, 16)
            net.WriteData(chunk, #chunk)
            net.WriteBool(isLastChunk)
            net.WriteBool(tobool(isCompressedString))
            if isLastChunk then
                net.WriteString(callbackName)
            else
                net.WriteString("")
            end
            if SERVER then
                if toPly then
                    net.Send(toPly)
                else
                    net.Broadcast()
                end
            else
                net.SendToServer()
            end

            if isLastChunk then
                SEv.Net.sendTab[chunksID] = nil
            end
        end)
    end
end

net.Receive("sev_net_send_string", function()
    local chunksID = net.ReadString()
    local chunksSubID = net.ReadUInt(32)
    local len = net.ReadUInt(16)
    local chunk = net.ReadData(len)
    local isLastChunk = net.ReadBool()
    local isCompressedString = net.ReadBool()
    local callbackName = net.ReadString() -- Empty until isLastChunk is true.

    -- Initialize streams or reset overwriten ones
    if not SEv.Net.receivedTab[chunksID] or SEv.Net.receivedTab[chunksID].chunksSubID ~= chunksSubID then
        SEv.Net.receivedTab[chunksID] = {
            chunksSubID = chunksSubID,
            data = ""
        }

        -- 3 minutes to remove possible memory leaks
        timer.Create(chunksID, 180, 1, function()
            SEv.Net.receivedTab[chunksID] = nil
        end)
    end

    -- Rebuild the compressed string
    SEv.Net.receivedTab[chunksID].data = SEv.Net.receivedTab[chunksID].data .. chunk

    -- Finish stream
    if isLastChunk then
        local data = SEv.Net.receivedTab[chunksID].data

        if isCompressedString then
            data = util.Decompress(data)
        end

        _G[callbackName](data)
    end
end)

-- Net wrapper -> Register less net strings
    -- To use it just change net.Start to SEv.Net:Start and net.Receive to SEv.Net:Receive
    -- There's no need to declare the net name with util.AddNetworkString
        -- By Zaurzo and Xalalau

function SEv.Net:Start(id)
    net.Start("sev_cheap")
    net.WriteString(id)
end

function SEv.Net:Receive(id, func)
    SEv.Net.cheap[id] = func
end

local function NetWrapper(len, ply)
    local id = net.ReadString()

    if isfunction(SEv.Net.cheap[id]) then
        SEv.Net.cheap[id](len, ply)
    end
end
net.Receive("sev_cheap", NetWrapper)
