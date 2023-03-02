-- Visual effects

net.Receive("sev_create_smoke_stream", function()
    ParticleEffect("steam_train", net.ReadVector(), net.ReadAngle())
end)

net.Receive("sev_create_sparks", function()
    SEv.Effect:CreateSparks(net.ReadVector())
end)

net.Receive("sev_create_ring_explosion", function()
    SEv.Effect:CreateRingExplosion(net.ReadVector())
end)

-- Sparks

function SEv.Effect:CreateSparks(pos)
    local emitter = ParticleEmitter(pos)
    local total = math.random(3, 19)

    for i = 0, total do
        local part = emitter:Add("effects/spark", pos)

        if part then
            part:SetDieTime(1)
    
            part:SetStartAlpha(255)
            part:SetEndAlpha(0)
    
            part:SetStartSize(5)
            part:SetEndSize(0)
    
            part:SetGravity(Vector(0, 0, -250)) 
            part:SetVelocity(VectorRand() * 50)
        end
    end
    
    emitter:Finish()
end

-- Laser beam

-- Requires: 3D rendering context
-- Beam types from 1 (thinner) to 3 (larger)
function SEv.Effect:CreateBeam(startPos, endPos, beamType, color)
    -- Code adapted from https://maurits.tv/data/garrysmod/wiki/wiki.garrysmod.com/indexffa5.html

    local beams = {
        Material( "sprites/physbeam"),
        Material( "sprites/physbeama"),
        Material( "sprites/physgbeamb")
    }

    local beam = beams[beamType]

    -- setup our variables
    local start_pos = startPos;
    local end_pos = endPos;
    local dir = ( end_pos - start_pos );
    local increment = dir:Length() / 12;
    dir:Normalize();
     
    -- set material
    render.SetMaterial( beam );
     
    -- start the beam with 14 points
    render.StartBeam( 14 );
     
    -- add start
    render.AddBeam(
        start_pos, -- Start position
        32, -- Width
        CurTime(), -- Texture coordinate
        color -- Color
    );
     
    local i;
    for i = 1, 12 do
        -- get point
        local point = ( start_pos + dir * ( i * increment ) ) + VectorRand() * math.random( 1, 16 );
     
        -- texture coords
        local tcoord = CurTime() + ( 1 / 12 ) * i;
     
        -- add point
        render.AddBeam(
            point,
            32,
            tcoord,
            color
        );
     
    end
     
    -- add the last point
    render.AddBeam(
        end_pos,
        32,
        CurTime() + 1,
        color
    );
     
    -- finish up the beam
    render.EndBeam();
end

-- Ring explosion

-- Very closely emulates a Combine Ball explosion
-- https://wiki.facepunch.com/gmod/effects.BeamRingPoint
function SEv.Effect:CreateRingExplosion(pos)
    if not pos then return end

    EmitSound(Sound("NPC_CombineBall.Explosion"), pos, 1, CHAN_AUTO, 1, 75, 0, 100)
    util.ScreenShake(pos, 20, 150, 1, 1250)
    
    local data = EffectData()
    data:SetOrigin(pos)
    util.Effect("cball_explode",data)
    
    effects.BeamRingPoint(pos, 0.2, 12, 1024, 64, 0, Color(255,255,225,32),{
        speed=0,
        spread=0,
        delay=0,
        framerate=2,
        material="sprites/lgtning.vmt"
    })

    effects.BeamRingPoint(pos, 0.5, 12, 1024, 64, 0, Color(255,255,225,64),{
        speed=0,
        spread=0,
        delay=0,
        framerate=2,
        material="sprites/lgtning.vmt"
    })
end