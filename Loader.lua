-- ╔═══════════════════════════════════════════════════════════╗
-- ║  ✦ HIYORI ON TOP ✦ — LOADER                             ║
-- ║  Edit the _G config below, then execute this script.     ║
-- ║  The main script auto-updates from GitHub every 15 min.  ║
-- ╚═══════════════════════════════════════════════════════════╝

-- ┌─────────────────────────────────────────────────────────┐
-- │  YOUR CONFIGURATION (edit these before executing)       │
-- └─────────────────────────────────────────────────────────┘

_G.MutationBrainrot = { "Money", "UFO", "Gold", "Emerald" }  -- mutations your brainrot can get
_G.BrainrotName     = "Your Brainrot Name"                    -- brainrot to fuse
_G.WebhookLink      = "YOUR_DISCORD_WEBHOOK_URL"              -- discord webhook for tracking

-- ┌─────────────────────────────────────────────────────────┐
-- │  LUARMOR AUTH (your unique script key)                   │
-- └─────────────────────────────────────────────────────────┘

script_key = "YOUR_SCRIPT_KEY"
loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/afea565efebb00ff071956e6553a9702.lua"))()
