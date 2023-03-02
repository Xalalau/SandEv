--[[
    SandEv or SEv - Sandbox Events System
    'Cause Hammer alone is not enough

    Project by Xalalau Xubilozo

    Anomaly Research Center (A.R.C.)
    Revealing and exposing curses
        Collaborators:
            Zaurzo
            TheEndBoss

    MIT License
]]




--[[
    -----------------------
    Base Lua file structure
    -----------------------

    -- Initialization file (check the next sections)
    /lua/autorun/customfilename.lua

    -- The instance loads the Lua files sequentially, in alphabetical order and from higher to lower folder levels

    -- General Lua file prefixes
         =   No prefix means the file will simply be mounted and available on the server
    sh_  =   Add the file to the server and to the clients
    sv_  =   Add the file to only to the server
    cl_  =   Add the file to only to clients

    e.g.  sv_myluafile.lua

    -- Scripts to run right after the previous instance and before the instance libs and events
    /lua/autorun/baseluafolder/init/*

    -- Custom libraries
    /lua/autorun/baseluafolder/libs/*

    -- Custom events sorted by tier level
    /lua/autorun/baseluafolder/events/tier*/*

    -- Events files can have these suffixes
         =   No suffix. The event will be loaded on the instance aimed maps and on all tiers
    _g   =   global. The event will be loaded on any map
    _t   =   tier. The event will be loaded on the instance aimed maps and only when the correct tier is loaded
    _gt  =   global and tier

    e.g.  sv_myevent_g.lua

    -------------------------------------
    Minimal instance initialization table
    -------------------------------------

    INSTANCE = {
        id = string instance small id,                           -- An small name to be part of commands and internal ids
        luaFolder = string my lua folder,                    -- For events and libs
        dataFolder = string my data folder,                  -- For memories and custom data
        maps = { string some_map_name, ... },                -- List of maps where all events must run. Add "*" to whitelist all maps
        toolCategories = { string my tools category, ... },  -- Create devmove tool categories (they'll appear only when devmode is enabled)
        errorData = {                                        -- Enable the ErrorAPI to collect script errors via http
            databaseName = string database name,
            wsid = string addon workshop id,
            url = string server url,
            patterns = { string pattern },                   -- Usually a folder name from /lua
        },
        enableLogging = boolean enable,                      -- Append a copy of logging system as INSTANCE.Log
        enableLobby = boolean enable,                        -- Append a copy of the lobby system as INSTANCE.Lobby
        enableEvents = boolean enable                        -- Append a copy of the events system as INSTANCE.Event, INSTANCE.Event.Memory,
                                                             -- INSTANCE.Event.Memory.Incompatibility and INSTANCE.Event.Memory.Dependency
    }

    ---------------------------
    Hook the instance to SandEv
    ---------------------------

    -- Just copy and adapt the following code:

    local function PostInitCallback(isInitialized)
        -- Run code right after the instance is fully loaded
        -- if isInitialized is false the instance failed to integrate to SandEv
    end

    -- Include the instance
    hook.Add("sandev_init", INSTANCE.luaFolder, function(SEv)
        SEv:AddInstance(INSTANCE, PostInitCallback)
    end)

    --------------------
    Create custom events
    --------------------

    Refer to
    /lua/sandev/tier1/event_creation_ref.lua
    for more information
]]




SEv = SEv or {
    devMode = false, -- The devMode enables access to SandEv's in-game commands and messages. They are used to control, visualize and create events
    id = "sandev", -- Stores instance id
    luaFolder = "sandev", -- Stores events and libs
    dataFolder = "sandev", -- Stores memories and custom data
    instances = {}, -- External instances, using the same structure as SEv table (they'll be loaded into the map)
    toolCategories = { "SandEv Tools" }, -- Devmove tool categories
    errorData = { -- Send addon errors to a server
        databaseName = "sandev",
        wsid = "2908040257",
        url = "https://gerror.xalalau.com",
        patterns = { "sandev" }, -- Folder inside /lua
    },
    Event = { -- Lib to deal with events
        list = {}, -- { [string event name] = function create event, ... }
        loadingOrder = {}, -- { string event name, ... } -- The load order is the file inclusion order
        customEntityList = {}, -- { [string event name] = { [entity ent] = table entity rendering info, ... }, ... }
        gameEntityList = {}, -- { [string event name] = { [entity ent] = bool, ... }, ... }
        Memory = { -- Lib to remember player map progress
            filename = "memories.txt", -- Location to save Memories.List
            path = "", -- Relative memories file path (instance.dataFolder + SEv.Event.filename)
            list = {}, -- { [string memory name] = bool is active, ... } -- Controlled on serverside and copied to clientside
            swaped = {}, -- { [string memory name] = nil or last memory value, ... } -- Hold toggled memories values
            Incompatibility = { -- Sublib to block events based on memories
                list = {} -- { [string memory name] = { ["string memory name"] = true, ... }, ... }
            },
            Dependency = { -- Sublib to deal with memory dependencies
                providers = {}, -- { [string event name] = { ["string memory name"] = true, ... } } -- Events that provide memories
                dependents = {} -- { [string event name] = { ["string memory name"] = true, ... } } -- Events that require memories
                -- The above two tables above when crossed produce a dependency logic and evidence errors.
            }
        },
    },
    Addon = {}, -- General addons support
    Custom = {},
    Effect = {},
    Ent = {},
    Workshop = {
        list = {} -- { [string addn wsid] = table engine.GetAddons() addon info, ... }
    },
    Light = {},
    Lobby = {},
    Log = {
        enabled = false, -- Enable / disable log messages
        debugAll = false -- Turn it on to see all the debug messages
    },
    Map = {
        nodesFolder = "nodes",
        nodesCacheFilename = game.GetMap() .. "_nodes.txt", -- File to save the map node positions
        path = "", -- Relative map nodes file path (instance.dataFolder + SEv.Map.nodesFolder + "map name _ SEv.Map.filename")
        nodesList, -- { [int index] = Vector position, ... } -- Map node positions
        blockCleanup = false,
        CleanupEntFilter = {} -- { [entity ent] = bool, ... }
    },
    Material = {},
    Net = {
        sendTab = {}, -- { [string chunksID] = int chunksSubID }
        receivedTab = {}, -- { [string chunksID] = { chunksSubID = int, compressedString = byte string } }
        cheap = {} -- { [string net id] = function callback }
    },
    NPC = {},
    Ply = {},
    Prop = {},
    Tool = {
        categoriesPanel,
        instances = {},
        categoryControllers = {}
    },
    Util = {},
    Vehicle = {}
}

-- Define nodes file path
SEv.Map.path = SEv.dataFolder .. "/" .. SEv.Map.nodesFolder .. "/" .. SEv.Map.nodesCacheFilename

if SERVER then
    SEv.Event.lastSentChunksID = nil -- str -- Internal. Prevent older chunks from being uploaded if the map is reloaded

    -- Lobby system (lua/sev/lobby/sv_lobby.lua):
    SEv.Lobby.servers = { -- We can have multiple server links
    }
    SEv.Lobby.selectedServerDB = ""
    SEv.Lobby.version = "3"
    SEv.Lobby.isEnabled = false
    SEv.Lobby.selectedServerLink = ""
    SEv.Lobby.lobbyChecksLimit = 20
    SEv.Lobby.lobbyChecks = 0
    SEv.Lobby.isNewEntry = true
    SEv.Lobby.gameID = math.random(1, 999) -- Used to identify multiple GMod instances on the same machine. May "fail" rarely but whatever
    SEv.Lobby.printResponses = false -- Flood the console with information returned from the server
    SEv.Lobby.invaderClass = "" -- A class name to process lobby interactions

    SEv.Ent.blockingEntRemove = {} -- { entity ply, ... } -- Those players are blocking ent_remove from running on protected ents
end

if CLIENT then
    SEv.Event.renderEvent = {} -- { [string event name] = { enabled = bool should render event, [string entID] = { entRenderInfo }, ... } }

    SEv.Lobby.lastPercent = 0

    -- Break lights
    SEv.Addon.spysNightVision = true
    SEv.Addon.NV_ToggleNightVision = nil

    SEv.Ent.isMainMenuOpen = false
    SEv.Ent.alertedEntRemove = false
end

-- Include code

-- Prefixes:
local prefixes = {
    "sh_",
    "sv_",
    "cl_"
}

-- Load source files
local function HandleFile(filePath, prefix)
    if SERVER then
        if prefix ~= "cl_" then
            include(filePath)
        end

        if prefix ~= "sv_" then
            AddCSLuaFile(filePath)
        end
    end

    if CLIENT then
        if prefix ~= "sv_" then
            include(filePath)
        end
    end
end

local function ReadDir(dir, prefix, isCurrentTier, ignoreSuffixes, isBaseMap)
    local files, dirs = file.Find(dir .. "*", "LUA")
    local selectedFiles = {}

    -- Separate files by type
    for _, file in ipairs(files) do
        if string.sub(file, -4) == ".lua" then
            local filePath = dir .. file

            if string.sub(file, 0, 3) == prefix then
                table.insert(selectedFiles, filePath)
            end
        end
    end

    -- Load separated files
    for _, filePath in ipairs(selectedFiles) do
        -- Check suffixes
        if not ignoreSuffixes then
            if isBaseMap then
                if (string.find(filePath, "_t.", 1, true) or string.find(filePath, "_gt.", 1, true)) and not isCurrentTier then continue end 
            else
                if string.find(filePath, "_gt.", 1, true) then
                    if not isCurrentTier then continue end 
                else
                    if not string.find(filePath, "_g.", 1, true) then continue end
                end
            end
        end

        HandleFile(filePath, prefix)
    end

    -- Open the next directory
    for _, subDir in ipairs(dirs) do
        ReadDir(dir .. subDir .. "/", prefix, isCurrentTier, ignoreSuffixes, isBaseMap)
    end
end

function SEv:IncludeFiles(folder, isCurrentTier, ignoreSuffixes, isBaseMap)
    for _, prefix in ipairs(prefixes) do
        ReadDir(folder, prefix, isCurrentTier, ignoreSuffixes, isBaseMap)
    end
end

-- Add instances
function SEv:AddInstance(instance, PostInitCallback)
    table.insert(SEv.instances, instance)
    instance.PostInitCallback = PostInitCallback

    if instance.id then
        print("[SandEv] Registered " .. instance.id .. " instance")
    end
end

-- SandEv extra init
local function PostInitCallback(initialized)
    if not initialized then
        SEv = nil
        return
    end
end

-- Instances init
hook.Add("InitPostEntity", "sev_init", function()
    -- Register instances
    hook.Run("sandev_init", SEv)

    -- Check gamemode (sandbox family only)
    local gamemode = gmod.GetGamemode()

    if not gamemode.IsSandboxDerived then
        PostInitCallback(false)

        for k, instance in ipairs(SEv.instances) do
            if instance.PostInitCallback then
                instance.PostInitCallback(false)
            end
        end

        return
    end

    -- Random number generation
    math.randomseed(os.time())

    -- Create nodes folder
    file.CreateDir(SEv.dataFolder .. "/" .. SEv.Map.nodesFolder)

	-- Particles
	game.AddParticles("particles/train_steam.pcf")
	PrecacheParticleSystem("steam_train")

    -- Init SEv
    do
        -- Create data folders
        file.CreateDir(SEv.dataFolder)

        -- Load init functions
        SEv:IncludeFiles(SEv.luaFolder .. "/init/", nil, true)

        -- Register ErrorAPI entries
        local addonData = ErrorAPI:RegisterAddon(SEv.errorData.databaseName, SEv.errorData.url, SEv.errorData.patterns, SEv.errorData.wsid)

        if addonData then
            hook.Add(SEv.id .. "_devmode", SEv.luaFolder .. "_control_error_api", function(state)
                addonData.enabled = not state
            end)
        end

        -- Set tool categories
        if CLIENT then
            SEv:RegisterToolCategories(SEv)
        end

        -- Include libs
        SEv:IncludeFiles(SEv.luaFolder .. "/libs/", nil, true)

        -- Initialize libs
        SEv.Workshop:InitializeList()

        if SERVER then
            SEv.Map:LoadGroundNodes()
        else
            timer.Simple(0.4, function() -- Just to be sure
                SEv.Addon:StealSpysNightVisionControl()
            end)
        end

        -- Set devmode
        if SEv.devMode then
            SEv:EnableDevMode()
        end

        -- Run last initializations
        PostInitCallback(true)

        -- Print message
        print("[SandEv] Loaded itself")
    end

    -- Init instances
    for k, instance in ipairs(SEv.instances) do
        -- Initialize net variables
        if SERVER then
            SEv:AddInstanceNets(instance)
        end

        -- Copy the Log lib
        if instance.enableLogging then
            local override = instance.Log

            instance.Log = table.Copy(SEv.Log)

            if override then
                table.Merge(instance.Log, override)
            end
        end

        -- Add devMode
        SEv:AddDevModeToInstance(instance)

        -- Create data folders
        file.CreateDir(instance.dataFolder)

        -- Load init functions
        SEv:IncludeFiles(instance.luaFolder .. "/init/", nil, true)

        -- Register ErrorAPI entries
        if instance.errorData then
            local addonData = ErrorAPI:RegisterAddon(instance.errorData.databaseName, instance.errorData.url, instance.errorData.patterns, instance.errorData.wsid)

            if addonData then
                hook.Add(instance.id .. "_devmode", instance.luaFolder .. "_control_error_api", function(state)
                    addonData.enabled = not state
                end)
            end
        end

        -- Set tool categories
        if CLIENT then
            SEv:RegisterToolCategories(instance)
        end

        -- Include libs
        SEv:IncludeFiles(instance.luaFolder .. "/libs/", nil, true)

        -- Initialize custom lobby systems
        if instance.enableLobby then
            local override = instance.Lobby

            instance.Lobby = table.Copy(SEv.Lobby)

            instance.Lobby.instance = instance

            if override then
                table.Merge(instance.Lobby, override)
            end
        end

        -- Initialize custom event systems
        if instance.enableEvents then
            local override = instance.Event

            instance.Event = table.Copy(SEv.Event)

            instance.Event.instance = instance
            instance.Event.Memory.instance = instance
            instance.Event.Memory.Incompatibility.instance = instance
            instance.Event.Memory.Dependency.instance = instance

            -- Define memories file path
            instance.Event.Memory.path = instance.dataFolder .. "/" .. SEv.Event.Memory.filename

            instance.Event:InitSh(instance)
            if SERVER then
                instance.Event:InitSv(instance)
            else
                instance.Event:InitCl(instance)
            end

            instance.Event.Memory:InitSh(instance)
            if SERVER then
                instance.Event.Memory:InitSv(instance)
            else
                instance.Event.Memory:InitCl(instance)
            end

            if SERVER then
                instance.Event.Memory:Load()
                instance.Event:InitializeTier()
            end

            if override then
                table.Merge(instance.Event, override)
            end

            -- Send the server memories at the appropriate time
            if CLIENT then
                net.Start(instance.id .. "_ask_for_memories")
                net.SendToServer()

                hook.Add(instance.id .. "_memories_received", instance.id .. "_initialize_cl_events", function()
                    instance.Event:InitializeTier()
                end)
            end
        end

        -- Set devmode
        if instance.devMode then
            instance:EnableDevMode()
        end

        -- Run last initializations
        if instance.PostInitCallback then
            instance.PostInitCallback(true)
        end

        -- Run post instance init hook
        hook.Run(instance.id .. "_post_init", instance)

        -- Print message
        if instance.id then
            print("[SandEv] Loaded " .. instance.id .. " instance")
        end
    end

    -- Lock down some libs after we're done copying them to instances
    SEv.Util:BlockDirectLibCalls(SEv.Log)
    SEv.Util:BlockDirectLibCalls(SEv.Lobby)
    SEv.Util:BlockDirectLibCalls(SEv.Event)
    SEv.Util:BlockDirectLibCalls(SEv.Event.Memory)
    SEv.Util:BlockDirectLibCalls(SEv.Event.Memory.Incompatibility)
    SEv.Util:BlockDirectLibCalls(SEv.Event.Memory.Dependency)
end)
