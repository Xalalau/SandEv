-- Prevent the player from lighting vc fireplace (CLIENT)
-- https://steamcommunity.com/workshop/filedetails/?id=131759821

net.Receive("sev_curse_vc_fireplace", function()
    SEv.Addon:CurseVJFirePlace(net.ReadEntity())
end)

function SEv.Addon:CurseVJFirePlace(ent)
    if not IsValid(ent) then return end

    ent:SetNW2Bool("VJ_FirePlace_Activated", false)
    ent.FirePlaceOn = false

    if ent.StopParticles then
        ent:StopParticles()
    end

    if VJ_STOPSOUND then
        VJ_STOPSOUND(ent.firesd)
    end

    timer.Simple(2, function()
        if ent:IsValid() then
            ent.Think = function() return end
        end
    end)
end
