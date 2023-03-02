-- Persistent event memories
-- Events can have unlimited memories


-- Load memories from file
function SEv.Event.Memory:Load()
    local memoriesFile = file.Read(self.path, "Data")

    self.list = util.JSONToTable(memoriesFile or "{}")
end

-- Save the current memories
function SEv.Event.Memory:Save()
    file.Write(self.path, util.TableToJSON(self.list, true))
end

-- Writes active server memories on clients
function SEv.Event.Memory:SendAllMemories(ply)
    local memoriesTab = table.Copy(self.list or {})

    for memoryName, value in pairs(memoriesTab) do
        if self:IsPerPlayer(memoryName) then
            local pureMemoryName = self:RevertPerPlayer(memoryName)
            memoriesTab[memoryName] = nil
            memoriesTab[pureMemoryName] = value
        end
    end

    net.Start(self.instance.id .. "_broadcast_memories")
    net.WriteTable(memoriesTab)
    net.Send(ply)
end

-- Toggle existing per player memory
function SEv.Event.Memory:TogglePerPlayer(ply, cmd, args, doNotRefreshEvents)
    local somePlyNick = args[1]
    local memoryNameIn = args[2]

    for k, somePly in ipairs(player.GetHumans()) do
        if somePlyNick == somePly:Nick() then
            local perPlayerMemoryIn = self:ConvertPerPlayer(somePly, memoryNameIn)
            self:Toggle(ply, cmd, { perPlayerMemoryIn }, doNotRefreshEvents, true)
            return
        end
    end

    print("Player not found.")
end

-- Toggle existing memories
function SEv.Event.Memory:Toggle(ply, cmd, args, doNotRefreshEvents, isPerPlayer)
    local memoryNameIn = args[1]

    if not memoryNameIn then return end

    local function swapValue(memoryNameIn, doNotRefreshEvents)
        local value = self.list[memoryNameIn]
        local swapedValue

        if value == nil then
            swapedValue = self.swaped[memoryNameIn]
        else
            swapedValue = nil
        end
        self.swaped[memoryNameIn] = value

        if isPerPlayer then
            local memoryNamePure = self:RevertPerPlayer(memoryNameIn)
            self:SetPerPlayer(ply, memoryNamePure, swapedValue, doNotRefreshEvents)
        else
            self:Set(memoryNameIn, swapedValue, doNotRefreshEvents)
        end
    end

    if memoryNameIn == "enabled" then
        for memoryName, memoryValue in pairs(self.list) do
            swapValue(memoryName, true)
        end
        self.instance.Event:ReloadByMemory()

        print("Done")
    elseif memoryNameIn == "disabled" then
        for memoryName, memoryValue in pairs(self.swaped) do
            swapValue(memoryName, true)
        end
        self.instance.Event:ReloadByMemory()

        print("Done")
    elseif self.list[memoryNameIn] ~= nil or self.swaped[memoryNameIn] ~= nil then
        swapValue(memoryNameIn, doNotRefreshEvents)
        print("  " .. memoryNameIn .. " = " .. tostring(self.list[memoryNameIn]))
    else
        print("Memory not found.")
    end
end

-- Instance init
function SEv.Event.Memory:InitSv(instance)
    net.Receive(instance.id .. "_ask_for_memories", function(_, ply)
        instance.Event.Memory:SendAllMemories(ply)
    end)

    instance.Event.Memory.InitSv = nil
end