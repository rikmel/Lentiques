# ✦ Hiyori On Top ✦ — Auto Fuse & Money Machine

> Automatic brainrot fusing, money collection, and dupe tracking for Tsunami.

## 🚀 Quick Start

1. **Get your script key** from Luarmor
2. **Copy the loader below** into your executor
3. **Edit the `_G` config** with your settings
4. **Execute!**

```lua
-- ┌─────────────────────────────────────────────────────────┐
-- │  YOUR CONFIGURATION (edit these before executing)       │
-- └─────────────────────────────────────────────────────────┘

_G.MutationBrainrot = { "Money", "UFO", "Gold", "Emerald" }
_G.BrainrotName     = "Your Brainrot Name"
_G.WebhookLink      = "YOUR_DISCORD_WEBHOOK_URL"

-- ┌─────────────────────────────────────────────────────────┐
-- │  LUARMOR AUTH (your unique key)                         │
-- └─────────────────────────────────────────────────────────┘

script_key = "YOUR_SCRIPT_KEY"
loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/afea565efebb00ff071956e6553a9702.lua"))()
```

## 🔄 Auto-Update

The script **automatically checks for updates every 15 minutes**. When a new version is detected:
- A webhook notification is sent to your Discord
- The current script shuts down cleanly
- The new version is fetched and re-executed
- Your `_G` config is preserved — no action needed!

## ⚙️ Configuration

| Variable | Type | Description |
|----------|------|-------------|
| `_G.MutationBrainrot` | `table` | List of mutations your brainrot can get after fusing |
| `_G.BrainrotName` | `string` | Name of the brainrot you want to fuse |
| `_G.WebhookLink` | `string` | Discord webhook URL for dupe notifications |

## 📋 Features

- **Auto Fuse Mode** — Detects active maps and automatically fuses brainrots
- **Money Mode** — Collects money while waiting for maps
- **Dupe Detection** — Peak tracking system that detects new duplicates
- **Discord Webhooks** — Rich embeds with session stats, inventory breakdown, speed, and map info
- **Speed Upgrade** — Automatically upgrades speed to 400 on startup
- **Luck Timer** — Waits for max luck before entering fuse mode
- **Tsunami Protection** — Builds walls and retreats during waves
- **Auto-Update** — Checks GitHub every 15 minutes for new versions

## 📦 Version

Current: **v5.0**
