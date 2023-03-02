-- Only functions that apply to entities in general!!

-- Detour management

local ENT = FindMetaTable("Entity")
SEv_ENT_GetClass = SEv_ENT_GetClass or ENT.GetClass
SEv_IsValid = SEv_IsValid or IsValid

-- Is ent spawned by a player

function SEv.Ent:IsSpawnedByPlayer(ent)
    return IsValid(ent) and ent:GetNWBool("sev_spawned") or false
end

-- Cleanup

function SEv.Ent:BlockCleanup(ent, value) -- Alias
    SEv.Map:BlockEntCleanup(ent, value)
end

-- Physgun

function SEv.Ent:BlockPhysgun(ent, value, ply)
    if ply and ply:IsPlayer() then
        ply.sev_physgyun = ply.sev_physgyun or {}
        ply.sev_physgyun[ent] = value
    else
        ent.sev_physgyun = value
    end
end

function SEv.Ent:IsPhysgunBlocked(ent, ply)
    if not IsValid(ent) then return end

    if ply and ply:IsPlayer() then
        return ply.sev_physgyun and ply.sev_physgyun[ent]
    else
        return ent.sev_physgyun
    end
end

hook.Add("PhysgunPickup", "sev_physgun_pickup_control", function(ply, ent)
    local isBlocked = SEv.Ent:IsPhysgunBlocked(ent, ply) or SEv.Ent:IsPhysgunBlocked(ent)

    if isBlocked ~= nil then
        return not isBlocked
    end
end)

hook.Add("OnPhysgunFreeze", "sev_physgun_freeze_control", function(weapon, physobj, ent, ply)
    return SEv.Ent:IsPhysgunBlocked(ent) or SEv.Ent:IsPhysgunBlocked(ent, ply) or nil
end)

hook.Add("CanPlayerUnfreeze", "sev_physgun_unfreeze_control", function(ply, ent, phys)
    if SEv.Ent:IsPhysgunBlocked(ent) or SEv.Ent:IsPhysgunBlocked(ent, ply) then
        return false
    end
end)

-- Toolgun

function SEv.Ent:BlockTools(ent, ...)
    local newTab = ent.sev_blocked_tools or {}

    for k, toolname in ipairs({ ... }) do
        newTab[toolname] = true
    end

    ent.sev_blocked_tools = newTab
end

function SEv.Ent:UnblockTools(ent, ...)
    if ent.sev_blocked_tools then
        for k, toolname in ipairs({ ... }) do
            ent.sev_blocked_tools[toolname] = nil
        end
    end
end

function SEv.Ent:GetBlockedTools(ent)
    return ent.sev_blocked_tools
end

function SEv.Ent:BlockToolgun(ent, value, ply)
    if ply and ply:IsPlayer() then
        ply.sev_toolgun = ply.sev_toolgun or {}
        ply.sev_toolgun[ent] = value
    else
        ent.sev_toolgun = value
    end
end

function SEv.Ent:IsToolgunBlocked(ent, ply)
    if ply and ply:IsPlayer() then
        return ply.sev_toolgun and ply.sev_toolgun[ent]
    else
        return ent.sev_toolgun
    end
end

hook.Add("CanTool", "sev_toolgun_permission_control", function(ply, tr, toolname, tool, button)
    local ent = tr.Entity
    local IsToolgunBlocked = SEv.Ent:IsToolgunBlocked(ent) or SEv.Ent:IsToolgunBlocked(ent, ply)

    if IsValid(ent) then
        if IsToolgunBlocked ~= nil then
            return not ent.sev_toolgun
        end

        local blockedTools = SEv.Ent:GetBlockedTools(ent)

        if blockedTools then
            return not blockedTools[toolname]
        end
    end
end)

-- Context menu

function SEv.Ent:BlockContextMenu(ent, value, ply)
    if ply and ply:IsPlayer() then
        ent:SetNWBool("sev_context_menu_" .. ply:SteamID(), value)
    else
        ent:SetNWBool("sev_context_menu", value)
    end
end

function SEv.Ent:IsContextMenuBlocked(ent, ply)
    if ply and ply:IsPlayer() then
        return ent:GetNWBool("sev_context_menu_" .. ply:SteamID())
    else
        return ent:GetNWBool("sev_context_menu")
    end
end

-- Set fake invalid (breaks numerous iterations, mainly used to simulate a brush) (wild)

function SEv.Ent:IsFakeInvalid(ent)
    return ent:GetNWBool("sev_fake_invalid") and true
end

function SEv.Ent:SetFakeInvalid(ent, value)
    ent:SetNWBool("sev_fake_invalid", value)
end

function IsValid(var)
    if isfunction(var) or isnumber(var) or isbool(var) then return false end -- Extra checks to avoid common addon errors
    if not SEv_IsValid(var) then return false end
    if IsEntity(var) and var.GetNWBool and SEv.Ent:IsFakeInvalid(var) then return false end
    return true
end

-- Curse (events use this information in a variety of ways)

function SEv.Ent:SetCursed(ent, value)
    ent.sev_cursed = value
end

function SEv.Ent:IsCursed(ent)
    return ent.sev_cursed
end

function SEv.Ent:HideCurse(ent, value)
    ent.sev_hide_curse = value
end

function SEv.Ent:IsCurseHidden(ent)
    return ent.sev_hide_curse
end

-- Sounds

function SEv.Ent:SetMute(ent, value)
    ent.sev_muted = value
end

function SEv.Ent:IsMuted(ent)
    return ent.sev_muted
end

hook.Add("EntityEmitSound", "sev_sound_control", function(soundTab)
    if soundTab.Entity and SEv.Ent:IsMuted(soundTab.Entity) then
        return false
    end
end)

-- Fade

local function Fade(ent, fadingTime, callback, args, isIn)
    if not ent or not ent:IsValid() then return end

    local hookName = "sev_fade_" .. (isIn and "in" or "out") .. "_" .. tostring(ent)
    local maxTime = CurTime() + fadingTime
    local renderMode = ent:GetRenderMode()
    local color = ent:GetColor()

    -- Make fade out prevail over fade in
    if not isIn and hook.GetTable()["Tick"] and hook.GetTable()["Tick"]["sev_fade_in_" .. tostring(ent)] then
        hook.Remove("Tick", "sev_fade_in_" .. tostring(ent))
    end

    ent:SetRenderMode(RENDERMODE_TRANSCOLOR) -- Note: it doesn't work with everything

    hook.Add("Tick", hookName, function()
        if CurTime() >= maxTime or not ent:IsValid() then
            if ent:IsValid() then
                ent:SetRenderMode(renderMode)

                if callback and isfunction(callback) then
                    callback(unpack(args))
                end
            end

            hook.Remove("Tick", hookName)
        else
            local percentage = (isIn and 1 or 0) - (maxTime - CurTime()) / fadingTime * (isIn and 1 or -1)

            ent:SetColor(Color(color.r, color.g, color.b, color.a * percentage))
        end
    end)
end

function SEv.Ent:FadeIn(ent, fadingTime, callback, ...)
    Fade(ent, fadingTime, callback, { ... }, true)
end

function SEv.Ent:FadeOut(ent, fadingTime, callback, ...)
    Fade(ent, fadingTime, callback, { ... })
end

-- Set fake classname (By Zaurzo - A.R.C.)

function SEv.Ent:IsClassFake(ent)
    return ent:GetNWBool("sev_fake_class_name") and true
end

function SEv.Ent:SetFakeClass(ent, class)
    ent:SetNWString("sev_fake_class_name", class)
end

function SEv.Ent:GetRealClass(ent)
    return SEv_ENT_GetClass(ent)
end

ENT.GetClass = function(self)
    if SEv.Ent:IsClassFake(self) then return self:GetNWString("sev_fake_class_name") end
    return SEv_ENT_GetClass(self)
end

-- Hide information from HUDs and ent finders
-- See /instance/addon/entinfo

function SEv.Ent:IsInfoHidden(ent)
    if not IsValid(ent) then return false end
    return ent:GetNWBool("sev_cover_ent_name") and true
end

function SEv.Ent:HideInfo(ent, value)
    ent:SetNWBool("sev_cover_ent_name", value)
end

-- Conditional callback

function SEv.Ent:CallOnCondition(ent, condition, callback, ...)
    local name = tostring(ent)
    local args = { ... }

    timer.Create(name, 0.2, 0, function()
        if not ent:IsValid() then
            timer.Remove(name)
            return
        end

        if not condition() then return end

        timer.Remove(name)

        callback(unpack(args))
    end)
end

-- Reimplements *CGlobalEntityList::FindEntityNearestFacing
-- https://github.com/lua9520/source-engine-2018-hl2_src/blob/3bf9df6b2785fa6d951086978a3e66f49427166a/game/server/entitylist.cpp#L1043

function SEv.Ent:FindNearestFacing(origin, facing, threshold)
    local bestDot = threshold
    local bestEnt = nil

    for _, ent in ipairs(ents.GetAll()) do
        if not SEv_IsValid(ent) or ent:IsWorld() or ent:IsPlayer() or ent:IsWeapon() then
            continue
        end

        local toEnt = ent:WorldSpaceCenter() - origin
        toEnt:Normalize()

        local dot = facing:Dot(toEnt)

        if dot <= bestDot then
            continue
        end

        bestDot = dot
        bestEnt = ent
    end

    return bestEnt
end

function SEv.Ent:FindAllFacing(origin, facing, threshold)
    local foundEnts = {}

    for _, ent in ipairs(ents.GetAll()) do
        if not SEv_IsValid(ent) or ent:IsWorld() or ent:IsPlayer() or ent:IsWeapon() then
            continue
        end

        local toEnt = ent:WorldSpaceCenter() - origin
        toEnt:Normalize()

        local dot = facing:Dot(toEnt)

        if dot <= threshold then
            continue
        end

        table.insert(foundEnts, ent)
    end

    return foundEnts
end

-- Protect from ent_remove and ent_remove_all commands

--[[
    This is how ent_remove(_all) {argument} works:

    -- CC_Ent_Remove https://github.com/lua9520/source-engine-2018-hl2_src/blob/3bf9df6b2785fa6d951086978a3e66f49427166a/game/server/baseentity.cpp#L5041
        -- searchs for class if arg 1 is defined
        -- calls FindPickerEntity() if not https://github.com/lua9520/source-engine-2018-hl2_src/blob/3bf9df6b2785fa6d951086978a3e66f49427166a/game/server/player.cpp#L5776
            -- makes a TraceLine to MAX_COORD_RANGE (16384) in FindEntityForward https://github.com/lua9520/source-engine-2018-hl2_src/blob/3bf9df6b2785fa6d951086978a3e66f49427166a/game/server/player.cpp#L5738
            -- if it fails them FindEntityNearestFacing is called with 55 degrees view (0.96 rad) https://github.com/lua9520/source-engine-2018-hl2_src/blob/3bf9df6b2785fa6d951086978a3e66f49427166a/game/server/entitylist.cpp#L1043

            -- Note: Util_TraceLine: https://github.com/lua9520/source-engine-2018-hl2_src/blob/3bf9df6b2785fa6d951086978a3e66f49427166a/game/shared/util_shared.h#L249

    The entity protection only occur if there's a chance that the player is trying to execute these commands (Main menu + interactions).
    To make the trace ignore the protected entities I'm setting the collision bounds of the selected ones to an empty space.
    To make the {argument} (class name) useless I'm changing the protected entities classes to something else.
    To break "FindEntityNearestFacing" the new class for all the protected entities is "worldspawn".

    I'm using the same traces and scans as ent_remove, so the found entities should always be the same as the command. Well, I
    wish that were true... Even though everything looks right, I needed to add a third search to make the result more reliable.
    take a lookt at FindProtectedVictmins if feel like solving the mystery.

    Binding ent_remove(_all) is also blocked, as I'm denying the execution when the protected entities are the victims.

    I'd validate the command input directly instead of betting on chances if GMod provided a way for us to know what this input is when the
    player opens the console and when he types, but that's not the case.

    ~~~~ By Zaurzo and Xalalau. Zaurzo said: "we got the big boy out of the way".
]]

local function FindProtectedVictmins(ply)
    local foundEnts = {}

    local function IsValidVictmin(ent)
        return ent and SEv_IsValid(ent) and ent.GetNWBool and ent:GetNWBool("sev_block_remove_ent")
    end

    -- Find entities using util.TraceLine (MAX_COORD_RANGE = 16384) and FindAllFacing (threshold 0.96)
    local tr = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:EyeAngles():Forward() * 16384,
        filter = ply
    })

    if IsValidVictmin(tr.Entity) then
        table.insert(foundEnts, tr.Entity)
    end

    for k, ent in ipairs(SEv.Ent:FindAllFacing(ply:EyePos(), ply:EyeAngles():Forward(), 0.96)) do
        if IsValidVictmin(ent) and ent ~= tr.Entity then
            table.insert(foundEnts, ent)
        end
    end

    -- Extra scan to improve results. Delete it if you figure out why the searchs above are different from the ent_remove command.
    -- Finds near ents
    for k, ent in ipairs(ents.FindInCone(ply:GetShootPos(), ply:GetAimVector(), 1500, 0.86)) do -- 0.86 = 30º
        if IsValidVictmin(ent) and not table.HasValue(foundEnts, ent) then
            table.insert(foundEnts, ent)
        end
    end

    return foundEnts
end

if CLIENT then
    -- CreateMove works even in singleplayer with the game paused
    hook.Add("CreateMove", "sev_block_ent_remove", function(cmd)
        if gui.IsGameUIVisible() and not SEv.Ent.isMainMenuOpen then
            SEv.Ent.isMainMenuOpen = true
        elseif not gui.IsGameUIVisible() and SEv.Ent.isMainMenuOpen then
            net.Start("sev_protect_ent_remove")
            net.WriteBool(false)
            net.SendToServer()

            SEv.Ent.isMainMenuOpen = false
            SEv.Ent.alertedEntRemove = false
        end

        -- Protect the ents if the player tries to input ent_remove
            -- I should only do this protection if necessary, as changing classes can break the map!
        if SEv.Ent.isMainMenuOpen and not SEv.Ent.alertedEntRemove and (
           input.IsKeyDown(KEY_RSHIFT) or input.IsKeyDown(KEY_LSHIFT) or -- Shift (if he decides to type the command. Underscore he needs shift)
           input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL) or -- CTRL (if he tries to paste with CTRL + V)
           input.IsKeyDown(KEY_UP) or input.IsKeyDown(KEY_DOWN) or -- Arrows (if he tries to access the console history)
           input.IsKeyDown(KEY_BACKSPACE) or -- Backspace (if he closes the menu with the command there and opens it again, the last char must be deleted)
           LocalPlayer():GetNWBool("sev_right_click")) then -- Right Click (if he tries to paste with the context menu)
            net.Start("sev_protect_ent_remove")
            net.WriteBool(true)
            net.SendToServer()

            SEv.Ent.alertedEntRemove = true

            LocalPlayer():SetNWBool("sev_right_click", false) -- reset this 
        end
    end)

    -- Don't allow binding ent_remove
    hook.Add("PlayerBindPress", "sev_block_ent_remove_binds", function(ply, bind, pressed)
        if string.find(bind, "ent_remove") || string.find(bind, "ent_remove_all") then
            local foundEnts = FindProtectedVictmins(ply)

            if #foundEnts > 0 then
                return true
            end
        end
    end)
end

if SERVER then
    -- Send right clicks to the client
    local lastWasRightClick = true
    hook.Add("PlayerButtonDown", "sev_check_player_right_click", function( ply, button )
        if button == 108 then
            ply:SetNWBool("sev_right_click", true)
            lastWasRightClick = true
        elseif lastWasRightClick then
            ply:SetNWBool("sev_right_click", false)
        end
    end)

    -- Protect and unprotect our entities
    net.Receive("sev_protect_ent_remove", function(len, ply)
        local protect = net.ReadBool()

        for checkPly, state in pairs(SEv.Ent.blockingEntRemove) do
            if not checkPly:IsValid() then
                SEv.Ent.blockingEntRemove[checkPly] = nil
            end
        end

        if protect then
            if not SEv.Ent.blockingEntRemove[ply] then
                local foundEnts = FindProtectedVictmins(ply)

                for k, ent in ipairs(foundEnts) do
                    ent.sev_original_collision_bounds1, ent.sev_original_collision_bounds2 = ent:GetCollisionBounds()
                    ent:SetCollisionBounds(Vector(0, 0, 0), Vector(0, 0, 0))
                    ply.sev_saved_ents = ply.sev_saved_ents or {}
                    table.insert(ply.sev_saved_ents, ent)
                end

                if table.Count(SEv.Ent.blockingEntRemove) == 0 then
                    for k, ent in ipairs(ents.GetAll()) do
                        if ent.GetNWBool and ent:GetNWBool("sev_block_remove_ent") then
                            ent.sev_original_class = ent:GetClass()
                            ent:SetKeyValue("classname", "worldspawn")
                        end
                    end
                end

                SEv.Ent.blockingEntRemove[ply] = true
            end
        else
            if SEv.Ent.blockingEntRemove[ply] then
                SEv.Ent.blockingEntRemove[ply] = nil
            else
                return
            end

            if table.Count(SEv.Ent.blockingEntRemove) == 0 then
                for k, ent in ipairs(ents.GetAll()) do
                    if ent.sev_original_class then
                        ent:SetKeyValue("classname", ent.sev_original_class)
                        ent.sev_original_class = nil
                    end
                end
            end

            if ply.sev_saved_ents then
                for k, ent in ipairs(ply.sev_saved_ents) do
                    if SEv_IsValid(ent) then
                        ent:SetCollisionBounds(ent.sev_original_collision_bounds1, ent.sev_original_collision_bounds2)
                        ent.sev_original_collision_bounds1 = nil
                        ent.sev_original_collision_bounds2 = nil
                    end
                end

                ply.sev_saved_ents = nil
            end
        end
    end)
end

function SEv.Ent:BlockEntRemoveCvars(ent, value)
    ent:SetNWBool("sev_block_remove_ent", value)
end
