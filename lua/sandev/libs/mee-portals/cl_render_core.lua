-- this is the rendering code for the portals, some references from: https://github.com/MattJeanes/world-portals

local sky_cvar = GetConVar("sv_skyname")
local sky_name = ""
local sky_materials = {}

local portals = {}
local oldHalo = 0
local timesRendered = 0

local skysize = 16384    --2^14, default zfar limit
local angle_zero = Angle(0, 0, 0)

local renderViewTable = {
    x = 0,
    y = 0,
    w = ScrW(),
    h = ScrH(),
    origin = Vector(),
    angles = Angle(),
    drawviewmodel = false,
}

-- sort the portals by distance since draw functions do not obey the z buffer
timer.Create("sev_portal_distance_fix", 0.25, 0, function()
    if not SEv.Portals or SEv.Portals.portalIndex < 1 then return end

    portals = ents.FindByClass("sev_portal")
    table.sort(portals, function(a, b) 
        return a:GetPos():DistToSqr(EyePos()) < b:GetPos():DistToSqr(EyePos())
    end)

    -- update sky material (I guess it can change?)
    if sky_name ~= sky_cvar:GetString() then
        sky_name = sky_cvar:GetString()

        local prefix = "skybox/" .. sky_name
        sky_materials[1] = Material(prefix .. "bk")
        sky_materials[2] = Material(prefix .. "dn")
        sky_materials[3] = Material(prefix .. "ft")
        sky_materials[4] = Material(prefix .. "lf")
        sky_materials[5] = Material(prefix .. "rt")
        sky_materials[6] = Material(prefix .. "up")
    end
end)

-- update the rendertarget here since we cant do it in postdraw (cuz of infinite recursion)
local physgun_halo = GetConVar("physgun_halo")
hook.Add("RenderScene", "sev_portals_draw", function(eyePos, eyeAngles, fov)
    if not SEv.Portals or SEv.Portals.portalIndex < 1 then return end
    if not SEv.Portals.PortalRTs then return end
    SEv.Portals.Rendering = true

    -- black halo clipping plane fix (Thanks to homonovus)
    physgun_halo = physgun_halo or GetConVar("physgun_halo")
    if not physgun_halo then return end
    local oldHalo = physgun_halo:GetInt()
    physgun_halo:SetInt(0)

    for k, v in ipairs(portals) do
        if timesRendered >= SEv.Portals.MaxRTs then break end
        if not v:IsValid() or not v:GetExitPortal():IsValid() then continue end

        if timesRendered < SEv.Portals.MaxRTs and SEv.Portals.ShouldRender(v, eyePos, eyeAngles) then
            local exitPortal = v:GetExitPortal()
            local editedPos, editedAng = SEv.Portals.TransformPortal(v, exitPortal, eyePos, eyeAngles)

            renderViewTable.origin = editedPos
            renderViewTable.angles = editedAng
            renderViewTable.fov = fov

            timesRendered = timesRendered + 1
            v.PORTAL_RT_NUMBER = timesRendered    -- the number index of the rendertarget it will use in rendering

            -- render the scene
            local up = exitPortal:GetUp()
            local oldClip = render.EnableClipping(true)
            render.PushRenderTarget(SEv.Portals.PortalRTs[timesRendered])
            render.PushCustomClipPlane(up, up:Dot(exitPortal:GetPos() + up * 0.49))
            render.RenderView(renderViewTable)
            render.PopCustomClipPlane()
            render.EnableClipping(oldClip)
            render.PopRenderTarget()
        end
    end

    physgun_halo:SetInt(oldHalo)

    SEv.Portals.Rendering = false
    timesRendered = 0
end)

-- draw the player in renderview
hook.Add("ShouldDrawLocalPlayer", "sev_portal_drawplayer", function()
    if SEv.Portals and SEv.Portals.Rendering and not SEv.Portals.DrawPlayerInView then 
        return true 
    end
end)

-- (REWRITE THIS!)
-- draw the 2d skybox in place of the black (Thanks to Fafy2801)
local function drawsky(pos, ang, size, size_2, color, materials)
    -- BACK
    render.SetMaterial(materials[1])
    render.DrawQuadEasy(pos + Vector(0, size, 0), ang:Right(), size_2, size_2, color, 0)
    -- DOWN
    render.SetMaterial(materials[2])
    render.DrawQuadEasy(pos - Vector(0, 0, size), ang:Up(), size_2, size_2, color, 180)
    -- FRONT
    render.SetMaterial(materials[3])
    render.DrawQuadEasy(pos - Vector(0, size, 0), -ang:Right(), size_2, size_2, color, 0)
    -- LEFT
    render.SetMaterial(materials[4])
    render.DrawQuadEasy(pos - Vector(size, 0, 0), ang:Forward(), size_2, size_2, color, 0)
    -- RIGHT
    render.SetMaterial(materials[5])
    render.DrawQuadEasy(pos + Vector(size, 0, 0), -ang:Forward(), size_2, size_2, color, 0)
    -- UP
    render.SetMaterial(materials[6])
    render.DrawQuadEasy(pos + Vector(0, 0, size), -ang:Up(), size_2, size_2, color, 180)
end

hook.Add("PostDrawTranslucentRenderables", "sev_portal_skybox", function()
    if not SEv.Portals or SEv.Portals.portalIndex < 1 then return end
    if not SEv.Portals.Rendering or util.IsSkyboxVisibleFromPoint(renderViewTable.origin) then return end
    if not next(sky_materials) then return end
    render.OverrideDepthEnable(true, false)
    drawsky(renderViewTable.origin, angle_zero, skysize, -skysize * 2, color_white, sky_materials)
    render.OverrideDepthEnable(false , false)
end)
