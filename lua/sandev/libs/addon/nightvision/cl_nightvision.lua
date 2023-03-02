-- Break spy's Night Vision
-- https://steamcommunity.com/sharedfiles/filedetails/?id=224378049

net.Receive("sev_set_spys_night_vision", function()
    SEv.Addon:SetSpysNightVision(net.ReadBool())
end)

function SEv.Addon:SetSpysNightVision(state)
    if not self.NV_ToggleNightVision then return end

    local NV_Status = hook.GetTable()["RenderScreenspaceEffects"]["NV_FX"] and true or false

    if NV_Status ~= state then
        self.spysNightVision = state
        self.NV_ToggleNightVision(LocalPlayer())
    end
end

function SEv.Addon:StealSpysNightVisionControl()
    local NV_ToggleNightVision = concommand.GetTable()["nv_togg"]

    if NV_ToggleNightVision then
        local NV_MonitorIllumination = hook.GetTable()["Think"]["NV_MonitorIllumination"]
        
        self.NV_ToggleNightVision = NV_ToggleNightVision

        hook.GetTable()["Think"]["NV_MonitorIllumination"] = function(...)
            if self.spysNightVision then
                NV_MonitorIllumination(...)
            end
        end
    
        concommand.GetTable()["nv_togg"] = function(...)
            if self.spysNightVision then
                NV_ToggleNightVision(...)
            end
        end
    end    
end

-- Break Arctic's Night Vision (CLIENT)
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2389553185

net.Receive("sev_set_arctics_night_vision", function()
    SEv.Addon:SetArcticsNightVision()
end)

function SEv.Addon:SetArcticsNightVision()
    if ArcticNVGs and ArcticNVGs_Enabled then
        local goggles = LocalPlayer():GetNWInt("nvg", 0)
        local goggles_table = ArcticNVGs[goggles]

        ArcticNVGs_Toggle()

        net.Start("sev_set_arctics_night_vision")
        net.SendToServer()
    end
end

-- Break Night Vision Goggles (CLIENT)
-- https://steamcommunity.com/sharedfiles/filedetails/?id=1496324549

net.Receive("sev_drop_night_vision_goggles", function(_, ply)
    net.Start("DropDrGNVG")
    net.SendToServer()
end)

-- Break Night Vision Goggles (MW:2019 Inspired) (CLIENT)
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2242151511

net.Receive("sev_drop_night_vision_goggles_inspired", function(_, ply)
    net.Start("DropNVG")
    net.SendToServer()
end)
