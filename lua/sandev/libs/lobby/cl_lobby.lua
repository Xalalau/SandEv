net.Receive("sev_lobby_debug_text", function(_, ply)
    local message = net.ReadString()
    chat.AddText(Color(255, 87, 51), message)
end)
