-- Break Modern Warfare NVGs
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2532012185
function SEv.Addon:BreakNWMVGs(ply)
    if not ply or not ply:IsValid() or not ply:IsPlayer() then return end
 
    if ply.vrnvgequipped and ply.vrnvgflipped and not ply.vrnvgbroken then
        timer.Simple(2, function() -- Double check! Removing a valid object too quickly can result in a buggy partially broken display
            if ply:IsValid() and ply.vrnvgequipped and ply.vrnvgflipped and not ply.vrnvgbroken then
                ply.vrnvgbroken = true

                if util.NetworkStringToID("vrnvgnetbreakeasymode") then
                    net.Start("vrnvgnetbreakeasymode")
                    net.WriteBool(true)
                    net.Send(ply)
                end

                ply:ViewPunch(Angle(-8,0,0))
            end
        end)
    end
end

-- Remove Rasko's Night vision SWEP
-- https://steamcommunity.com/sharedfiles/filedetails/?id=770421936
function SEv.Addon:RemoveRaskosNightvisionSWEP(ply)
    if not (ply and ply:IsValid() and ply:IsPlayer()) then return end

    local weapon = ply:GetActiveWeapon()

    if weapon and weapon:IsValid() then
        if weapon:GetClass() == "nightvision" then
            net.Start("RASKO_NightvisionOff")
            net.WriteEntity(ply)
            net.Send(ply)
            
            timer.Simple(0.2, function()
                if weapon:IsValid() then
                    weapon:Remove()
                end
            end)
        end
    end
end

-- Break Arctic's Night Vision (SERVER)
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2389553185

net.Receive("sev_set_arctics_night_vision", function(_, ply)
    SEv.Addon:SetArcticsNightVision(ply)
end)

function SEv.Addon:SetArcticsNightVision(ply)
    timer.Simple(1, function()
        if not ply:IsValid() or not ArcticNVGs then return end

        local drop = (ArcticNVGs[ply:GetNWInt("nvg", 0)] or {}).Entity

        if drop then
            local ent = ents.Create(drop)

            ent:SetPos(ply:EyePos())
            ent:SetAngles(ply:EyeAngles())
            ent:SetOwner(ply)
            ent:Spawn()
        end

        ply:SetNWInt("nvg", 0)
    end)
end

-- Break Night Vision Goggles (SERVER)
-- https://steamcommunity.com/sharedfiles/filedetails/?id=1496324549

function SEv.Addon:DropNightVisionGoggles(ply)
    if ply:GetNWBool("WearingDrGNVG") then
        net.Start("sev_drop_night_vision_goggles")
        net.Send(ply)
    end
end

-- Break Night Vision Goggles (MW:2019 Inspired) (SERVER)
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2242151511

function SEv.Addon:DropNightVisionGogglesInspired(ply)
    if ply:GetNWBool("WearingNVG") then
        net.Start("sev_drop_night_vision_goggles_inspired")
        net.Send(ply)
    end
end
