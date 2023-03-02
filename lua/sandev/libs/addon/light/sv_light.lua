-- Burn all lights from simfphys cars
-- https://steamcommunity.com/workshop/filedetails/?id=771487490
function SEv.Addon:BurnSimfphysLights(vehicle)
    if not vehicle or not vehicle:IsValid() then return false end

    if vehicle:GetClass() == "gmod_sent_vehicle_fphysics_base" then
        local entTable = vehicle:GetTable()

        if entTable.SetLightsEnabled then
            entTable:SetLightsEnabled(false)
            entTable.SetLightsEnabled = function() return end
        end

        if entTable.SetFogLightsEnabled then
            entTable:SetFogLightsEnabled(false)
            entTable.SetFogLightsEnabled = function() return end
        end

        if entTable.SetLampsEnabled then
            entTable:SetLampsEnabled(false)
            entTable.SetLampsEnabled = function() return end
        end

        vehicle:SetTable(entTable)

        return true
    end

    return false
end

-- Modify some light addon functions to work like standard light tools
hook.Add("OnEntityCreated", "sev_light_spawned", function(ent)
    if ent and ent:IsValid() then
        SEv.Addon:AddWiremodLightFunctions(ent)
        SEv.Addon:AddAdvLightEntsFunctions(ent)
        SEv.Addon:AddVJLightFunctions(ent)
    end
end)

-- Prevent the player from lighting vc fireplace (SERVER)
-- https://steamcommunity.com/workshop/filedetails/?id=131759821
function SEv.Addon:CurseVJFirePlace(ent)
    if ent:GetClass() ~= "sent_vj_fireplace" then return false end

    net.Start("sev_curse_vc_fireplace")
    net.WriteEntity(ent)
    net.Broadcast()

    return true
end

-- Prevent the player from lighting vj flarerounds
-- https://steamcommunity.com/workshop/filedetails/?id=131759821
function SEv.Addon:CurseVJFlareRound(ent)
    if ent:GetClass() ~= "obj_vj_flareround" then return false end

    ent.Dead = true
    if ent.CurrentIdleSound then ent.CurrentIdleSound:Stop() end

    if ent.StopParticles then
        ent:StopParticles()
    end
    
    timer.Simple(2, function()
        if IsValid(ent) then
            ent:Remove()
        end
    end)

    return true
end

-- Prevent the player from lighting vc fireplace and vj flarerounds (SERVER)
-- https://steamcommunity.com/workshop/filedetails/?id=131759821
function SEv.Addon:AddVJLightFunctions(ent)
    if ent:GetClass() == "sent_vj_fireplace" or ent:GetClass() == "obj_vj_flareround" then
        function ent:GetRadius()
            return 200
        end
    end
end

-- Wiremod lamps and lights
-- https://steamcommunity.com/sharedfiles/filedetails/?id=160250458
function SEv.Addon:AddWiremodLightFunctions(ent)
    if ent:GetClass() == "gmod_wire_lamp" then
        function ent:GetDistance()
            return ent.Dist
        end

        function ent:GetBrightness()
            return ent.Brightness
        end

        function ent:SetBrightness(value)
            ent.Brightness = value
            ent:UpdateLight()
        end

        function ent:Burn()
            emptyFunction = function() return end

            if ent:GetOn() then
                ent:Switch(false)
            end
    
            ent.SetOn = emptyFunction
            ent.Switch = emptyFunction
            ent.TriggerInput = emptyFunction
        end
    end

    if ent:GetClass() == "gmod_wire_light" then
        ent.GetDistance = ent.GetSize
        ent.SetOn = function() return end
        ent.GetOn = function() return end

        function ent:Burn()
            emptyFunction = function() return end

            ent:Directional(nil)
            ent:Radiant(nil)
            ent:SetGlow(false)
            ent:SetBrightness(0)
            ent:SetSize(0)
            ent:SetSpriteSize(0)
    
            ent.Directional = emptyFunction
            ent.Radiant = emptyFunction
            ent.SetGlow = emptyFunction
            ent.SetBrightness = emptyFunction
            ent.SetSize = emptyFunction
            ent.SetSpriteSize = emptyFunction
            ent.TriggerInput = emptyFunction
        end
    end
end

-- Advanced Light Entities
-- https://steamcommunity.com/workshop/filedetails/?id=493751477
function SEv.Addon:AddAdvLightEntsFunctions(ent)
    if ent.GetActiveState and (ent:GetClass() == "cheap_light" or ent:GetClass() == "spot_light") then
        function ent:GetOn()
            return ent:GetActiveState()
        end

        function ent:SetOn(...)
            ent:SetActiveState(...)
        end
    end
end
