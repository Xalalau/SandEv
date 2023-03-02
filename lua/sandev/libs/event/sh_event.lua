-- Events base

-- In singleplayer the client starts fast enough to get only part of the entities, so
-- I manually block sending them and let him request the full list when he's done.
local blockSendFirstEntities = true
timer.Simple(2, function()
    blockSendFirstEntities = false
end)

-- Return the rendering info table from an entity
function SEv.Event:GetEntityRenderInfo(ent)
    return {
        class = ent:GetClass() or "",
        eventName = ent:GetVar("eventName"),
        entName = ent:GetVar("entName"),
        entID = tostring(ent),
        vecA = ent:GetVar("vecA"),
        vecB = ent:GetVar("vecB"),
        vecCenter = ent:GetVar("vecCenter"),
        color = ent:GetVar("color"),
        vecConnection = ent:GetVar("vecConnection")
    }
end

-- Get events list
function SEv.Event:GetList()
    return self.list
end

-- Check for an event entity
function SEv.Event:IsGameEntity(ent)
    for eventName, entList in pairs(self.gameEntityList) do
        if entList[ent] then
            return eventName
        end
    end
end

-- Set any event entity
function SEv.Event:SetGameEntity(eventName, ent)
    self.gameEntityList[eventName] = self.gameEntityList[eventName] or {}
    self.gameEntityList[eventName][ent] = true
end

-- Remove any event entity
function SEv.Event:RemoveGameEntity(eventName, ent)
    if self.gameEntityList[eventName] then
        self.gameEntityList[eventName][ent] = nil
    end
end

-- Set a custom event entity which can have the area rendered on the clientside
function SEv.Event:SetRenderInfoEntity(ent)
    -- Register entity rendering information
    timer.Simple(0.1, function() -- Wait to get valid entity keys/values
        if not ent:IsValid() then return end

        local entRenderInfo = self:GetEntityRenderInfo(ent)
        local eventName = entRenderInfo.eventName

        if not eventName then return end
        -- This check isn't true normally, only when someone wants to force spawn an object, as some of the external instances have done.
        -- However I believe that saves and duplications can also cause problems with unloaded events.

        self.customEntityList[eventName] = self.customEntityList[eventName] or {}
        self.customEntityList[eventName][ent] = entRenderInfo

        -- Send entRenderInfo to render
        if not self.instance.devMode then return end

        if SERVER then
            if blockSendFirstEntities then return end

            net.Start(self.instance.id .. "_event_set_render_cl")
                net.WriteTable(entRenderInfo)
            net.Broadcast()
        else
            self:Render(entRenderInfo)
        end

        ent:CallOnRemove(self.instance.id .. "_remove_render_info", function()
            if self:GetEntityRenderInfo(ent) then
                self:RemoveRenderInfoEntity(ent)
            end
        end)
    end)
end

-- Remove a custom event entity
function SEv.Event:RemoveRenderInfoEntity(ent)
    if not IsValid(ent) or not self.instance then return end

    local entRenderInfo = self:GetEntityRenderInfo(ent)

    if not entRenderInfo then return end

    timer.Simple(0.2, function() -- Wait to be sure that self.customEntityList is initialized
        local eventName = entRenderInfo.eventName

        if not eventName then return end

        if self.customEntityList[eventName] then
            self.customEntityList[eventName][ent] = nil
        end

        if not self.instance.devMode or not SERVER then return end

        local entID = entRenderInfo.entID

        net.Start(self.instance.id .. "_event_remove_render_cl")
            net.WriteString(eventName)
            net.WriteString(entID)
        net.Broadcast()
    end)
end

-- Check if a event is enabled
function SEv.Event:IsEnabled(eventName)
    return self.list[eventName] and self.list[eventName].enabled or false
end

-- Remove all entities from the table and the map
function SEv.Event:RemoveAll()
    local function dissolveEnts(list)
        for eventName, entList in pairs(list) do
            for ent, _ in pairs(entList) do
                if ent:IsValid() then
                    if not SEv.Ent:Dissolve(ent) then
                        ent:Remove()
                    end
                end
            end
        end
    end

    dissolveEnts(self.customEntityList)
    dissolveEnts(self.gameEntityList)

    for k, eventName in ipairs(self.loadingOrder) do
        if self.list[eventName].enabled and self.list[eventName].disableFunc then
            self.list[eventName].disableFunc()
        end
    end

    self.customEntityList = {}
    self.gameEntityList = {}
    self.loadingOrder = {}
    self.list = {}

    if SERVER then
        net.Start(self.instance.id .. "_event_remove_all_cl")
        net.Broadcast()
    end
end

-- Remove event entities from the table and the map
function SEv.Event:Remove(eventNameOut)
    local function removeEventEntities(eventName, list)
        if not list[eventName] then return end

        for ent, _ in pairs(list[eventName]) do
            if ent:IsValid() then
                if not SEv.Ent:Dissolve(ent) then
                    ent:Remove()
                end
            end
        end

        list[eventName] = nil
    end

    local hasEntities = false

    if self.customEntityList[eventNameOut] then
        removeEventEntities(eventNameOut, self.customEntityList)
        hasEntities = true
    end

    if self.gameEntityList[eventNameOut] then
        removeEventEntities(eventNameOut, self.gameEntityList)
        hasEntities = true
    end

    if self.list[eventNameOut] then
        if self.list[eventNameOut].disableFunc then
            self.list[eventNameOut].disableFunc()
        end

        self.list[eventNameOut].enabled = false
    end

    hook.Run(self.instance.id .. "_remove_" .. eventNameOut)

    if SERVER and hasEntities then
        net.Start(self.instance.id .. "_event_remove_cl")
            net.WriteString(eventNameOut)
        net.Broadcast()
    end
end

-- Run an event
function SEv.Event:Run(eventName)
    local failFunc = self.list[eventName].failFunc

    -- Check if the required memories are loaded
    if not self.Memory.Dependency:Check(eventName) then
        return failFunc and failFunc()
    end

    -- Check if there are incompatible memories loaded
    if self.Memory.Incompatibility:Check(eventName) then
        return failFunc and failFunc()
    end

    -- Initialize
    if self.list[eventName] then
        if self.list[eventName].func() then
            self.list[eventName].enabled = true
        end

        -- Call hook
        timer.Simple(0.4, function() -- Load everything before calling hooks!
            hook.Run(self.instance.id .. "_run_" .. eventName)
        end)
    end
end

-- Set event initialization
function SEv.Event:SetCall(eventNameIn, initFunc)
    local isEnabled

    if self.list[eventNameIn] then
        local index = table.KeyFromValue(self.loadingOrder, eventNameIn)
        isEnabled = self.list[eventNameIn].enabled

        self.loadingOrder[index] = eventNameIn
    else
        isEnabled = false

        table.insert(self.loadingOrder, eventNameIn)
    end

    hook.Run(self.instance.id .. "_add_" .. eventNameIn)
    self.list[eventNameIn] = { func = initFunc, enabled = isEnabled }
end

-- Set event initialization fail callback
function SEv.Event:SetFailCall(eventNameIn, callback)
    if self.list[eventNameIn] then
        self.list[eventNameIn].failFunc = callback
    end
end

-- Set event disabling callback
function SEv.Event:SetDisableCall(eventNameIn, callback)
    if self.list[eventNameIn] then
        self.list[eventNameIn].disableFunc = callback
    end
end

-- Get the max tier players can enable
function SEv.Event:GetMaxPossibleTier()
    local maxTier = 1

    if self.Memory:Get("MeatyFight") then
        maxTier = maxTier + 1
        if self.Memory:Get("INeedFight") then
            maxTier = maxTier + 1
        end
    end

    return maxTier
end

-- Load event tiers
function SEv.Event:InitializeTier()
    local maxTier = self:GetMaxPossibleTier()
    local tier = GetConVar(self.instance.id .. "_tier"):GetInt()

    -- Force players to roll back to the higher valid tier
    if SERVER and not self.instance.devMode and tier > maxTier then
        GetConVar(self.instance.id .. "_tier"):SetInt(maxTier)
        return
    end

    -- Clear any loaded events
    self:RemoveAll()

    -- Include all events
    local curMap = game.GetMap()
    for i=1, tier do
        local tierFolder = self.instance.luaFolder .. "/events/tier" .. i .. "/"
        local isBaseMap = false

        if self.instance.maps == "*" then
            isBaseMap = true
        elseif istable(self.instance.maps) then
            if table.HasValue(self.instance.maps, curMap) then
                isBaseMap = true
            end
        end

        SEv:IncludeFiles(tierFolder, i == tier, false, isBaseMap)
    end

    -- Load events
    for k, eventName in ipairs(self.loadingOrder) do
        self:Run(eventName)
    end

    if SERVER then
        net.Start(self.instance.id .. "_event_initialize_tier_cl")
        net.Broadcast()
    end
end

-- Reload the already loaded events
function SEv.Event:ReloadCurrent()
    if SERVER and self.instance.devMode then
        for eventName, ent in pairs(self.customEntityList) do
            self.customEntityList[eventName] = {}
        end

        for eventName, ent in pairs(self.gameEntityList) do
            self.gameEntityList[eventName] = {}
        end
    end

    for k, eventName in ipairs(self.loadingOrder) do
        if self:IsEnabled(eventName) then
            self:Run(eventName)
        end
    end

    if SERVER and self.instance.devMode then
        net.Start(self.instance.id .. "_event_remove_all_ents_cl")
        net.Broadcast()

        timer.Simple(1, function()
            self:SendCustomEnts(ply)
        end)
    end
end

-- Reload events according to the logic of memory dependencies and incompatibilities
-- Note: this system is automatic and for it to work it's necessary to make all events assume the
-- correct state, so everything that was manually toggled will be automatically restaured here.
function SEv.Event:ReloadByMemory()
    local crossedEvents = self.Memory.Dependency:GetDependentEventsState()
    local memories = self.Memory:GetList()
    local block = {}

    -- Remove or block events that now are incompatible due to new memories
    for k, eventName in ipairs(self.loadingOrder) do
        local incompatTab = self.Memory.Incompatibility:Get(eventName)

        for memoryName, _ in pairs(incompatTab or {}) do
            if memories[memoryName] then
                if self:IsEnabled(eventName) then
                    self:Remove(eventName)
                    block[eventName] = true
                end

                break
            end
        end
    end

    -- Disable events that don't meet their dependencies anymore
    for _, eventName in ipairs(crossedEvents.disabled) do
        if self:IsEnabled(eventName) then
            self:Remove(eventName)
        end
    end

    -- Activate compatible events that now meet their dependencies but are disabled
    for _, eventName in ipairs(crossedEvents.enabled) do
        if not block[eventName] and not self:IsEnabled(eventName) then
            self:Run(eventName)
        end
    end

    -- Activate events that have no reason to be disabled
    for k, eventName in ipairs(self.loadingOrder) do
        if not self:IsEnabled(eventName) and not block[eventName] then
            self:Run(eventName)
        end
    end
end

-- Toggle events
-- Warning! Events are subject to memories, so it's not possible to activate
-- them without the minimum conditions for this.
function SEv.Event:Toggle(ply, cmd, args)
    local eventNameIn = args[1]

    if not eventNameIn then return end
    if not self.list[eventNameIn] and not (eventNameIn == "enabled" or eventNameIn == "disabled") then return end

    local function toggle(state, eventName)
        local memories = self.Memory.Dependency:GetProviders()[eventName] or {}

        for memoryName, _ in pairs(memories) do
            self.Memory:Toggle(ply, cmd, { memoryName }, true)
        end

        if state then
            self:Remove(eventName)
        else
            self:Run(eventName)
        end
    end

    if eventNameIn == "enabled" or eventNameIn == "disabled" then
        local state = eventNameIn == "enabled"

        for k, eventName in ipairs(self.loadingOrder) do
            if self:IsEnabled(eventName) == state then
                print(eventName .. " = " .. tostring(not self:IsEnabled(eventName)))
                toggle(state, eventName)
            end
        end

        return
    end

    if self.list[eventNameIn] then
        print(eventNameIn .. " = " .. tostring(not self:IsEnabled(eventNameIn)))
        toggle(self:IsEnabled(eventNameIn), eventNameIn)
    end
end

-- List events
function SEv.Event:List()
    local enabled, disabled = {}, {}

    for k, eventName in ipairs(self.loadingOrder) do
        if self:IsEnabled(eventName) then
            table.insert(enabled, eventName)
        else
            table.insert(disabled, eventName)
        end
    end

    print([[Options:
  enabled
  disabled]])

    if #enabled > 0 then
        print("\nEnabled:")
        for k, eventName in SortedPairsByValue(enabled) do
            print("  " .. eventName)
        end
    end

    if #disabled > 0 then
        print("\nDisabled:")
        for k, eventName in SortedPairsByValue(disabled) do
            print("  " .. eventName)
        end
    end
end

-- Instance init
function SEv.Event:InitSh(instance)
    CreateConVar(instance.id .. "_tier", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED })

    -- After a cleanup
    hook.Add("PostCleanupMap", instance.id .. "_reload_map_sh", function()
        instance.Event:ReloadCurrent()
    end)

    instance.Event.InitSh = nil
end