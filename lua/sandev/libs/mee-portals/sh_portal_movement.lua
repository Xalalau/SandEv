-- this file controls player movement through portals
-- is is also clientside because we need prediction
-- this is probably the most important and hacked together part of the mod

local function updateScale(ply, scale)
    ply:SetModelScale(scale)
    ply:SetViewOffset(Vector(0, 0, 64 * scale))
    ply:SetViewOffsetDucked(Vector(0, 0, 64 * scale / 2))

    if scale < 0.11 then
        ply:SetCrouchedWalkSpeed(0.83)
    else
        ply:SetCrouchedWalkSpeed(0.3)
    end
end

local freezePly = false
local function updateCalcViews(finalPos, finalVel)
    timer.Remove("sev_portals_eye_fix_delay")    --just in case you enter the portal while the timer is running

    local addAngle = 1
    finalPos = finalPos - finalVel * FrameTime() * 0.5    -- why does this work? idk but it feels nice, could be a source prediction thing

    hook.Add("CalcView", "sev_portals_fix", function(ply, origin, angle)
        if ply:EyePos():DistToSqr(origin) > 10000 then return end
        addAngle = addAngle * 0.9
        angle.r = angle.r * addAngle

        -- position ping compensation
        if freezePly and ply:Ping() > 5 then
            finalPos = finalPos + finalVel * FrameTime()
            SEvPortals.DrawPlayerInView = true
        else
            finalPos = ply:EyePos()
            SEvPortals.DrawPlayerInView = false
        end

        return {origin = finalPos, angles = angle}
    end)

    -- weapons sometimes glitch out a bit when you teleport, since the weapon angle is wrong
    hook.Add("CalcViewModelView", "sev_portals_fix", function(wep, vm, oldPos, oldAng, pos, ang)
        ang.r = ang.r * addAngle
        return finalPos, ang
    end)

    -- finish eyeangle lerp
    timer.Create("sev_portals_eye_fix_delay", 0.5, 1, function()
        local ang = LocalPlayer():EyeAngles()
        ang.r = 0
        LocalPlayer():SetEyeAngles(ang)
        hook.Remove("CalcView", "sev_portals_fix")
        hook.Remove("CalcViewModelView", "sev_portals_fix")
    end)
end

-- this indicates wheather the player is 'teleporting' and waiting for the server to give the OK that the client position is valid
-- (only a problem with users that have higher ping)
if SERVER then
    -- util.AddNetworkString("SEv_PORTALS_FREEZE") -- Moved to the net init file
else
    net.Receive("SEv_PORTALS_FREEZE", function()
        if game.SinglePlayer() then 
            updateCalcViews(Vector(), Vector())

            if net.ReadBool() then
                SEvPortals.ToggleMirror()
            end
        end --singleplayer fixes (cuz stupid move hook isnt clientside in singleplayer)

        freezePly = false
    end)
end

local function seamless_check(e) -- for traces
    return not (SEv.Ent:GetRealClass(e) == "sev_portal" or e:GetClass() == "player")
end

-- 'no collide' the player with the wall by shrinking the player's collision box
local traceTable = {}
local function editPlayerCollision(mv, ply)
    if ply.PORTAL_STUCK_OFFSET != 0 then
        traceTable.start = ply:GetPos() + ply:GetVelocity() * 0.02
    else
        traceTable.start = ply:GetPos()
    end
    traceTable.endpos = traceTable.start
    traceTable.mins = Vector(-16, -16, 0)
    traceTable.maxs = Vector(16, 16, 72 - (ply:Crouching() and 1 or 0) * 36)
    traceTable.filter = ply

    if not ply.SEv_PORTAL_STUCK_OFFSET then
        traceTable.ignoreworld = true
    else
        -- extrusion in case the player enables non-ground collision and manages to clip outside of the portal while they are falling (rare case)
        if ply.SEv_PORTAL_STUCK_OFFSET ~= 0 then
            local tr = SEvPortals.TraceLine({start = ply:EyePos(), endpos = ply:EyePos() - Vector(0, 0, 64), filter = ply})

            if tr.Hit and SEv.Ent:GetRealClass(tr.Entity) ~= "sev_portal" then
                ply.SEv_PORTAL_STUCK_OFFSET = nil
                mv:SetOrigin(tr.HitPos)
                ply:ResetHull()
                return 
            end
        end
    end

    local tr = util.TraceHull(traceTable)

    -- getting this to work on the ground was a FUCKING headache
    if not ply.SEv_PORTAL_STUCK_OFFSET and
       tr.Hit and
       SEv.Ent:GetRealClass(tr.Entity) == "sev_portal" and
       tr.Entity.GetExitPortal and
       tr.Entity:GetExitPortal() and
       tr.Entity:GetExitPortal():IsValid()
        then
        local secondaryOffset = 0

        if tr.Entity:GetUp():Dot(Vector(0, 0, 1)) > 0.5 then        -- the portal is on the ground
            traceTable.mins = Vector(0, 0, 0)
            traceTable.maxs = Vector(0, 0, 72)

            local tr = util.TraceHull(traceTable)
            if not tr.Hit or SEv.Ent:GetRealClass(tr.Entity) ~= "sev_portal" then
                return -- we accomplished nothing :DDDD
            end

            if tr.Entity:GetUp():Dot(Vector(0, 0, 1)) > 0.999 then
                ply.SEv_PORTAL_STUCK_OFFSET = 72
            else
                ply.SEv_PORTAL_STUCK_OFFSET = 72
                secondaryOffset = 36
            end
        elseif tr.Entity:GetUp():Dot(Vector(0, 0, 1)) < -0.9 then 
            return                             -- the portal is on the ceiling
        else
            ply.SEv_PORTAL_STUCK_OFFSET = 0        -- the portal is not on the ground
        end

        ply:SetHull(Vector(-4, -4, 0 + ply.SEv_PORTAL_STUCK_OFFSET), Vector(4, 4, 72 + secondaryOffset))
        ply:SetHullDuck(Vector(-4, -4, 0 + ply.SEv_PORTAL_STUCK_OFFSET), Vector(4, 4, 36 + secondaryOffset))

    elseif ply.SEv_PORTAL_STUCK_OFFSET and not tr.Hit then
        ply:ResetHull()
        ply.SEv_PORTAL_STUCK_OFFSET = nil
    end
    
    traceTable.ignoreworld = false
end

-- teleport players
hook.Add("Move", "sev_portal_teleport", function(ply, mv)
    if not IsValid(ply) then return end -- In one of my automatic error reports ply appeared as number... - Xala

    if not SEvPortals or SEvPortals.portalIndex < 1 then 
        if ply.SEv_PORTAL_STUCK_OFFSET then
            ply:ResetHull()
            ply.SEv_PORTAL_STUCK_OFFSET = nil
        end

        return 
    end

    local plyPos = ply:EyePos()
    traceTable.start = plyPos - mv:GetVelocity() * 0.02
    traceTable.endpos = plyPos + mv:GetVelocity() * 0.02
    traceTable.filter = ply
    local tr = SEvPortals.TraceLine(traceTable)

    editPlayerCollision(mv, ply)

    if not tr.Hit then return end

    local hitPortal = tr.Entity
    if SEv.Ent:GetRealClass(hitPortal) == "sev_portal" and hitPortal.GetExitPortal and hitPortal:GetExitPortal() and hitPortal:GetExitPortal():IsValid() then
        if mv:GetVelocity():Dot(hitPortal:GetUp()) < 0 then
            if ply.SEv_PORTAL_TELEPORTING then return end
            freezePly = true

            -- wow look at all of this code just to teleport the player
            local exitPortal = hitPortal:GetExitPortal()
            local editedPos, editedAng = SEvPortals.TransformPortal(hitPortal, exitPortal, tr.HitPos, ply:EyeAngles())
            local _, editedVelocity = SEvPortals.TransformPortal(hitPortal, exitPortal, nil, mv:GetVelocity():Angle())
            local max = math.Max(mv:GetVelocity():Length(), exitPortal:GetUp():Dot(-physenv.GetGravity() / 3))

            --ground can fluxuate depending on how the user places the portals, so we need to make sure we're not going to teleport into the ground
            local eyeHeight = (ply:EyePos() - ply:GetPos())
            local editedPos = editedPos - eyeHeight
            traceTable.start = editedPos + eyeHeight
            traceTable.endpos = editedPos - Vector(0, 0, 0.1)
            traceTable.filter = seamless_check
            local floor_trace = SEvPortals.TraceLine(traceTable)
            local finalPos = editedPos

            -- dont do extrusion if the player is noclipping
            local offset
            if ply:GetMoveType() ~= MOVETYPE_NOCLIP then
                offset = floor_trace.HitPos
            else
                offset = editedPos
            end

            local exitSize = (exitPortal:GetExitSize()[1] / hitPortal:GetExitSize()[1])
            if ply.SEv_SCALE_MULTIPLIER then
                if ply.SEv_SCALE_MULTIPLIER * exitSize ~= ply.SEv_SCALE_MULTIPLIER then
                    ply.SEv_SCALE_MULTIPLIER = math.Clamp(ply.SEv_SCALE_MULTIPLIER * exitSize, 0.01, 10)
                    finalPos = finalPos + (eyeHeight - eyeHeight * exitSize)
                    updateScale(ply, ply.SEv_SCALE_MULTIPLIER)
                end
            end

            finalPos = finalPos - (editedPos - offset) * exitSize + Vector(0, 0, 0.1)    -- small offset so we arent in the floor

            -- apply final velocity
            mv:SetVelocity(editedVelocity:Forward() * max * exitSize)

            -- lerp fix for singleplayer
            if game.SinglePlayer() then
                ply:SetPos(finalPos)
                ply:SetEyeAngles(editedAng)
            end

            -- send the client that the new position is valid
            if SERVER then 
                -- lerp fix for singleplayer
                if game.SinglePlayer() then
                    ply:SetPos(finalPos)
                    ply:SetEyeAngles(editedAng)
                end

                mv:SetOrigin(finalPos)
                net.Start("SEv_PORTALS_FREEZE")
                net.WriteBool(hitPortal == exitPortal)
                net.Send(ply)
            else
                updateCalcViews(finalPos + (ply:EyePos() - ply:GetPos()), editedVelocity:Forward() * max * exitSize, (ply.SEv_SCALE_MULTIPLIER or 1) * exitSize)    --fix viewmodel lerping for a tiny bit
                ply:SetEyeAngles(editedAng)
                ply:SetPos(finalPos)

                if hitPortal:GetExitPortal() == hitPortal then
                    SEvPortals.ToggleMirror()
                end
            end

            ply.SEv_PORTAL_TELEPORTING = true
            ply.SEv_PORTAL_STUCK_OFFSET = exitPortal:GetUp():Dot(Vector(0, 0, 1)) > 0.999 and 72 or 0
            ply:SetHull(Vector(-4, -4, ply.SEv_PORTAL_STUCK_OFFSET), Vector(4, 4, 72 + ply.SEv_PORTAL_STUCK_OFFSET * 0.5))
            ply:SetHullDuck(Vector(-4, -4, ply.SEv_PORTAL_STUCK_OFFSET), Vector(4, 4, 36 + ply.SEv_PORTAL_STUCK_OFFSET * 0.5))

            timer.Simple(0.03, function()
                if IsValid(ply) then
                    ply.SEv_PORTAL_TELEPORTING = false
                end
            end)

            hitPortal:RunPlyUsageCallbacks(ply)
            if hitPortal ~= exitPortal then
                exitPortal:RunPlyUsageCallbacks(ply)
            end

            return true
        end
    end
end)

local searchPortalsRadius = 2000 -- Longer seek distances make reentry smoother
local angleRange = math.pi / 6 -- 60º
hook.Add("Move", "sev_portal_funneling", function(ply, move)
    if not SEvPortals or SEvPortals.portalIndex < 1 then return end

    local velVec = move:GetVelocity()
    local minVelSqr = ply:GetRunSpeed() * ply:GetRunSpeed()
    local velSqr = velVec:LengthSqr()

    if velSqr > minVelSqr then
        -- Get the nearest portal with the acceptable entry angle
        -- Both the player distance and velocity vectors must have their angles in the acceptable entry range
        local foundPortals = ents.FindInSphere(ply:GetPos(), searchPortalsRadius)
        local selectedPortal
        local lastDistSqr = 1/0 -- infinite
        for _, portal in ipairs(foundPortals) do
            if SEv.Ent:GetRealClass(portal) == "sev_portal" and portal:GetNWBool("enableFunneling", false) then
                local portalDownVec = -portal:GetUp()
                local distVec = portal:GetPos() - ply:GetPos()
                local angleBetweenDistAndPortalDownVecs = math.acos(
                    (distVec.x * portalDownVec.x + distVec.y * portalDownVec.y + distVec.z * portalDownVec.z) / (
                        math.sqrt(distVec:LengthSqr()) --* math.sqrt(portalDownVec:LengthSqr()) -- Ignored this since it's usually 1
                    )
                )
                if angleBetweenDistAndPortalDownVecs < angleRange then
                    local angleBetweenVelAndPortalDownVecs = math.acos(
                        (velVec.x * portalDownVec.x + velVec.y * portalDownVec.y + velVec.z * portalDownVec.z) / (
                            math.sqrt(velSqr) --* math.sqrt(portalDownVec:LengthSqr())
                        )
                    )
                    local currentDistSqr = distVec:LengthSqr()

                    if angleBetweenVelAndPortalDownVecs < angleRange and currentDistSqr < lastDistSqr then
                        selectedPortal = portal
                        lastDistSqr = currentDistSqr
                    end
                end
            end
        end

        if selectedPortal then
            -- Slowly fix the player's trajectory making it freer if he tries to move sideways
            local vel = math.sqrt(velSqr)
            local velCorretionVec = (selectedPortal:GetPos() - (ply:GetPos() - velVec * 0.1)):GetNormalized() * vel
            local changeProportion = move:GetSideSpeed() == 0 and 0.05 or 0.01
            local newVelVec = velVec * (1 - changeProportion) + velCorretionVec * changeProportion

            move:SetVelocity(newVelVec)
        end
    end
end)
