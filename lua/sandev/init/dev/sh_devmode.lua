-- Instances devmode

function SEv:AddDevModeToInstance(instance)
    function instance:EnableDevMode()
        instance.devMode = true

        local function ConvertCVarDataToMemory(any)
            if any == nil then
            elseif isnumber(any) then
                any = tonumber(any)
            elseif any == ("true" or "false") then
                any = tobool(any)
            elseif string.find(any, "^[%s]-[{]") then
                any = CompileString([[return ]] .. any, "sev_tblstr")()
            end
        
            return any
        end

        concommand.Add(instance.id .. "_events_toggle", function(ply, cmd, args) instance.Event:Toggle(ply, cmd, args) end)
        concommand.Add(instance.id .. "_events_list", function() instance.Event:List() end)
        concommand.Add(instance.id .. "_memories_toggle", function(ply, cmd, args) instance.Event.Memory:Toggle(ply, cmd, args) end)
        concommand.Add(instance.id .. "_memories_toggle_per_player", function(ply, cmd, args) instance.Event.Memory:TogglePerPlayer(ply, cmd, args) end)
        concommand.Add(instance.id .. "_memories_list", function() instance.Event.Memory:List() end)
        concommand.Add(instance.id .. "_memories_print_logic", function() instance.Event.Memory.Dependency:PrintLogic() end)
        concommand.Add(instance.id .. "_memories_set", function(ply, cmd, args) instance.Event.Memory:Set(args[1], ConvertCVarDataToMemory(args[2])) print("Done") end)

        if CLIENT then
            net.Start(instance.id .. "_event_request_all_render_sv")
            net.SendToServer()

            CreateClientConVar(instance.id .. "_events_show_names", "0", true, false)
            CreateClientConVar(instance.id .. "_events_render_auto", "0", true, false)
            SEvPortals.VarDrawDistance = CreateClientConVar(instance.id .. "_portal_drawdistance", "3500", true, false, "Sets the size of the portal along the Y axis", 0)

            concommand.Add(instance.id .. "_events_render", function(ply, cmd, args) instance.Event:ToggleRender(ply, cmd, args) end)
            concommand.Add(instance.id .. "_events_render_list", function() instance.Event:ListRender() end)
        end

        hook.Run(instance.id .. "_devmode", true)
        
        if SERVER then
            RunConsoleCommand("state_devmode_" .. instance.id, "1")
        end
    end

    function instance:DisableDevMode()
        instance.devMode = false

        concommand.Remove(instance.id .. "_events_toggle")
        concommand.Remove(instance.id .. "_events_list")
        concommand.Remove(instance.id .. "_memories_toggle")
        concommand.Remove(instance.id .. "_memories_list")
        concommand.Remove(instance.id .. "_memories_print_logic")
        concommand.Remove(instance.id .. "_memories_set")

        if CLIENT then
            concommand.Remove(instance.id .. "_events_render")
            concommand.Remove(instance.id .. "_events_render_list")

            -- Apparently we can't remove cvars.
        end

        hook.Run(instance.id .. "_devmode", false)

        if SERVER then
            RunConsoleCommand("state_devmode_" .. instance.id , "0")
        end
    end

    local devModeState = CreateConVar("state_devmode_" .. instance.id , "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED }) -- Just to store the state between games

    if SERVER then
        function instance:ToggleDevMode()
            local toggleFuncName = instance.devMode and "DisableDevMode" or "EnableDevMode"

            instance[toggleFuncName]()

            net.Start(instance.id .. "_toggle_devmode")
            net.WriteString(toggleFuncName)
            net.Broadcast()

            print("[SandEv] " .. instance.id .. " devmode is " .. (instance.devMode and "On" or "Off"))
        end

        concommand.Add("devmode_" .. instance.id .. "_toggle", function() instance:ToggleDevMode() end)    

        if devModeState:GetBool() then
            instance:ToggleDevMode()
        end
    else
        hook.Add(instance.id .. "_memories_received", instance.id .. "_auto_dev_mode_cl", function()
            if GetConVar("state_devmode_" .. instance.id):GetBool() then
                instance:EnableDevMode()
            end
        end)

        net.Receive(instance.id .. "_toggle_devmode", function()
            local toggleFuncName = net.ReadString()
            instance[toggleFuncName]()
        end)
    end
end

-- SandEv devmode

function SEv:EnableDevMode()
    SEv.devMode = true

    hook.Run(SEv.id .. "_devmode", true)
    
    if SERVER then
        RunConsoleCommand("state_devmode_" .. SEv.id, "1")
    end
end

function SEv:DisableDevMode()
    SEv.devMode = false

    hook.Run(SEv.id .. "_devmode", false)

    if SERVER then
        RunConsoleCommand("state_devmode_" .. SEv.id , "0")
    end
end

local SEvDevModeState = CreateConVar("state_devmode_" .. SEv.id , "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED }) -- Just to store the state between games

if SERVER then
    function SEv:ToggleDevMode()
        local toggleFuncName = SEv.devMode and "DisableDevMode" or "EnableDevMode"

        SEv[toggleFuncName]()

        net.Start(SEv.id .. "_toggle_devmode")
        net.WriteString(toggleFuncName)
        net.Broadcast()

        print("[SandEv] " .. SEv.id .. " devmode is " .. (SEv.devMode and "On" or "Off"))
    end

    concommand.Add("devmode_" .. SEv.id .. "_toggle", function() SEv:ToggleDevMode() end)    

    if SEvDevModeState:GetBool() then
        SEv:ToggleDevMode()
    end
else
    hook.Add(SEv.id .. "_memories_received", SEv.id .. "_auto_dev_mode_cl", function()
        if GetConVar("state_devmode_" .. SEv.id):GetBool() then
            SEv:EnableDevMode()
        end
    end)

    net.Receive(SEv.id .. "_toggle_devmode", function()
        local toggleFuncName = net.ReadString()
        SEv[toggleFuncName]()
    end)
end