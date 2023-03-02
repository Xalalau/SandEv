-- Persistent event memories
-- Events can have unlimited memories

-- Send active server memories to clients
function SEv.Event.Memory:ReceiveAllMemories(serverMemories)
    for memoryName, value in pairs(serverMemories) do
        self.list[memoryName] = value
    end
end 

-- Instance init
function SEv.Event.Memory:InitCl(instance)
    net.Receive(instance.id .. "_broadcast_memory", function()
        local memoryName = net.ReadString()
        local doNotRefreshEvents = net.ReadBool()
        local value = util.JSONToTable(net.ReadString())
    
        value = value and unpack(value)
    
        instance.Event.Memory:Set(memoryName, value, doNotRefreshEvents, true)
    end)
    
    net.Receive(instance.id .. "_broadcast_memories", function()
        instance.Event.Memory:ReceiveAllMemories(net.ReadTable())
        hook.Run(instance.id .. "_memories_received")
    end)
    

    instance.Event.Memory.InitCl = nil
end