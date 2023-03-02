-- Trigger to kill illumination

ENT.Base = "base_entity"
ENT.Type = "brush"

function ENT:Setup(instance, eventName, entName, vecA, vecB)
    -- Blink
        -- Requires ent.SetOn and ent.GetOff or ent.Fire("TurnOn") and ent.Fire("TurnOff")
    -- FadeIn and FadeOut
        -- Requires ent.GetBrightness and ent.SetBrightness
    -- Search for external lights
        -- Requires ent.GetLightSize or ent.GetDistance or ent.GetRadius or ent.GetFarZ
    self.supportedLights = {
        ["gmod_light"] = true,
        ["gmod_lamp"] = true,
        ["gmod_softlamp"] = true,
        ["classiclight"] = true,
        ["gmod_wire_light"] = true,
        ["gmod_wire_lamp"] = true,
        ["expensive_light"] = true,
        ["expensive_light_new"] = true,
        ["cheap_light"] = true,
        ["projected_light"] = true,
        ["projected_light_new"] = true,
        ["light_spot"] = true,
        ["spot_light"] = true,
        ["sent_vj_fireplace"] = true,
        ["obj_vj_flareround"] = true
    }

    self:Spawn()

    local vecCenter = (vecA - vecB)/2 + vecB

    self:SetVar("eventName", eventName)
    self:SetVar("entName", entName)
    self:SetVar("vecA", vecA)
    self:SetVar("vecB", vecB)
    self:SetVar("vecCenter", vecCenter)
    self:SetVar("color", Color(252, 119, 3, 255)) -- Orange

    self:SetName(entName)
    self:SetPos(vecCenter)

    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBoundsWS(vecA, vecB)
    self:SetTrigger(true)

    self:SearchForExternalLights()
    self:SearchInside()

    SEv.Ent:SetCursed(self, true)

    instance.Event:SetRenderInfoEntity(self)
end

-- Some entities doesn't active the trigger touch, so we go after them
function ENT:SearchInside()
    local timerName = "sev_force_dimming_" .. tostring(self)

    timer.Create(timerName, 5, 0, function()
        if not self:IsValid() then
            timer.Remove(timerName)
            return
        end

        for _, ent in ipairs(ents.FindInBox(self:GetVar("vecA"), self:GetVar("vecB"))) do
            if not IsEntity(ent) or not ent.GetClass or not ent:GetClass() or not self.supportedLights[ent:GetClass()] then continue end

            local spotlight
            for __, nearEnt in ipairs(ents.FindInSphere(ent:GetPos(), 30)) do
                if nearEnt.GetClass and nearEnt:GetClass() == "point_spotlight" then
                    spotlight = nearEnt
                    break
                end
            end

            if SEv.Light:IsBurnResistant(ent) then
                if math.random(1, 1000) <= (spotlight and 5 or 100) then
                    local blinkTime = math.random(1, 2)

                    SEv.Light:Blink(ent, blinkTime, true,
                        function()
                            if spotlight then
                                spotlight:Fire("LightOn")
                            end
                        end,
                        function()
                            if spotlight then
                                spotlight:Fire("LightOff")
                            end
                        end,
                        function()
                            if spotlight then -- Sometimes the cone fails to end on the right mode, so it's needed
                                timer.Simple(0.1, function() 
                                    if not spotlight:IsValid() then return end
    
                                    spotlight:Fire("LightOn")
                                end)
                            end
                        end
                    )
                end
            elseif not ent.sev_tryed_to_burn then
                self:BurnLight(ent, spotlight)
            end
        end
    end)
end

-- Burn lights
-- Note: Burn-Resistant Lights will turn off, dim and even release sparks, but can still be turned on.
function ENT:BurnLight(ent, spotlight)
    if SEv.Addon:BurnSimfphysLights(ent) then return end
    if SEv.Addon:CurseVJFirePlace(ent) then return end
    if SEv.Addon:CurseVJFlareRound(ent) then return end

    ent.sev_tryed_to_burn = true
    if spotlight then
        spotlight.sev_tryed_to_burn = true
    end

    local IsBurnResistant = SEv.Light:IsBurnResistant(ent)
    local startBlinking = math.random(1, 100) <= (IsBurnResistant and 55 or 17)
    local burned = false

    SEv.Ent:BlockContextMenu(ent, true) -- Prematurely lock context menu

    if startBlinking then
        burned = SEv.Light:Blink(ent, math.random(1, 2), IsBurnResistant,
            function()
                if spotlight then
                    spotlight:Fire("LightOn")
                end
            end,
            function()
                if spotlight then
                    spotlight:Fire("LightOff")
                end
            end,
            function()
                SEv.Light:Burn(ent)

                if spotlight then -- Sometimes the cone fails to end on the right mode, so it's needed
                    timer.Simple(0.1, function()
                        if not spotlight:IsValid() then return end

                        if not IsBurnResistant then
                            spotlight:Fire("LightOff")
                        else
                            spotlight:Fire("LightOn")
                        end

                        SEv.Light:Burn(spotlight)
                    end)
                end
            end
        )
    end

    if not IsBurnResistant and (not startBlinking or not burned) then
        burned = SEv.Light:FadeOut(ent, function()
            SEv.Light:Burn(ent)
        end)
    end

    if burned then
        if math.random(1, 100) <= 10 then
            timer.Simple(math.random(3, 9)/10, function()
                if not ent:IsValid() then return end

                net.Start("sev_create_sparks")
                net.WriteVector(ent:GetPos())
                net.Broadcast()
            end)
        end
    end
end

-- Look for lights that rays hit vecCenter
function ENT:SearchForExternalLights()
    local hookName = "sev_check_lights_" .. tostring(self)

    hook.Add("OnEntityCreated", hookName, function(ent)
        if not self:IsValid() then
            hook.Remove("OnEntityCreated", hookName)
            return
        end

        if not ent.GetClass or not ent:GetClass() or not self.supportedLights[ent:GetClass()] then return end

        local lastPost = ent:GetPos()
        local timerName = "sev_check_lights_" .. tostring(ent) .. "_" .. tostring(self)

        timer.Create(timerName, 1, 0, function()
            if not self:IsValid() or not ent:IsValid() or SEv.Light:IsBurned(ent) then
                timer.Remove(timerName)
                return
            end

            if lastPost == ent:GetPos() then return end
            lastPost = ent:GetPos()

            local GetRadius = ent.GetLightSize or ent.GetDistance or ent.GetRadius or ent.GetFarZ

            if ent:GetPos():Distance(self:GetVar("vecCenter")) - GetRadius(ent) <= 0 then
                self:BurnLight(ent)
            end
        end)
    end)
end

function ENT:StartTouch(ent)
    self:BurnLight(ent)

    if not ent:IsPlayer() then return end

    local ply = ent

    timer.Create("sev_light_dimmer_addons_" .. tostring(ply), math.random(3, 10), 1, function()
        if not ply:IsValid() or not ply.sev_in_dimmer then return end

        SEv.Addon:BreakNWMVGs(ply)
        SEv.Addon:RemoveRaskosNightvisionSWEP(ply)
        SEv.Addon:DropNightVisionGoggles(ply)
        SEv.Addon:DropNightVisionGogglesInspired(ply)

        net.Start("sev_set_spys_night_vision")
        net.WriteBool(false)
        net.Send(ply)

        net.Start("sev_set_arctics_night_vision")
        net.WriteBool()
        net.Send(ply)
    end)
end

function ENT:Touch(ent)
    if ent:IsPlayer() then
        if not ent.sev_in_dimmer then
            ent.sev_in_dimmer = true
        end
            
        if GetConVar("mat_fullbright"):GetBool() then
            RunConsoleCommand("mat_fullbright", "0")
        end
    end
end

function ENT:EndTouch(ent)
    if not ent:IsPlayer() then return end

    ent.sev_in_dimmer = false

    local timerName = "sev_light_dimmer_addons_" .. tostring(ent)

    timer.Simple(0.5, function()
        if not ent.sev_in_dimmer then
            timer.Remove(timerName)
        end
    end)

    net.Start("sev_set_spys_night_vision")
    net.WriteBool(true)
    net.Send(ent)
end
