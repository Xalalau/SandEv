-- Persistent event memories
-- Events can have unlimited memories

-- ATTENTION! Memories are always saved on the SERVER!!
-- "Client memories" are just a way to save individualized data on the server
-- and to run unique events on the clients, they are no exception to the rule.

-- FULLY reset memories
function SEv.Event.Memory:Reset()
    file.Delete(self.path)

    self.list = {}
    self.swaped = {}
    self.Incompatibility.list = {}
    self.Dependency.providers = {}
    self.Dependency.dependents = {}

    if SERVER then
        net.Start(self.instance.id .. "_clear_memories")
        net.Broadcast()
    end
end

-- Set a memory
function SEv.Event.Memory:Set(memoryName, value, doNotRefreshEvents, isFromServer)
    if CLIENT and not isFromServer then
        Error("ERROR! Clientside memories are intended to be a copy of the server memories. Do not define clientside exclusive memories!")
        return
    end

    self.list[memoryName] = value

    if SERVER then
        self:Save()

        net.Start(self.instance.id .. "_broadcast_memory")
        net.WriteString(memoryName)
        net.WriteBool(doNotRefreshEvents)
        net.WriteString(util.TableToJSON({ value }))
        net.Broadcast()
    end

    if not doNotRefreshEvents then
        self.instance.Event:ReloadByMemory()
    end
end

-- Get a memory
function SEv.Event.Memory:Get(memoryName)
    return memoryName and self.list and self.list[memoryName]
end

-- Get the memories list
function SEv.Event.Memory:GetList()
    return self.list
end

-- List memories information
function SEv.Event.Memory:List()
    local enabled, disabled = {}, {}

    for memoryName, memoryState in pairs(self.list) do
        if memoryState then
            table.insert(enabled, memoryName)
        else
            table.insert(disabled, memoryName)
        end
    end

    for memoryName, _ in pairs(self.swaped) do
        table.insert(disabled, memoryName)
    end

    print([[Options:
  enabled
  disabled]])

    if #enabled > 0 then
        print("\nEnabled:")
        for k, memoryName in SortedPairsByValue(enabled) do
            print("  " .. memoryName)
        end
    end

    if #disabled > 0 then
        print("\nDisabled:")
        for k, memoryName in SortedPairsByValue(disabled) do
            print("  " .. memoryName)
        end
    end
end

-- Convert a memory name to a per player memory name
function SEv.Event.Memory:ConvertPerPlayer(ply, memoryName)
    return ply:SteamID64() .. "_" .. memoryName
end

-- Revert a per player memory name to a memory name
function SEv.Event.Memory:RevertPerPlayer(perPlayerMemoryName)
    return string.sub(perPlayerMemoryName, 19, -1)
end

-- Check if a memory is per player
function SEv.Event.Memory:IsPerPlayer(memoryName)
    return tonumber(string.sub(memoryName, 1, 17)) and true or false
end

-- Get a per player memory value
function SEv.Event.Memory:GetPerPlayer(ply, memoryName)
    local perPlayerMemoryName = self:ConvertPerPlayer(ply, memoryName)
    return memoryName and self.list and self.list[perPlayerMemoryName]
end

-- Set a per player memory
--   It can be used to store data both on the server and client and is capable of triggering events on the client.
function SEv.Event.Memory:SetPerPlayer(ply, memoryName, value, doNotRefreshEvents)
    if CLIENT then
        net.Start(self.instance.id .. "_set_per_player_memory_sv")
        net.WriteString(memoryName)
        net.WriteString(util.TableToJSON({ value }))
        net.WriteBool(doNotRefreshEvents)
        net.SendToServer()

        return
    end

    local perPlayerMemoryName = self:ConvertPerPlayer(ply, memoryName)

    self.list[perPlayerMemoryName] = value

    net.Start(self.instance.id .. "_set_per_player_memory_cl")
    net.WriteString(memoryName)
    net.WriteString(util.TableToJSON({ value }))
    net.WriteBool(doNotRefreshEvents)
    net.Send(ply)

    self:Save()

    if not doNotRefreshEvents then
        self.instance.Event:ReloadByMemory()
    end
end

-- Instance init
function SEv.Event.Memory:InitSh(instance)
    if CLIENT then
        net.Receive(instance.id .. "_clear_memories", function()
            instance.Event.Memory:Reset()
        end)

        net.Receive(instance.id .. "_set_per_player_memory_cl", function()
            local memoryName = net.ReadString()
            local value = unpack(util.JSONToTable(net.ReadString()))
            local doNotRefreshEvents = net.ReadBool()

            instance.Event.Memory.list[memoryName] = value

            if not doNotRefreshEvents then
                instance.Event:ReloadByMemory()
            end
        end)
    end

    if SERVER then
        net.Receive(instance.id .. "_set_per_player_memory_sv", function(_, ply)
            local memoryName = net.ReadString()
            local value = unpack(util.JSONToTable(net.ReadString()) or {})
            local doNotRefreshEvents = net.ReadBool()

            instance.Event.Memory:SetPerPlayer(ply, memoryName, value, doNotRefreshEvents)
        end)
    end

    instance.Event.Memory.InitSh = nil
end
