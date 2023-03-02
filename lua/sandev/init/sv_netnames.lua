--[[
    https://wiki.facepunch.com/gmod/Calling_net.Start_with_unpooled_message_name
    "Ideally you'd do this when your Lua files are being loaded - but where that's not
    possible you need to do it at least a couple of seconds before calling the message
    to be sure that it'll work."

    That's why I'm joining the AddNetworkString here. People with VERY slow computers
    have had severe problems with unpooled messages even with me doing extra checks.
]]

-- Addons
util.AddNetworkString("sev_curse_vc_fireplace")

util.AddNetworkString("sev_set_spys_night_vision")
util.AddNetworkString("sev_set_arctics_night_vision")
util.AddNetworkString("sev_drop_night_vision_goggles")
util.AddNetworkString("sev_drop_night_vision_goggles_inspired")

-- Ents
util.AddNetworkString("sev_protect_ent_remove")

-- Effects
util.AddNetworkString("sev_create_sparks")
util.AddNetworkString("sev_create_smoke_stream")
util.AddNetworkString("sev_create_ring_explosion")

-- Portals
util.AddNetworkString("SEv_PORTALS_FREEZE")

-- Nodraw trigger
util.AddNetworkString("sev_trigger_nodraw_add_area")
util.AddNetworkString("sev_trigger_nodraw_remove_area")
util.AddNetworkString("sev_trigger_nodraw_toggle_area")
util.AddNetworkString("sev_trigger_nodraw_add_ent")
util.AddNetworkString("sev_trigger_nodraw_remove_ent")

-- Lobby
util.AddNetworkString("sev_lobby_debug_text")

-- Networking
util.AddNetworkString("sev_net_send_string")

-- Instance only libs
function SEv:AddInstanceNets(instance)
    -- Events
    util.AddNetworkString(instance.id .. "_event_set_render_cl")
    util.AddNetworkString(instance.id .. "_event_Remove_render_cl")
    util.AddNetworkString(instance.id .. "_event_send_all_render_cl")
    util.AddNetworkString(instance.id .. "_event_request_all_render_sv")
    util.AddNetworkString(instance.id .. "_event_remove_all_cl")
    util.AddNetworkString(instance.id .. "_event_remove_all_ents_cl")
    util.AddNetworkString(instance.id .. "_event_remove_cl")
    util.AddNetworkString(instance.id .. "_event_initialize_tier_cl")

    -- Memories
    util.AddNetworkString(instance.id .. "_broadcast_memory")
    util.AddNetworkString(instance.id .. "_broadcast_memories")
    util.AddNetworkString(instance.id .. "_ask_for_memories")
    util.AddNetworkString(instance.id .. "_clear_memories")
    util.AddNetworkString(instance.id .. "_set_per_player_memory_sv")
    util.AddNetworkString(instance.id .. "_set_per_player_memory_cl")

    -- DevMode
    util.AddNetworkString(instance.id .. "_toggle_devmode")
end

-- SEv Devmode
util.AddNetworkString(SEv.id .. "_toggle_devmode")

-- Net
util.AddNetworkString("sev_cheap")