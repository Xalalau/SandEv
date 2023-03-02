-- Events base

local wireframe = Material("models/wireframe")

surface.CreateFont("SEvEntName", {
    font = "TargetID",
    size = 20,
    weight = 1000,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    shadow = true,
})

surface.CreateFont("SEvEventName", {
    font = "TargetID",
    size = 24,
    weight = 1000,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    shadow = true,
})

-- Event rendering
function SEv.Event:Render(entRenderInfo)
    if not self.instance.devMode then return end

    -- Render event name
    if self.renderEvent[entRenderInfo.eventName] == nil then
        self.renderEvent[entRenderInfo.eventName] = { enabled = false }

        hook.Add("HUDPaint", entRenderInfo.eventName, function()
            if self.renderEvent[entRenderInfo.eventName] == nil then
                hook.Remove("HUDPaint", entRenderInfo.eventName)
                return
            end

            if not GetConVar(self.instance.id .. "_events_show_names"):GetBool() then return end

            local drawposscreen = entRenderInfo.vecCenter:ToScreen()

            draw.DrawText(entRenderInfo.eventName, "SEvEntName", drawposscreen.x, drawposscreen.y - 25, color_white, TEXT_ALIGN_CENTER)
        end)
    end

    -- Current event entity
    self.renderEvent[entRenderInfo.eventName][entRenderInfo.entID] = entRenderInfo

    -- Render event entity locator
    hook.Add("PostDrawTranslucentRenderables", entRenderInfo.entName, function()
        if self.renderEvent[entRenderInfo.eventName] == nil or not self.renderEvent[entRenderInfo.eventName][entRenderInfo.entID] then
            hook.Remove("PostDrawTranslucentRenderables", entRenderInfo.entName)
            return
        end

        if not self.renderEvent[entRenderInfo.eventName].enabled then return end

        render.SetMaterial(wireframe)

        if entRenderInfo.vecA and entRenderInfo.vecB and entRenderInfo.color then
            render.DrawWireframeBox(Vector(0, 0, 0), Angle(0, 0, 0), entRenderInfo.vecA, entRenderInfo.vecB, entRenderInfo.color, true)
        end

        if entRenderInfo.vecCenter and entRenderInfo.vecConnection then
            render.DrawBeam(entRenderInfo.vecCenter, entRenderInfo.vecConnection, 1, 1, 1, { entRenderInfo.color })
        end
    end)

    -- Render event entity name
    hook.Add("HUDPaint", entRenderInfo.entName, function()
        if self.renderEvent[entRenderInfo.eventName] == nil or not self.renderEvent[entRenderInfo.eventName][entRenderInfo.entID] then
            hook.Remove("HUDPaint", entRenderInfo.entName)
            return
        end

        if not self.renderEvent[entRenderInfo.eventName].enabled then return end

        local distance = LocalPlayer():GetPos():Distance(entRenderInfo.vecCenter)

        if distance > 1000 then return end

        local up = Vector(0, 0, 1 * distance/1000)
        local drawposscreen = (entRenderInfo.vecCenter + up):ToScreen()

        draw.DrawText(entRenderInfo.entName, "SEvEventName", drawposscreen.x, drawposscreen.y, entRenderInfo.color, TEXT_ALIGN_CENTER)
    end)

    if GetConVar(self.instance.id .. "_events_render_auto"):GetBool() then
        self.renderEvent[entRenderInfo.eventName].enabled = true
    end
end

-- Toggle rendering from console
function SEv.Event:ToggleRender(ply, cmd, args)
    local eventNameIn = args[1]

    if not eventNameIn then return end

    if eventNameIn == "all" then
        for eventName, eventTab in pairs(self.renderEvent) do
            if not eventTab.enabled then
                eventTab.enabled = true
            end
        end

        print("Done")
        return
    elseif eventNameIn == "none" then
        for eventName, eventTab in pairs(self.renderEvent) do
            if eventTab.enabled then
                eventTab.enabled = false
            end
        end

        print("Done")
        return
    elseif eventNameIn == "invert" then
        for eventName, eventTab in pairs(self.renderEvent) do
            eventTab.enabled = not eventTab.enabled
        end

        print("Done")
        return
    end

    if self.renderEvent[eventNameIn] ~= nil then
        self.renderEvent[eventNameIn].enabled = not self.renderEvent[eventNameIn].enabled
        print(eventNameIn .. " = " .. tostring(self.renderEvent[eventNameIn].enabled))
    end
end

-- List information about event rendering
function SEv.Event:ListRender()
    print("Events:")

    for eventName, eventInfo in SortedPairs(self.renderEvent) do
        print("  " .. eventName, (eventInfo.enabled and "(Rendered)" or ""))
    end
end

-- Instance init
function SEv.Event:InitCl(instance)
    -- Load event tiers by server order
    net.Receive(instance.id .. "_event_initialize_tier_cl", function()
        instance.Event:InitializeTier()
    end)

    -- Remove events by server order
    net.Receive(instance.id .. "_event_remove_all_cl", function()
        instance.Event:RemoveAll()

        if self.instance.devMode then
            instance.Event.renderEvent = {}
        end
    end)

    net.Receive(instance.id .. "_event_remove_all_ents_cl", function()
        if self.instance.devMode then
            instance.Event.renderEvent = {}
        end
    end)

    -- Remove an event by server order
    net.Receive(instance.id .. "_event_remove_cl", function()
        local eventName = net.ReadString()

        instance.Event:Remove(eventName)

        if self.instance.devMode then
            instance.Event.renderEvent[eventName] = nil
        end
    end)

    -- Receive entity rendering info
    net.Receive(instance.id .. "_event_set_render_cl", function()
        instance.Event:Render(net.ReadTable())
    end)

    -- Remove an event entity by server order
    net.Receive(instance.id .. "_event_Remove_render_cl", function()
        local eventName = net.ReadString()
        local entID = net.ReadString()

        if self.instance.devMode and instance.Event.renderEvent[eventName] then
            instance.Event.renderEvent[eventName][entID] = nil
        end
    end)

    -- Receive all events
    local receivedTab = {}
    net.Receive(instance.id .. "_event_send_all_render_cl", function()
        local currentChunksID = net.ReadString()
        local len = net.ReadUInt(16)
        local chunk = net.ReadData(len)
        local lastPart = net.ReadBool()

        if not receivedTab[currentChunksID] then
            receivedTab = {}
            receivedTab[currentChunksID] = ""
        end

        receivedTab[currentChunksID] = receivedTab[currentChunksID] .. chunk

        if lastPart then
            local eventEntTab = util.JSONToTable(util.Decompress(receivedTab[currentChunksID]))

            receivedTab = {}

            if eventEntTab and istable(eventEntTab) then
                for k,eventEntInfo in ipairs(eventEntTab) do
                    instance.Event:Render(eventEntInfo)
                end
            end
        end
    end)

    instance.Event.InitCl = nil
end