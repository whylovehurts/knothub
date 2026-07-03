--!nocheck
--[[
    KnotHub Loader — Universal Game Router
    ───────────────────────────────────────
    Detects the current game by PlaceId and loads the correct script from GitHub.
    Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/whylovehurts/knothub/refs/heads/main/loader.lua"))()
--]]

local BASE_URL = "https://raw.githubusercontent.com/whylovehurts/knothub/refs/heads/main/"

local GAMES = {
    [130247632398296] = "Anime Fighting (130247632398296)",
    [99383863544987]  = "Anime Limitless (99383863544987)",
}

local placeId = game.PlaceId
local gamePath = GAMES[placeId]

if gamePath then
    print("[KnotHub] Detected: " .. gamePath .. " (PlaceId: " .. tostring(placeId) .. ")")
    local url = BASE_URL .. gamePath:gsub(" ", "%%20") .. "/main.lua"
    local success, err = pcall(function()
        loadstring(game:HttpGet(url))()
    end)
    if not success then
        warn("[KnotHub] Failed to load script for " .. gamePath .. ": " .. tostring(err))
    end
else
    warn("[KnotHub] Unsupported game! PlaceId: " .. tostring(placeId))
    warn("[KnotHub] Supported games:")
    for id, name in pairs(GAMES) do
        warn("  • " .. name .. " (" .. tostring(id) .. ")")
    end
end
