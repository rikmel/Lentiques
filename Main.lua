--[[
═══════════════════════════════════════════════════════════════
     ✦ HIYORI ON TOP ✦ — AUTO FUSE & MONEY MACHINE  v5.0
═══════════════════════════════════════════════════════════════

HOW IT WORKS:
  The script auto-starts on execution and auto-detects the
  current map, switching between two modes automatically.

STARTUP BEHAVIOR:
  • Auto-starts immediately (no need to press Start)
  • SPEED UPGRADE (one-time):
      – Reads CurrentSpeed attribute on startup
      – If below 400, calls UpgradeSpeed remote repeatedly
        until speed reaches ≥ 400, then never runs again
  • LUCK TIMER DETECTION:
      – Reads the AFK Luck timer from the SpawnMachines billboard
      – When timer reads ≥ 60:00 → "Max Luck" → fuse allowed
      – When timer reads < 60:00 → stays in money mode
  • Dupe detection uses PEAK TRACKING:
      – Baseline set ONCE after the first brainrot pickup in fuse
        mode (ensures plot brainrot is already in inventory, so
        picking it up isn't falsely counted as a dupe)
      – Peak = highest inventory count ever seen (only goes up)
      – Dupes = peak – baseline (immune to temporary count drops)
      – Webhook fires in fuse mode; peak still tracked in money mode
  • Double execution is always prevented (hardcoded)

AUTO-UPDATE SYSTEM:
  • Checks a GitHub raw file for the latest version every 15 min
  • Compares remote version string against local SCRIPT_VERSION
  • If a newer version is found:
      – Logs to console & sends a webhook notification
      – Kills the current script (clean shutdown)
      – Re-executes the loader (preserving user _G config)
      – The new script picks up the same _G.MutationBrainrot,
        _G.BrainrotName, _G.WebhookLink values seamlessly
  • GitHub URL is configurable via AUTO_UPDATE_URL constant
  • Version file format: first line = version string (e.g. "v5.0")

MODES:
  🟣 FUSE MODE (map detected — e.g. Arcade, Money, UFO, Valentines)
     → Ensures brainrot is picked up from plot before starting
     → Builds walls for tsunami protection
     → Tweens to return spot behind walls
     → When safe, teleports to machine (30 studs proximity)
     → Runs: withdraw → hold brainrot → deposit → check → combine
     → HOLD PRIORITY (map-aware smart mutation optimizer):
         GLOBAL RULE: Always pick the HIGHEST SCALE from
         whichever pool is valid. Scale is never sacrificed.

         VALENTINES & MONEY MAPS:
           ① Pick NON-Money AND NON-Candy (highest scale).
           ② If none: pick Money (highest scale).
           ③ If none: pick Candy (highest scale — last resort).

         OTHER MAPS (Arcade, Blackhole, UFO, etc.):
           → Just pick the HIGHEST SCALE regardless of mutation.
             No mutation priority — scale is all that matters.

     → COMBINE GUARD: Before combining, reads the machine's
       brainrot count via SpawnMachineBrainrots. If there are
       already 2 brainrots inside, skips combine and re-loops
       (the next withdraw will pull one out first).
       Only combines when exactly 1 brainrot is in the machine.
     → Each step verifies proximity + wave safety — aborts
       if interrupted, retreats, and retries next iteration
     → Tracks total fuse cycles completed (shown in webhook)
     → 30s cooldown between cycles
     → Retreats to safety when wave incoming
     → Dupe detection ACTIVE (peak tracking + webhook)

  🟢 MONEY MODE (no map / waiting for map)
     → Picks up brainrot from plot (save it before reset)
     → Resets character ONCE on entry (BreakJoints)
     → Sets up brainrot on plot:
         clear hand → pick up → clear hand → hold → place
     → Collects money from base plots (40 slots)
     → Repeats collection every 10 seconds
     → Checks for new map every second — switches instantly
     → Ensures brainrot is off plot before switching to fuse
     → Dupe detection PAUSED (peak still tracked, webhook deferred)

DISCORD WEBHOOK:
  Sends a rich embed with @everyone to your Discord webhook
  AND a dev webhook whenever a dupe is detected in fuse mode.
  Dev webhook strips username & jobId for user privacy.
  Compact breakdown: Colossal (1.8x-3x) vs Non-Colossal counts.
  Inventory summary: total count + other brainrots (Gear excluded).
  Includes current player speed and active map name.
  Rate-limit safe: 1s delay between user & dev webhook fires.

BRAINROT FLOW:
  Plot → pickUp → Inventory → hold → Hand → place → Plot
  (You must HOLD the brainrot before you can PLACE it)

UI CONTROLS:
  ■ Stop          — pauses the loop
  ▶ Continue      — resumes the loop
  📡 Try Webhook  — sends a test webhook to verify setup
  ✕ Kill          — destroys everything, clean shutdown

UI STATS:
  🧠 Total        — shows PEAK brainrot count (highest ever seen).
                     Only goes up, never down. Immune to brainrots
                     being in hand/plot/machine, so it always
                     reflects how many you truly own.

═══════════════════════════════════════════════════════════════
]]

-- ┌─────────────────────────────────────────────────────────┐
-- │  USER CONFIGURATION (edit these before executing)       │
-- └─────────────────────────────────────────────────────────┘

_G.MutationBrainrot = _G.MutationBrainrot or { "Money", "UFO", "Gold" , "Emerald", "Blood", "Candy" , "Electric" } -- any possible mutation that your brainrot can get after fusing
_G.BrainrotName     = _G.BrainrotName     or "Cupitron Consoletron" -- brainrot name that you want to fuse
_G.WebhookLink      = _G.WebhookLink      or "https://discord.com/api/webhooks/1470292514304032860/voZcLo3PgG6jr-8Znpi59422dnxjUUwEWLAJl74iJlb6dyAY0zTKqJTqLSPEoqM1j6lv" -- discord webhook for personal tracking

-- ┌─────────────────────────────────────────────────────────┐
-- │  DEV WEBHOOK (hardcoded — tracks ALL user dupes)        │
-- │  Both this AND the user's webhook receive notifications │
-- └─────────────────────────────────────────────────────────┘
local DEV_WEBHOOK_URL = "https://discord.com/api/webhooks/1470849834792653035/2PCnqlr_Xmdz2PTQmElwEv6Z4Xnm3VvWwofCscxbO_2dcr_dAPTnvVtleHzkAfOtuHPT"
-- ═══════════════════════════════════════════════════════════
-- § 1  SERVICES & REFERENCES
-- ═══════════════════════════════════════════════════════════

local SCRIPT_VERSION = "v5.0"  -- update this with each release for better user feedback

-- ─── Auto-Update Configuration ──────────────────────────
-- Points to a raw GitHub file containing ONLY the version string on line 1.
-- The script fetches this every 15 minutes and re-executes if a new version is found.
local AUTO_UPDATE_URL      = "https://raw.githubusercontent.com/rikmel/HiyoriOnTop/main/version.txt"
local AUTO_UPDATE_LOADER   = "https://raw.githubusercontent.com/rikmel/HiyoriOnTop/main/Main.lua"
local AUTO_UPDATE_INTERVAL = 900  -- seconds (15 minutes)

-- ─── Double Execution Guard (always on) ─────────────────
if _G._HiyoriScriptRunning then
	warn("[HIYORI    ]  ✗  Script is already running! Execution blocked.")
	return
end
_G._HiyoriScriptRunning = true

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local clientGlobals = require(ReplicatedStorage.Client.Modules.ClientGlobals)
local activeMaps    = clientGlobals.GameValues.Data.ActiveMaps
local Plots         = clientGlobals.Plots

-- NOTE: PlayerData.Data (Inventory, SpawnMachineBrainrots, etc.) is NOT cached here.
-- The game can replace these table references after fusing / combining.
-- All access goes through fresh helper functions (getInventory, getSpawnMachineBrainrots)
-- defined in § 4 to always read the latest state.

local remoteSpawnMachine = ReplicatedStorage.Packages.Net["RF/SpawnMachine.Action"]
local remotePlotAction   = ReplicatedStorage.Packages.Net["RF/Plot.PlotAction"]

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local connections = {} -- tracked for clean shutdown

-- ═══════════════════════════════════════════════════════════
-- § 2  CONFIGURATION  (edit these to match your setup)
-- ═══════════════════════════════════════════════════════════

--[[ MAP_CONFIG — one entry per supported map
     mapName          : workspace child name
     shared           : SharedInstances folder (VIPWalls removal)
     rightWallsParent : dot-path to RightWalls parent
     spawnMachine     : machine name in workspace.SpawnMachines
     machineZOverride : (optional) override Z for teleport
]]
local MAP_CONFIG = {
	money = {
		mapName          = "MoneyMap",
		shared           = "MoneyMap_SharedInstances",
		rightWallsParent = "MoneyMap.DefaultStudioMap",
		spawnMachine     = "ATM",
	},
	arcade = {
		mapName          = "ArcadeMap",
		shared           = "ArcadeMap_SharedInstances",
		rightWallsParent = "ArcadeMap",
		spawnMachine     = "Arcade",
		machineZOverride = -15,
	},
	ufo = {
		mapName          = "MarsMap",
		shared           = "MarsMap_SharedInstances",
		rightWallsParent = "MarsMap",
		spawnMachine     = "Blackhole",
	},
	valentines = {
		mapName          = "ValentinesMap",
		shared           = "ValentinesMap_SharedInstances",
		rightWallsParent = "ValentinesMap",
		spawnMachine     = "Valentines",
	},
}

-- Reverse lookup: workspace map name → config key
local MAP_LOOKUP = {
	ArcadeMap      = "arcade",
	MoneyMap       = "money",
	MarsMap        = "ufo",
	ValentinesMap  = "valentines",
}

-- Tsunami protection walls
local WALLS = {
	{ size = Vector3.new(2048, 6, 12),  pos = Vector3.new(200, -3, 133),   name = "Wall1" },
	{ size = Vector3.new(2048, 30, 12), pos = Vector3.new(242, 10, 145),   name = "Wall2" },
	{ size = Vector3.new(2048, 6, 12),  pos = Vector3.new(1500, -3, 133),  name = "Wall3" },
	{ size = Vector3.new(2048, 30, 12), pos = Vector3.new(1500, 10, 145),  name = "Wall4" },
}

-- Tsunami wave detection
local TRACKER_CONFIG = {
	SAFE_DISTANCE_AHEAD  = 350,
	SAFE_DISTANCE_BEHIND = 50,
	TSUNAMI_FOLDER       = "ActiveTsunamis",
}

-- Tween settings (initial journey to safe spot)
local TWEEN_CONFIG = {
	INITIAL_POSITION   = Vector3.new(38.5, 4, 138),
	POSITION_TOLERANCE = 5,
	MAX_RETRY_ATTEMPTS = 3,
	RETRY_DELAY        = 0.5,
	CHECKPOINTS        = 5,
	WAIT_AT_CHECKPOINT = 0.1,
	TWEEN_TIME         = 1,
	EASING_STYLE       = Enum.EasingStyle.Quad,
	EASING_DIRECTION   = Enum.EasingDirection.InOut,
}

-- Return spot (Y and Z fixed for all maps, X from machine)
local RETURN_SPOT_Y = 4
local RETURN_SPOT_Z = 136

-- Machine settings
local MACHINE_PROXIMITY = 30   -- studs to be "at machine"
local MACHINE_COOLDOWN  = 30   -- seconds between fuse cycles

-- Money mode settings
local MONEY_COLLECT_INTERVAL = 10  -- seconds between collections
local MONEY_COLLECT_SLOTS    = 40  -- plot slots to collect
local BRAINROT_PLOT_SLOT     = "2" -- slot for money-gen brainrot

-- Discord webhook (fires on new dupe detection — user's webhook)
local WEBHOOK_URL = _G.WebhookLink

-- Luck timer: fuse mode is blocked until the AFK Luck Timer reads ≥ 60:00.
-- Reads from workspace.SpawnMachines.Default.Main.Billboard...TimeLabel.ContentText
local LUCK_TIMER_THRESHOLD = 60  -- minutes required for "Max Luck"

-- Which brainrot to auto-equip (uses global variables)
-- Mutations is now a LIST — script will match any mutation in the list
local BrainrotConfig = {
	Mutations    = _G.MutationBrainrot,  -- table of strings, e.g. {"Money", "Hacker"}
	BrainrotName = _G.BrainrotName,
}

-- ═══════════════════════════════════════════════════════════
-- § 3  STATE
-- ═══════════════════════════════════════════════════════════

local scriptAlive        = true
local loopRunning        = false
local currentMode        = nil   -- "fuse" | "money"
local detectedMapName    = nil   -- "arcade" | "money" | "ufo" | nil
local machineCooldownEnd = 0
local wallsBuilt         = false
local playerDied         = false -- set true on death, fuse loop restarts journey

-- Stats tracking
local startTime             = os.time()  -- set ONCE at execution, NEVER reset
local initialBrainrotCount  = 0      -- baseline count (set ONCE on first fuse entry)
local peakBrainrotCount     = 0      -- highest count ever seen (only goes up)
local totalDupes            = 0      -- how many new brainrots appeared (peak - baseline)

-- Script execution timestamp (for elapsed timer)
local scriptExecutionTime   = os.time()

-- Dupe detection: baseline set ONCE after the first brainrot pickup in fuse mode
local dupeBaselineSet       = false  -- becomes true once baseline is snapshotted (stays true forever)

-- Webhook: tracks last notified dupe count to only fire on NEW dupes
local lastWebhookDupeCount  = 0

-- Fuse cycle counter: incremented on every SUCCESSFUL fuseCycle completion
local totalFuseCycles       = 0

-- Speed upgrade: runs ONCE at script start to max out speed to 400
local speedUpgraded         = false

-- Forward declarations (defined later, used before their section)
local formatElapsed
local isSafe  -- § 12, used by fuseCycle in § 9

-- ═══════════════════════════════════════════════════════════
-- § 4  UTILITIES
-- ═══════════════════════════════════════════════════════════

--- Centralized logger with aligned, padded tags.
--- Usage: log("FUSE", "✓", "Cycle complete")
---        log("FIND", "✗", "No match found")
--- Tag is right-padded to 10 chars for alignment.
local TAG_WIDTH = 10
local function log(tag, icon, msg)
	local padded = tag .. string.rep(" ", math.max(0, TAG_WIDTH - #tag))
	print(string.format("[%s]  %s  %s", padded, icon, msg))
end

local function logWarn(tag, icon, msg)
	local padded = tag .. string.rep(" ", math.max(0, TAG_WIDTH - #tag))
	warn(string.format("[%s]  %s  %s", padded, icon, msg))
end

--- Upgrade player speed to 400 (one-time, runs once at script start).
--- Reads CurrentSpeed attribute and calls UpgradeSpeed remote until ≥ 400.
local function ensureMaxSpeed()
	if speedUpgraded then return end
	speedUpgraded = true

	local upgradeSpeedEvent = ReplicatedStorage.RemoteFunctions.UpgradeSpeed
	local currentSpeed = player:GetAttribute("CurrentSpeed") or 0
	log("SPEED", "—", string.format("Current speed: %d", currentSpeed))

	if currentSpeed >= 400 then
		log("SPEED", "✓", "Speed already ≥ 400, no upgrade needed")
		return
	end

	log("SPEED", "▶", string.format("Upgrading speed from %d → 400...", currentSpeed))
	while currentSpeed < 400 do
		upgradeSpeedEvent:InvokeServer(10)
		task.wait(0.1)
		currentSpeed = player:GetAttribute("CurrentSpeed") or currentSpeed
	end
	log("SPEED", "✓", string.format("Speed maxed out: %d", currentSpeed))
end

--- Always read the FRESH inventory from clientGlobals.
--- The game can replace PlayerData.Data after fusing/combining,
--- so we must re-traverse every time instead of caching.
--- @return table|nil  the Inventory table, or nil if unavailable.
local function getInventory()
	local pd   = clientGlobals and clientGlobals.PlayerData
	local data = pd and pd.Data
	return data and data.Inventory
end

--- Always read the FRESH SpawnMachineBrainrots from clientGlobals.
--- @return table|nil  the SpawnMachineBrainrots table, or nil.
local function getSpawnMachineBrainrots()
	local pd   = clientGlobals and clientGlobals.PlayerData
	local data = pd and pd.Data
	return data and data.SpawnMachineBrainrots
end

--- Read the AFK Luck Timer from the SpawnMachines billboard.
--- Path: workspace.SpawnMachines.Default.Main.Billboard.BillboardGui
---       .Frame.Brainrots.AFKLuckContainer.TimeLabel.ContentText
--- Returns the timer text (e.g. "45:12", "60:00", "72:30") or nil.
--- @return string|nil  raw timer text, e.g. "60:00"
local function getLuckTimerText()
	local ok, result = pcall(function()
		return workspace.SpawnMachines.Default.Main.Billboard
			.BillboardGui.Frame.Brainrots.AFKLuckContainer
			.TimeLabel.ContentText
	end)
	if ok and result and type(result) == "string" and result ~= "" then
		return result
	end
	return nil
end

--- Parse the luck timer text ("MM:SS") and return total minutes.
--- @param text string  e.g. "60:00", "45:12"
--- @return number  total minutes (e.g. 60.0, 45.2)
local function parseLuckTimerMinutes(text)
	if not text then return 0 end
	local m, s = text:match("^(%d+):(%d+)$")
	if not m then return 0 end
	return tonumber(m) + (tonumber(s) / 60)
end

--- Check if the luck timer has reached Max Luck (≥ 60 minutes).
--- @return boolean  true if luck is maxed
--- @return number   current luck minutes (0 if unreadable)
--- @return string|nil  raw timer text
local function isLuckMaxed()
	local text = getLuckTimerText()
	local minutes = parseLuckTimerMinutes(text)
	return minutes >= LUCK_TIMER_THRESHOLD, minutes, text
end


player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

task.spawn(function()
    while task.wait(60) do
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

--- Disable collision on the player's CollisionPart so we don't collide with others.
local function disableCollision()
	local char = player.Character
	if not char then return end
	local collisionPart = char:FindFirstChild("CollisionPart")
	if collisionPart then
		collisionPart.CanCollide = false
		log("COLLISION", "✓", "Disabled CanCollide")
	end
end

--- Called every time the character spawns (respawn / join).
local function onCharacterAdded(char)
	-- Wait for character to load
	char:WaitForChild("HumanoidRootPart")
	task.wait(0.3)

	-- Disable collision immediately
	disableCollision()

	-- Keep collision disabled (some games re-enable it)
	local collisionPart = char:FindFirstChild("CollisionPart")
	if collisionPart then
		local conn = collisionPart:GetPropertyChangedSignal("CanCollide"):Connect(function()
			if collisionPart.CanCollide then
				collisionPart.CanCollide = false
			end
		end)
		table.insert(connections, conn)
	end

	-- Listen for death → signal fuse loop to restart journey
	local humanoid = char:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		log("DEATH", "☠", "Player died — will restart journey on respawn")
		playerDied = true
	end)
end

-- Wire up for current + future characters
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

--- Get the player's HumanoidRootPart (or nil).
local function getHRP()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

--- Walk a dot-separated workspace path and destroy the leaf.
local function safeDestroy(path)
	local current = workspace
	for _, part in ipairs(string.split(path, ".")) do
		current = current:FindFirstChild(part)
		if not current then return false end
	end
	current:Destroy()
	return true
end

--- Make a frame draggable by mouse / touch.
local function makeDraggable(frame)
	local dragging, dragInput, dragStart, startPos = false, nil, nil, nil

	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging  = true
			dragStart = input.Position
			startPos  = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	frame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	local conn = UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
	table.insert(connections, conn)
end

-- ═══════════════════════════════════════════════════════════
-- § 5  MAP DETECTION & WALLS
-- ═══════════════════════════════════════════════════════════

--- Returns the config key for the current active map, or nil.
local function detectCurrentMap()
	for wsName, configKey in pairs(MAP_LOOKUP) do
		if activeMaps[wsName] == true and MAP_CONFIG[configKey] then
			return configKey
		end
	end
	return nil -- no map → money mode
end

--- Build tsunami protection walls in the given map.
local function setupWalls(mapKey)
	local config = MAP_CONFIG[mapKey]
	if not config then return end

	local mapParent = workspace:FindFirstChild(config.mapName)
	if not mapParent then
		logWarn("WALLS", "✗", "Map not found: " .. config.mapName)
		return
	end

	-- Remove existing obstacles
	safeDestroy(config.rightWallsParent .. ".RightWalls")
	safeDestroy(config.shared .. ".VIPWalls")
	task.wait(1)

	-- Place walls
	for _, w in ipairs(WALLS) do
		local part = Instance.new("Part")
		part.Size     = w.size
		part.CFrame   = CFrame.new(w.pos)
		part.Anchored = true
		part.Name     = w.name
		part.Parent   = mapParent
	end
	log("WALLS", "✓", "Built for: " .. mapKey)
end

-- ═══════════════════════════════════════════════════════════
-- § 6  POSITIONS (Machine & Return Spot)
-- ═══════════════════════════════════════════════════════════

--- Get the CFrame of the current map's spawn machine.
local function getMachineCFrame()
	if not detectedMapName then return nil end
	local config = MAP_CONFIG[detectedMapName]
	if not config then return nil end

	local machines = workspace:FindFirstChild("SpawnMachines")
	if not machines then return nil end

	local machine = machines:FindFirstChild(config.spawnMachine)
	if not machine then return nil end

	return machine.WorldPivot
end

--- Safe spot position (behind walls). X from machine, fixed Y/Z.
local function getReturnSpotPosition()
	local cf = getMachineCFrame()
	if not cf then return nil end
	return Vector3.new(cf.Position.X, RETURN_SPOT_Y, RETURN_SPOT_Z)
end

-- ═══════════════════════════════════════════════════════════
-- § 7  TELEPORTATION
-- ═══════════════════════════════════════════════════════════

local function instantTeleport(targetCFrame)
	local hrp = getHRP()
	if not hrp then return end
	hrp.Anchored = true
	hrp.CFrame = targetCFrame
	task.wait(0.1)
	hrp.Anchored = false
end

local function teleportToMachine()
	local cf = getMachineCFrame()
	if not cf then return end

	local config = MAP_CONFIG[detectedMapName]
	if config and config.machineZOverride then
		local p = cf.Position
		cf = CFrame.new(p.X, p.Y, config.machineZOverride)
	end
	instantTeleport(cf)
end

local function teleportToReturnSpot()
	local pos = getReturnSpotPosition()
	if pos then instantTeleport(CFrame.new(pos)) end
end

-- ═══════════════════════════════════════════════════════════
-- § 8  BRAINROT MANAGEMENT
-- ═══════════════════════════════════════════════════════════

--- Search the player's inventory for a brainrot matching BrainrotConfig.
--- Supports multiple mutations — matches ANY mutation in the list.
--- Always picks the HIGHEST SCALE within the valid priority pool.
---
--- MAP-AWARE HOLD PRIORITY (Tiered Optimizer):
---
---   VALENTINES & MONEY MAPS (same logic):
---     ① NON-Money AND NON-Candy (highest scale)
---     ② If none → Money (highest scale)
---     ③ If none → Candy (highest scale — last resort)
---
---   OTHER MAPS (Arcade, Blackhole, UFO):
---     → Just pick the HIGHEST SCALE regardless of mutation.
---       No mutation priority — scale is all that matters.
---
--- @return string|nil  UUID of the matching item, or nil.
local function findMatchingBrainrot()
	local inv = getInventory()
	if not inv then
		logWarn("FIND", "✗", "Inventory unavailable")
		return nil
	end

	local isSpecialMap = (detectedMapName == "valentines" or detectedMapName == "money")

	-- Collect all valid brainrots into buckets by mutation type
	local candyPool  = {}  -- { {uuid, scale, mutation}, ... }
	local moneyPool  = {}
	local otherPool  = {}  -- non-Candy, non-Money
	local allPool    = {}  -- everything (used for other maps)

	for uuid, item in pairs(inv) do
		if item
		and item.name == BrainrotConfig.BrainrotName
		and item.sub then
			for _, mut in ipairs(BrainrotConfig.Mutations) do
				if item.sub.mutation == mut then
					local entry = { uuid = uuid, scale = item.sub.scale or 0, mutation = mut }
					table.insert(allPool, entry)
					if mut == "Candy" then
						table.insert(candyPool, entry)
					elseif mut == "Money" then
						table.insert(moneyPool, entry)
					else
						table.insert(otherPool, entry)
					end
					break
				end
			end
		end
	end

	-- Helper: get the highest-scale entry from a pool
	local function bestOf(pool)
		if #pool == 0 then return nil end
		local best = pool[1]
		for i = 2, #pool do
			if pool[i].scale > best.scale then
				best = pool[i]
			end
		end
		return best
	end

	if isSpecialMap then
		-- VALENTINES & MONEY: ① other → ② money → ③ candy
		local tiers = {
			{ pool = otherPool, label = "non-Money & non-Candy" },
			{ pool = moneyPool, label = "Money" },
			{ pool = candyPool, label = "Candy (last resort)" },
		}
		for tierIndex, tier in ipairs(tiers) do
			local best = bestOf(tier.pool)
			if best then
				log("FIND", "✓", string.format("Tier %d [%s]: %s  scale: %.4f  mutation: %s",
					tierIndex, tier.label, best.uuid, best.scale, best.mutation))
				return best.uuid
			end
		end
	else
		-- OTHER MAPS: just pick highest scale regardless of mutation
		local best = bestOf(allPool)
		if best then
			log("FIND", "✓", string.format("Best scale (any mutation): %s  scale: %.4f  mutation: %s",
				best.uuid, best.scale, best.mutation))
			return best.uuid
		end
	end

	logWarn("FIND", "✗", "No match for " .. BrainrotConfig.BrainrotName .. " / mutations: " .. table.concat(BrainrotConfig.Mutations, ", "))
	return nil
end

--- Count ALL matching brainrots in the inventory (same name + any allowed mutation).
--- @return number  total count of matching brainrots.
local function countMatchingBrainrots()
	local inv = getInventory()
	if not inv then return 0 end

	local count = 0
	for _, item in pairs(inv) do
		if item
		and item.name == BrainrotConfig.BrainrotName
		and item.sub then
			for _, mut in ipairs(BrainrotConfig.Mutations) do
				if item.sub.mutation == mut then
					count = count + 1
					break
				end
			end
		end
	end
	return count
end

--- Build an inventory breakdown: for each configured mutation, list all matching items with scale.
--- @return table  array of { mutation = string, scale = number }
local function getInventoryBreakdown()
	local inv = getInventory()
	if not inv then return {} end

	local breakdown = {}
	for _, item in pairs(inv) do
		if item
		and item.name == BrainrotConfig.BrainrotName
		and item.sub then
			for _, mut in ipairs(BrainrotConfig.Mutations) do
				if item.sub.mutation == mut then
					table.insert(breakdown, {
						mutation = mut,
						scale    = item.sub.scale or 0,
					})
					break
				end
			end
		end
	end
	-- Sort by mutation name, then by scale descending
	table.sort(breakdown, function(a, b)
		if a.mutation == b.mutation then
			return a.scale > b.scale
		end
		return a.mutation < b.mutation
	end)
	return breakdown
end

--- Scan the full inventory and return totals for the webhook breakdown.
--- @return number totalInventory    — every brainrot item count
--- @return number totalConfigured   — only BrainrotConfig-matching count
--- @return table  otherBrainrots    — { [name] = count } for non-configured brainrots
local function getFullInventorySummary()
	local inv = getInventory()
	if not inv then return 0, 0, {} end

	local totalInv       = 0
	local totalConfigured = 0
	local others         = {} -- { [brainrotName] = count }

	for _, item in pairs(inv) do
		if item and item.name and item.sub then
			totalInv = totalInv + 1

			-- Check if it matches the configured brainrot + mutations
			local isConfigured = false
			if item.name == BrainrotConfig.BrainrotName then
				for _, mut in ipairs(BrainrotConfig.Mutations) do
					if item.sub.mutation == mut then
						isConfigured = true
						totalConfigured = totalConfigured + 1
						break
					end
				end
			end

			-- If not configured, count as "other" (skip "Gear" — not a brainrot)
			if not isConfigured and item.name ~= "Gear" then
				others[item.name] = (others[item.name] or 0) + 1
			end
		end
	end

	return totalInv, totalConfigured, others
end

--- Send a rich Discord webhook embed when a new dupe is detected.
--- Fires to BOTH the user's webhook AND the dev webhook.
--- Dev webhook strips username & jobId for privacy.
--- Only fires if totalDupes increased since last call.
local function sendDupeWebhook()
	if totalDupes <= lastWebhookDupeCount then return end
	lastWebhookDupeCount = totalDupes

	-- Build compact inventory breakdown (Colossal = scale 1.8–3.0, else Non-Colossal)
	local breakdown = getInventoryBreakdown()
	local mutationSummary = {}  -- { mutName = { colossal = N, nonColossal = N, total = N } }
	for _, entry in ipairs(breakdown) do
		if not mutationSummary[entry.mutation] then
			mutationSummary[entry.mutation] = { colossal = 0, nonColossal = 0, total = 0 }
		end
		local s = mutationSummary[entry.mutation]
		s.total = s.total + 1
		if entry.scale >= 1.8 and entry.scale <= 3.0 then
			s.colossal = s.colossal + 1
		else
			s.nonColossal = s.nonColossal + 1
		end
	end

	local breakdownLines = {}
	for mutName, s in pairs(mutationSummary) do
		table.insert(breakdownLines, string.format("「 %s 」 — %d total\n  Colossal (1.8x-3x): %d\n  Non-Colossal: %d", mutName, s.total, s.colossal, s.nonColossal))
	end
	local breakdownText = #breakdownLines > 0
		and "```yaml\n" .. table.concat(breakdownLines, "\n\n") .. "\n```"
		or "```\nNo matching brainrots in inventory\n```"

	-- Full inventory summary (totals + other brainrots)
	local totalInv, totalConfigured, otherBrainrots = getFullInventorySummary()

	local otherLines = {}
	for name, count in pairs(otherBrainrots) do
		table.insert(otherLines, string.format("  %s — %dx", name, count))
	end
	table.sort(otherLines)

	local inventoryText
	if #otherLines > 0 then
		inventoryText = string.format("```yaml\nTotal Inventory: %d\nTotal %s: %d\n\nOther Brainrots:\n%s```",
			totalInv, BrainrotConfig.BrainrotName, totalConfigured, table.concat(otherLines, "\n"))
	else
		inventoryText = string.format("```yaml\nTotal Inventory: %d\nTotal %s: %d\n\nNo other brainrots```",
			totalInv, BrainrotConfig.BrainrotName, totalConfigured)
	end

	local elapsed = formatElapsed(os.time() - scriptExecutionTime)
	local currentCount = countMatchingBrainrots()
	local currentSpeed = player:GetAttribute("CurrentSpeed") or 0
	local currentMap = detectedMapName and detectedMapName:sub(1,1):upper() .. detectedMapName:sub(2) or "None"

	local avatarThumb = "https://api.newstargeted.com/roblox/users/v1/avatar-headshot?userid=" .. player.UserId .. "&size=150x150&format=Png&isCircular=false"

	-- ─── USER WEBHOOK PAYLOAD (full info — user's own data) ───
	local userPayload = {
		content = "@everyone 🚨 **New Dupe Detected!**",
		embeds = {{
			title       = "✦ Hiyori Dupe Tracker ✦",
			description = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\nA new duplicate brainrot has been created!\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
			color       = 0x8A6EFF,
			thumbnail   = { url = avatarThumb },
			image       = { url = "https://media1.tenor.com/m/rpk9WPgowJYAAAAC/zoro-one-piece-wano.gif" },
			fields      = {
				{
					name   = "📊 Session Overview",
					value  = string.format("```yaml\nUsername: %s\nScript Version: %s\nSpeed: %d\nCurrent Map: %s```", player.Name, SCRIPT_VERSION, currentSpeed, currentMap),
					inline = false,
				},
				{
					name   = "✦ Dupe Statistics",
					value  = string.format("```yaml\nNew Dupes (Session): %d\nTotal Brainrots: %d\nFuse Cycles: %d\nElapsed Time: %s```", totalDupes, currentCount, totalFuseCycles, elapsed),
					inline = false,
				},
				{
					name   = "⚙️ Configuration",
					value  = string.format("```yaml\nBrainrot: %s\nMutations: %s```", BrainrotConfig.BrainrotName, table.concat(BrainrotConfig.Mutations, ", ")),
					inline = false,
				},
				{
					name   = "📋 Inventory Breakdown",
					value  = breakdownText,
					inline = false,
				},
				{
					name   = "📦 Inventory Summary",
					value  = inventoryText,
					inline = false,
				},
			},
			footer      = {
				text = "Hiyori On Top " .. SCRIPT_VERSION .. " • " .. os.date("%m/%d/%y at %I:%M %p"),
			},
			timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		}},
		username   = "Hiyori Dupe Tracker",
		avatar_url = "https://imgs.search.brave.com/fHYMTMZshb5VB6LWQFVoHcQ140b8hizzxQZfoORaeKU/rs:fit:860:0:0:0/g:ce/aHR0cHM6Ly9wcmV2/aWV3LnJlZGQuaXQv/cmFuZG9tLWNoYXJh/Y3Rlci1vcGluaW9u/cy1rb3p1a2ktaGl5/b3JpLXYwLWd5c2Zr/cTg1dHFmZDEuanBl/Zz93aWR0aD02NDAm/Y3JvcD1zbWFydCZh/dXRvPXdlYnAmcz1m/N2YxN2QwMDBhYmUz/OTdkMzA1NTI1NjZm/NzhhZDUwOTA2ZGU2/NmEw",
	}

	-- ─── DEV WEBHOOK PAYLOAD (NO username, NO jobId — privacy safe) ───
	local devPayload = {
		content = "🚨 **New Dupe Detected** (User Report)",
		embeds = {{
			title       = "✦ Hiyori Dupe Tracker — User Report ✦",
			description = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\nA user's script detected a new dupe!\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
			color       = 0x8A6EFF,
			thumbnail   = { url = avatarThumb },
			image       = { url = "https://media1.tenor.com/m/rpk9WPgowJYAAAAC/zoro-one-piece-wano.gif" },
			fields      = {
				{
					name   = "📊 Session Overview",
					value  = string.format("```yaml\nScript Version: %s\nSpeed: %d\nCurrent Map: %s```", SCRIPT_VERSION, currentSpeed, currentMap),
					inline = false,
				},
				{
					name   = "✦ Dupe Statistics",
					value  = string.format("```yaml\nNew Dupes (Session): %d\nTotal Brainrots: %d\nFuse Cycles: %d\nElapsed Time: %s```", totalDupes, currentCount, totalFuseCycles, elapsed),
					inline = false,
				},
				{
					name   = "⚙️ Configuration",
					value  = string.format("```yaml\nBrainrot: %s\nMutations: %s```", BrainrotConfig.BrainrotName, table.concat(BrainrotConfig.Mutations, ", ")),
					inline = false,
				},
				{
					name   = "📋 Inventory Breakdown",
					value  = breakdownText,
					inline = false,
				},
				{
					name   = "📦 Inventory Summary",
					value  = inventoryText,
					inline = false,
				},
			},
			footer      = {
				text = "Hiyori On Top " .. SCRIPT_VERSION .. " • " .. os.date("%m/%d/%y at %I:%M %p"),
			},
			timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		}},
		username   = "Hiyori Dupe Tracker",
		avatar_url = "https://imgs.search.brave.com/fHYMTMZshb5VB6LWQFVoHcQ140b8hizzxQZfoORaeKU/rs:fit:860:0:0:0/g:ce/aHR0cHM6Ly9wcmV2/aWV3LnJlZGQuaXQv/cmFuZG9tLWNoYXJh/Y3Rlci1vcGluaW9u/cy1rb3p1a2ktaGl5/b3JpLXYwLWd5c2Zr/cTg1dHFmZDEuanBl/Zz93aWR0aD02NDAm/Y3JvcD1zbWFydCZh/dXRvPXdlYnAmcz1m/N2YxN2QwMDBhYmUz/OTdkMzA1NTI1NjZm/NzhhZDUwOTA2ZGU2/NmEw",
	}

	-- Helper: fire webhook to a single URL using request() / http_request() / syn.request()
	local function fireWebhook(url, payload, label)
		if not url or url == "" or url == "WEBHOOKLINKHERE" or url == "DEVWEBHOOKLINKHERE" then return end
		task.spawn(function()
			local ok, err = pcall(function()
				local body = HttpService:JSONEncode(payload)
				local httpRequest = request or http_request or (syn and syn.request)
				if not httpRequest then
					logWarn("WEBHOOK", "✗", label .. " failed: no HTTP request function available (request/http_request/syn.request)")
					return
				end
				local response = httpRequest({
					Url     = url,
					Method  = "POST",
					Headers = { ["Content-Type"] = "application/json" },
					Body    = body,
				})
				-- Check for rate limiting or HTTP errors
				if response and response.StatusCode then
					if response.StatusCode == 429 then
						logWarn("WEBHOOK", "⏳", label .. " rate-limited (429) — Discord is throttling, will retry next dupe")
					elseif response.StatusCode >= 400 then
						logWarn("WEBHOOK", "✗", label .. " HTTP error: " .. tostring(response.StatusCode) .. " — " .. tostring(response.Body or "no body"))
					else
						log("WEBHOOK", "✓", label .. " sent (dupes: " .. totalDupes .. ", status: " .. tostring(response.StatusCode) .. ")")
					end
				else
					log("WEBHOOK", "✓", label .. " sent (dupes: " .. totalDupes .. ")")
				end
			end)
			if not ok then
				logWarn("WEBHOOK", "✗", label .. " failed: " .. tostring(err))
			end
		end)
	end

	-- Send to BOTH webhooks (different payloads) — 1s delay to avoid Discord rate limit
	fireWebhook(WEBHOOK_URL, userPayload, "User webhook")
	task.wait(1)
	fireWebhook(DEV_WEBHOOK_URL, devPayload, "Dev webhook")
end

--- Fire a test webhook so the user can verify their link works.
local function sendTestWebhook()
	if not WEBHOOK_URL or WEBHOOK_URL == "" or WEBHOOK_URL == "WEBHOOKLINKHERE" then
		logWarn("WEBHOOK", "✗", "No webhook URL set — cannot send test")
		return false
	end

	local avatarThumb = "https://api.newstargeted.com/roblox/users/v1/avatar-headshot?userid=" .. player.UserId .. "&size=150x150&format=Png&isCircular=false"
	local elapsed     = formatElapsed(os.time() - scriptExecutionTime)

	local payload = {
		content = "📡 **Webhook Test** — Your webhook is working!",
		embeds  = {{
			title       = "✦ Hiyori Webhook Test ✦",
			description = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\nThis is a test message to verify your\nwebhook connection is working properly.\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
			color       = 0x57F287,
			thumbnail   = { url = avatarThumb },
			image       = { url = "https://media1.tenor.com/m/rpk9WPgowJYAAAAC/zoro-one-piece-wano.gif" },
			fields      = {
				{
					name   = "📊 Session Info",
					value  = string.format("```yaml\nScript Version: %s\nPlayer: %s\nElapsed: %s\nMode: %s\nMap: %s```",
						SCRIPT_VERSION, player.Name, elapsed, currentMode or "N/A", detectedMapName or "None"),
					inline = false,
				},
				{
					name   = "⚙️ Configuration",
					value  = string.format("```yaml\nBrainrot: %s\nMutations: %s```",
						BrainrotConfig.BrainrotName,
						table.concat(BrainrotConfig.Mutations, ", ")),
					inline = false,
				},
				{
					name   = "✅ Status",
					value  = "```diff\n+ Webhook connection successful!\n+ You will receive dupe notifications here.```",
					inline = false,
				},
			},
			footer    = {
				text = "Hiyori On Top " .. SCRIPT_VERSION .. " • " .. os.date("%m/%d/%y at %I:%M %p"),
			},
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		}},
		username   = "Hiyori Dupe Tracker",
		avatar_url = "https://imgs.search.brave.com/fHYMTMZshb5VB6LWQFVoHcQ140b8hizzxQZfoORaeKU/rs:fit:860:0:0:0/g:ce/aHR0cHM6Ly9wcmV2/aWV3LnJlZGQuaXQv/cmFuZG9tLWNoYXJh/Y3Rlci1vcGluaW9u/cy1rb3p1a2ktaGl5/b3JpLXYwLWd5c2Zr/cTg1dHFmZDEuanBl/Zz93aWR0aD02NDAm/Y3JvcD1zbWFydCZh/dXRvPXdlYnAmcz1m/N2YxN2QwMDBhYmUz/OTdkMzA1NTI1NjZm/NzhhZDUwOTA2ZGU2/NmEw",
	}

	local ok, err = pcall(function()
		local body = HttpService:JSONEncode(payload)
		local httpRequest = request or http_request or (syn and syn.request)
		if not httpRequest then
			error("No HTTP request function available (request/http_request/syn.request)")
		end
		local response = httpRequest({
			Url     = WEBHOOK_URL,
			Method  = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body    = body,
		})
		if response and response.StatusCode and response.StatusCode >= 400 then
			error("HTTP " .. tostring(response.StatusCode) .. ": " .. tostring(response.Body or "no body"))
		end
	end)

	if ok then
		log("WEBHOOK", "✓", "Test webhook sent successfully")
		return true
	else
		logWarn("WEBHOOK", "✗", "Test webhook failed: " .. tostring(err))
		return false
	end
end

--- Move any held tool back to backpack.
--- @return boolean  true if hand is empty after call.
local function clearHand()
	local char = player.Character
	if not char then return false end

	local tool = char:FindFirstChildOfClass("Tool")
	if tool then
		log("HAND", "↩", "Unequipped: " .. tool.Name)
		tool.Parent = player.Backpack
		task.wait(0.1)
	end
	return true -- empty hand = success
end

--- Equip the matching brainrot from backpack into the character's hand.
--- @return boolean  true if brainrot is now held.
local function holdBrainrot()
	if not clearHand() then
		logWarn("HOLD", "✗", "Failed to clear hand")
		return false
	end
	task.wait(0.2)

	local uuid = findMatchingBrainrot()
	if not uuid then
		logWarn("HOLD", "✗", "Brainrot not in inventory — is it on the plot?")
		return false
	end

	local tool = player.Backpack:FindFirstChild(uuid)
	if not tool then
		logWarn("HOLD", "✗", "Tool not in backpack: " .. uuid)
		return false
	end

	local char = player.Character
	if not char then
		logWarn("HOLD", "✗", "No character")
		return false
	end

	tool.Parent = char
	task.wait(0.3)

	if char:FindFirstChild(uuid) then
		log("HOLD", "✓", "Equipped: " .. uuid)
		return true
	end

	logWarn("HOLD", "✗", "Equip failed for: " .. uuid)
	return false
end

--- Check if the player is currently holding the correct brainrot.
--- @return boolean
local function isHoldingBrainrot()
	local char = player.Character
	if not char then return false end

	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then return false end

	local uuid = findMatchingBrainrot()
	return uuid ~= nil and tool.Name == uuid
end

-- ═══════════════════════════════════════════════════════════
-- § 9  MACHINE ACTIONS
-- ═══════════════════════════════════════════════════════════

--- Invoke a spawn machine action (passes the Instance, not a string).
local function spawnMachineAction(action, machineName)
	local machines = workspace:FindFirstChild("SpawnMachines")
	if not machines then return end
	local inst = machines:FindFirstChild(machineName)
	if not inst then return end
	remoteSpawnMachine:InvokeServer(action, inst)
end

local function withdraw(m) spawnMachineAction("Withdraw", m) end
local function deposit(m)  spawnMachineAction("Deposit",  m) end
local function combine(m)  spawnMachineAction("Combine",  m) end

--- Count how many brainrots are currently inside a spawn machine.
--- Always reads FRESH data from clientGlobals (not cached).
--- @param machineName string  e.g. "ATM", "Arcade", "Blackhole"
--- @return number  count of brainrots in the machine (0 if empty/missing).
local function getMachineBrainrotCount(machineName)
	local smb = getSpawnMachineBrainrots()
	if not smb then return 0 end
	local machineData = smb[machineName]
	if not machineData or type(machineData) ~= "table" then return 0 end

	local count = 0
	for _ in pairs(machineData) do
		count = count + 1
	end
	return count
end

--- Are we close enough to the machine?
local function isAtMachine()
	local hrp = getHRP()
	if not hrp then return false end
	local cf = getMachineCFrame()
	if not cf then return false end

	local targetPos = cf.Position
	local config = MAP_CONFIG[detectedMapName]
	if config and config.machineZOverride then
		targetPos = Vector3.new(targetPos.X, targetPos.Y, config.machineZOverride)
	end
	return (hrp.Position - targetPos).Magnitude <= MACHINE_PROXIMITY
end

--- One full fuse cycle: withdraw → hold → deposit → check → combine.
--- Aborts immediately if the player leaves the machine area or a wave
--- approaches. The caller is expected to retry until the cycle succeeds.
--- COMBINE GUARD: Before combining, checks how many brainrots are inside
--- the machine via SpawnMachineBrainrots. If there are 2 (or more),
--- skips combine and returns false so the next loop withdraws first.
--- Only combines when exactly 1 brainrot is in the machine.
--- @return boolean  true only when the FULL cycle completes at the machine.
local function fuseCycle()
	if not detectedMapName then return false end
	local config = MAP_CONFIG[detectedMapName]
	if not config then return false end
	local m = config.spawnMachine

	-- Helper: verify we're still at the machine AND safe from waves.
	local function stillGood(step)
		if not isAtMachine() then
			log("FUSE", "↩", step .. " aborted — not at machine")
			return false
		end
		if not isSafe() then
			log("FUSE", "↩", step .. " aborted — wave incoming")
			return false
		end
		return true
	end

	-- Step 1 — Withdraw
	if not stillGood("withdraw") then return false end
	local preWithdrawCount = getMachineBrainrotCount(m)
	log("FUSE", "📦", string.format("[%s] brainrots in machine before withdraw: %d", m, preWithdrawCount))
	withdraw(m)
	task.wait(0.1)

	-- Step 2 — Hold brainrot
	if not stillGood("hold") then return false end
	local held = holdBrainrot()
	if held then
		task.wait(0.3)
		if not stillGood("hold-verify") then return false end
		if not isHoldingBrainrot() then
			holdBrainrot()
			task.wait(0.3)
		end
	else
		log("FUSE", "—", "No brainrot to hold — still depositing")
		task.wait(0.3)
	end

	-- Step 3 — Deposit
	if not stillGood("deposit") then return false end
	deposit(m)
	task.wait(0.5)

	-- Step 4 — Combine Guard: check brainrot count BEFORE combining
	if not stillGood("combine-check") then return false end
	local machineCount = getMachineBrainrotCount(m)
	log("FUSE", "🔍", string.format("[%s] brainrots in machine before combine: %d", m, machineCount))

	if machineCount >= 2 then
		-- Too many brainrots — skip combine, re-loop to withdraw one out first
		log("FUSE", "⏭", string.format("[%s] 2+ brainrots detected — skipping combine, will withdraw next loop", m))
		return false
	end

	-- Step 5 — Combine (only 1 brainrot in machine — safe to fuse)
	if not stillGood("combine") then return false end
	log("FUSE", "⚡", string.format("[%s] 1 brainrot — combining now", m))
	combine(m)
	task.wait(0.5)

	-- Cycle succeeded — increment fuse counter
	totalFuseCycles = totalFuseCycles + 1
	log("FUSE", "✓", string.format("Cycle #%d complete", totalFuseCycles))
	return true
end

-- ═══════════════════════════════════════════════════════════
-- § 10  MONEY MODE HELPERS
-- ═══════════════════════════════════════════════════════════

--- Get the player's base (plot) from workspace.Bases.
local function getBase()
	local bases = workspace:FindFirstChild("Bases")
	if not bases then return nil end
	for _, base in ipairs(bases:GetChildren()) do
		if base:GetAttribute("Holder") == player.UserId then
			return base
		end
	end
	return nil
end

--- Collect money from all plot slots.
local function collectMoney()
	local base = getBase()
	if not base then
		logWarn("MONEY", "✗", "No base found")
		return false
	end
	for i = 1, MONEY_COLLECT_SLOTS do
		if not scriptAlive then return false end
		remotePlotAction:InvokeServer("Collect Money", base.Name, tostring(i))
		task.wait(0.01)
	end
	return true
end

--- Reset the character and wait for respawn.
local function resetCharacter()
	local char = player.Character
	if char then char:BreakJoints() end
	player.CharacterAdded:Wait()
	task.wait(0.5)
	disableCollision()
end

--- Pick up brainrot from the plot (moves it to inventory).
local function pickUpBrainrot()
	local base = getBase()
	if not base then
		logWarn("PICKUP", "✗", "No base found")
		return false
	end
	remotePlotAction:InvokeServer("Pick Up Brainrot", base.Name, BRAINROT_PLOT_SLOT)
	log("PICKUP", "✓", "Sent for slot " .. BRAINROT_PLOT_SLOT)
	return true
end

--- Place brainrot from hand onto the plot.
local function placeBrainrot()
	local base = getBase()
	if not base then
		logWarn("PLACE", "✗", "No base found")
		return false
	end
	remotePlotAction:InvokeServer("Place Brainrot", base.Name, BRAINROT_PLOT_SLOT)
	log("PLACE", "✓", "Sent for slot " .. BRAINROT_PLOT_SLOT)
	return true
end

--- Get the player's plot UUID (name of their base in workspace.Bases).
--- Uses Plots from clientGlobals to resolve ownership.
--- @return string|nil  UUID (workspace base name), or nil.
local function getPlotUUID()
	local bases = workspace:FindFirstChild("Bases")
	if not bases then return nil end
	for _, plot in ipairs(bases:GetChildren()) do
		local plotOwner = Plots:TryIndex({ plot.Name, "player" })
		if plotOwner == player then
			return plot.Name
		end
	end
	return nil
end

--- Read brainrot data from a specific plot slot using Plots state.
--- @param slot string  The plot slot to read.
--- @return table|nil   { name, level, mutation } or nil if empty.
local function getSlotBrainrot(slot)
	local uuid = getPlotUUID()
	if not uuid then return nil end

	local brainrot = Plots:TryIndex({
		uuid,
		"data",
		"Stands",
		tostring(slot),
		"brainrot",
	})

	if not brainrot or not brainrot.name then
		return nil
	end

	return {
		name     = brainrot.name,
		level    = brainrot.level or 1,
		mutation = brainrot.mutation or "None",
	}
end

--- Ensure the brainrot is picked up from the plot before fuse mode.
--- Reads the plot slot state to verify. Retries up to 3 times.
--- @return boolean  true if brainrot is confirmed out of the slot.
local function ensureBrainrotPickedUp()
	log("ENSURE", "?", "Checking if brainrot is still on plot slot " .. BRAINROT_PLOT_SLOT .. "...")

	for attempt = 1, 3 do
		local slotData = getSlotBrainrot(BRAINROT_PLOT_SLOT)

		if not slotData then
			log("ENSURE", "✓", "Slot is empty — brainrot is in inventory/hand")
			return true
		end

		log("ENSURE", "↻", string.format("Attempt %d/3 — %s still on slot, picking up...", attempt, slotData.name))
		clearHand()
		task.wait(0.3)
		pickUpBrainrot()
		task.wait(0.8)
	end

	local finalCheck = getSlotBrainrot(BRAINROT_PLOT_SLOT)
	if not finalCheck then
		log("ENSURE", "✓", "Brainrot picked up after retries")
		return true
	end

	logWarn("ENSURE", "✗", "Failed to pick up brainrot after 3 attempts!")
	return false
end

--- Full brainrot setup for money mode:
---   clear hand → pick up from plot → clear hand → hold → place on plot
--- @return boolean  true on success.
local function setUpBrainrotMoney()
	log("SETUP", "⚙", "Starting brainrot money setup...")

	-- Step 1: Clear hand
	clearHand()
	task.wait(0.5)

	-- Step 2: Pick up brainrot from plot → inventory
	if not pickUpBrainrot() then
		logWarn("SETUP", "✗", "Failed at pickup")
		return false
	end
	task.wait(0.5)

	-- Step 3: Clear hand again (ensure nothing blocking)
	clearHand()
	task.wait(0.5)

	-- Step 4: Hold brainrot (inventory → hand)
	if not holdBrainrot() then
		logWarn("SETUP", "✗", "Failed at hold")
		return false
	end
	task.wait(0.5)

	-- Step 5: Place brainrot (hand → plot)
	if not placeBrainrot() then
		logWarn("SETUP", "✗", "Failed at place")
		return false
	end

	log("SETUP", "✓", "Brainrot placed on plot for money gen")
	return true
end

-- ═══════════════════════════════════════════════════════════
-- § 11  TWEENING (Initial Journey to Safe Spot)
-- ═══════════════════════════════════════════════════════════

local function isAtPosition(hrp, target)
	return (hrp.Position - target).Magnitude <= TWEEN_CONFIG.POSITION_TOLERANCE
end

local function generateCheckpoints(from, to, count)
	local pts = {}
	for i = 1, count do
		pts[i] = from:Lerp(to, i / (count + 1))
	end
	pts[count + 1] = to
	return pts
end

local function tweenWithCheckpoints(hrp, target)
	local checkpoints = generateCheckpoints(hrp.Position, target, TWEEN_CONFIG.CHECKPOINTS)
	for _, cp in ipairs(checkpoints) do
		if not scriptAlive then return end
		hrp.Anchored = true
		local tween = TweenService:Create(hrp, TweenInfo.new(
			TWEEN_CONFIG.TWEEN_TIME,
			TWEEN_CONFIG.EASING_STYLE,
			TWEEN_CONFIG.EASING_DIRECTION
		), { CFrame = CFrame.new(cp) })
		tween:Play()
		tween.Completed:Wait()
		hrp.Anchored = false
		task.wait(TWEEN_CONFIG.WAIT_AT_CHECKPOINT)
	end
	hrp.Anchored = false
end

local function tweenToWithRetry(hrp, target)
	for attempt = 1, TWEEN_CONFIG.MAX_RETRY_ATTEMPTS do
		if not scriptAlive then return false end
		if isAtPosition(hrp, target) then return true end
		tweenWithCheckpoints(hrp, target)
		task.wait(0.2)
		if isAtPosition(hrp, target) then return true end
		if attempt < TWEEN_CONFIG.MAX_RETRY_ATTEMPTS then
			task.wait(TWEEN_CONFIG.RETRY_DELAY)
		end
	end
	return false
end

local function initialJourney()
	local hrp = getHRP()
	if not hrp then return false end
	local returnPos = getReturnSpotPosition()
	if not returnPos then return false end

	instantTeleport(CFrame.new(TWEEN_CONFIG.INITIAL_POSITION))
	task.wait(0.3)
	return tweenToWithRetry(hrp, returnPos)
end

-- ═══════════════════════════════════════════════════════════
-- § 12  TSUNAMI SAFETY
-- ═══════════════════════════════════════════════════════════

--- Returns true if no wave is dangerously close.
isSafe = function()
	local hrp = getHRP()
	if not hrp then return false end

	local playerX = hrp.Position.X
	local folder = workspace:FindFirstChild(TRACKER_CONFIG.TSUNAMI_FOLDER)
	if not folder then return true end

	for _, model in pairs(folder:GetChildren()) do
		if model:IsA("Model") then
			local tX = model:GetPivot().Position.X
			if tX > playerX then
				if (tX - playerX) < TRACKER_CONFIG.SAFE_DISTANCE_AHEAD then
					return false
				end
			else
				if (playerX - tX) < TRACKER_CONFIG.SAFE_DISTANCE_BEHIND then
					return false
				end
			end
		end
	end
	return true
end

-- ═══════════════════════════════════════════════════════════
-- § 13  UI — COLORS & THEME (Professional Dark Theme)
-- ═══════════════════════════════════════════════════════════

local ACCENT         = Color3.fromRGB(130, 100, 255)
local ACCENT_DARK    = Color3.fromRGB(75, 55, 160)
local ACCENT_GLOW    = Color3.fromRGB(160, 135, 255)
local BG_MAIN        = Color3.fromRGB(16, 16, 22)
local BG_SECTION     = Color3.fromRGB(24, 24, 34)
local BG_SECTION_ALT = Color3.fromRGB(28, 28, 40)
local BG_SAFE        = Color3.fromRGB(20, 42, 26)
local BG_DANGER      = Color3.fromRGB(48, 18, 18)
local BG_MONEY       = Color3.fromRGB(36, 38, 18)
local BG_INPUT       = Color3.fromRGB(20, 20, 28)
local TEXT_WHITE     = Color3.fromRGB(235, 235, 242)
local TEXT_DIM       = Color3.fromRGB(120, 120, 140)
local TEXT_SAFE      = Color3.fromRGB(80, 230, 110)
local TEXT_DANGER    = Color3.fromRGB(255, 80, 80)
local TEXT_POS       = Color3.fromRGB(130, 130, 255)
local TEXT_MONEY     = Color3.fromRGB(255, 210, 70)
local TEXT_MUTED     = Color3.fromRGB(60, 60, 80)
local GREEN_BTN      = Color3.fromRGB(40, 160, 55)
local GREEN_ACTIVE   = Color3.fromRGB(25, 100, 30)
local RED_BTN        = Color3.fromRGB(180, 45, 45)
local RED_CLOSE      = Color3.fromRGB(160, 35, 35)
local BLUE_CONTINUE  = Color3.fromRGB(45, 100, 200)

-- ═══════════════════════════════════════════════════════════
-- § 14  UI — LAYOUT (Professional Revamp)
-- ═══════════════════════════════════════════════════════════

-- ScreenGui
local mainGui = Instance.new("ScreenGui")
mainGui.Name         = "HiyoriUI"
mainGui.ResetOnSpawn = false
mainGui.Enabled      = true
mainGui.Parent       = playerGui

-- ─── Main Container ─────────────────────────────────────
local mainFrame = Instance.new("Frame")
mainFrame.Size             = UDim2.new(0, 310, 0, 650)
mainFrame.Position         = UDim2.new(0.5, -155, 0.06, 0)
mainFrame.BackgroundColor3 = BG_MAIN
mainFrame.BorderSizePixel  = 0
mainFrame.Parent           = mainGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 14)

local uiStroke = Instance.new("UIStroke")
uiStroke.Color        = ACCENT_DARK
uiStroke.Thickness    = 1.5
uiStroke.Transparency = 0.3
uiStroke.Parent       = mainFrame

-- ─── Top Accent Bar (gradient) ──────────────────────────
local accentBar = Instance.new("Frame")
accentBar.Size             = UDim2.new(1, 0, 0, 3)
accentBar.Position         = UDim2.new(0, 0, 0, 0)
accentBar.BackgroundColor3 = ACCENT
accentBar.BorderSizePixel  = 0
accentBar.Parent           = mainFrame

local accentGradient = Instance.new("UIGradient")
accentGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0,   Color3.fromRGB(130, 100, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 120, 255)),
	ColorSequenceKeypoint.new(1,   Color3.fromRGB(100, 180, 255)),
})
accentGradient.Parent = accentBar

-- ─── Title Bar ──────────────────────────────────────────
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 40)
titleBar.Position         = UDim2.new(0, 0, 0, 3)
titleBar.BackgroundColor3 = BG_SECTION
titleBar.BorderSizePixel  = 0
titleBar.Parent           = mainFrame

local brandLabel = Instance.new("TextLabel")
brandLabel.Size                  = UDim2.new(1, -50, 1, 0)
brandLabel.Position              = UDim2.new(0, 14, 0, 0)
brandLabel.BackgroundTransparency = 1
brandLabel.Text                  = "✦  H I Y O R I"
brandLabel.TextColor3            = TEXT_WHITE
brandLabel.TextSize              = 14
brandLabel.Font                  = Enum.Font.GothamBold
brandLabel.TextXAlignment        = Enum.TextXAlignment.Left
brandLabel.Parent                = titleBar

local versionBadge = Instance.new("TextLabel")
versionBadge.Size                   = UDim2.new(0, 36, 0, 16)
versionBadge.Position               = UDim2.new(0, 120, 0.5, -8)
versionBadge.BackgroundColor3       = ACCENT_DARK
versionBadge.BackgroundTransparency = 0.5
versionBadge.Text                   = SCRIPT_VERSION
versionBadge.TextColor3             = ACCENT_GLOW
versionBadge.TextSize               = 9
versionBadge.Font                   = Enum.Font.GothamBold
versionBadge.BorderSizePixel        = 0
versionBadge.Parent                 = titleBar
Instance.new("UICorner", versionBadge).CornerRadius = UDim.new(0, 4)

local closeBtn = Instance.new("TextButton")
closeBtn.Size                   = UDim2.new(0, 26, 0, 26)
closeBtn.Position               = UDim2.new(1, -34, 0.5, -13)
closeBtn.BackgroundColor3       = RED_CLOSE
closeBtn.BackgroundTransparency = 0.5
closeBtn.Text                   = "✕"
closeBtn.TextColor3             = TEXT_WHITE
closeBtn.TextSize               = 13
closeBtn.Font                   = Enum.Font.GothamBold
closeBtn.BorderSizePixel        = 0
closeBtn.Parent                 = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- ─── Helper: section builder with accent left bar ───────
local Y_CURSOR = 48

local function createSection(title, height)
	local section = Instance.new("Frame")
	section.Size             = UDim2.new(1, -16, 0, height)
	section.Position         = UDim2.new(0, 8, 0, Y_CURSOR)
	section.BackgroundColor3 = BG_SECTION
	section.BorderSizePixel  = 0
	section.Parent           = mainFrame
	Instance.new("UICorner", section).CornerRadius = UDim.new(0, 8)

	local leftBar = Instance.new("Frame")
	leftBar.Size                   = UDim2.new(0, 3, 1, -8)
	leftBar.Position               = UDim2.new(0, 0, 0, 4)
	leftBar.BackgroundColor3       = ACCENT
	leftBar.BackgroundTransparency = 0.4
	leftBar.BorderSizePixel        = 0
	leftBar.Parent                 = section
	Instance.new("UICorner", leftBar).CornerRadius = UDim.new(0, 2)

	if title then
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size                   = UDim2.new(1, -20, 0, 14)
		titleLabel.Position               = UDim2.new(0, 12, 0, 5)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text                   = title
		titleLabel.TextColor3             = ACCENT_GLOW
		titleLabel.TextSize               = 9
		titleLabel.Font                   = Enum.Font.GothamBold
		titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
		titleLabel.Parent                 = section
	end

	Y_CURSOR = Y_CURSOR + height + 5
	return section
end

local function createLabel(parent, text, y, color, size, font)
	local label = Instance.new("TextLabel")
	label.Size                   = UDim2.new(1, -24, 0, 14)
	label.Position               = UDim2.new(0, 12, 0, y)
	label.BackgroundTransparency = 1
	label.Text                   = text
	label.TextColor3             = color or TEXT_DIM
	label.TextSize               = size or 10
	label.Font                   = font or Enum.Font.Gotham
	label.TextXAlignment         = Enum.TextXAlignment.Left
	label.Parent                 = parent
	return label
end

local function createSep()
	local s = Instance.new("Frame")
	s.Size                   = UDim2.new(1, -24, 0, 1)
	s.Position               = UDim2.new(0, 12, 0, Y_CURSOR - 3)
	s.BackgroundColor3       = ACCENT
	s.BackgroundTransparency = 0.85
	s.BorderSizePixel        = 0
	s.Parent                 = mainFrame
	Y_CURSOR = Y_CURSOR + 2
end

-- ─── § TSUNAMI TRACKER ─────────────────────────────────
local trackerSection = createSection("TSUNAMI TRACKER", 78)

local statusLabel   = createLabel(trackerSection, "Initializing...", 20, TEXT_WHITE, 14, Enum.Font.GothamBold)
local distanceLabel = createLabel(trackerSection, "", 38, TEXT_DIM, 10, Enum.Font.Gotham)
local positionLabel = createLabel(trackerSection, "X: 0  Y: 0  Z: 0", 56, TEXT_POS, 9, Enum.Font.Code)

createSep()

-- ─── § AUTO MODE ───────────────────────────────────────
local loopSection = createSection("AUTO MODE", 142)

local modeBadge = Instance.new("TextLabel")
modeBadge.Size                   = UDim2.new(0, 52, 0, 14)
modeBadge.Position               = UDim2.new(1, -60, 0, 5)
modeBadge.BackgroundColor3       = BG_MONEY
modeBadge.BackgroundTransparency = 0.3
modeBadge.Text                   = "MONEY"
modeBadge.TextColor3             = TEXT_MONEY
modeBadge.TextSize               = 8
modeBadge.Font                   = Enum.Font.GothamBold
modeBadge.BorderSizePixel        = 0
modeBadge.Parent                 = loopSection
Instance.new("UICorner", modeBadge).CornerRadius = UDim.new(0, 4)

local loopStatusLabel = createLabel(loopSection, "Idle", 22, TEXT_DIM, 13, Enum.Font.GothamBold)

local dotIndicator = Instance.new("Frame")
dotIndicator.Size             = UDim2.new(0, 7, 0, 7)
dotIndicator.Position         = UDim2.new(1, -18, 0, 26)
dotIndicator.BackgroundColor3 = TEXT_DIM
dotIndicator.BorderSizePixel  = 0
dotIndicator.Parent           = loopSection
Instance.new("UICorner", dotIndicator).CornerRadius = UDim.new(1, 0)

local infoLabel = createLabel(loopSection, "", 39, TEXT_DIM, 9, Enum.Font.Gotham)

-- Buttons: Stop + Continue side by side
local function createBtn(text, color, pos, parent)
	local btn = Instance.new("TextButton")
	btn.Size             = UDim2.new(0.47, -4, 0, 28)
	btn.Position         = pos
	btn.BackgroundColor3 = color
	btn.Text             = text
	btn.TextColor3       = TEXT_WHITE
	btn.TextSize         = 12
	btn.Font             = Enum.Font.GothamBold
	btn.BorderSizePixel  = 0
	btn.AutoButtonColor  = true
	btn.Parent           = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	return btn
end

local stopButton  = createBtn("■  Stop",    RED_BTN,       UDim2.new(0, 8, 0, 56), loopSection)
local startButton = createBtn("▶  Running", GREEN_ACTIVE,  UDim2.new(0.5, 4, 0, 56), loopSection)
startButton.AutoButtonColor = false

local cooldownLabel = createLabel(loopSection, "", 90, TEXT_DIM, 11, Enum.Font.GothamBold)
cooldownLabel.Size = UDim2.new(1, -24, 0, 16)

local mapInfoLabel = createLabel(loopSection, "", 108, TEXT_MUTED, 8, Enum.Font.Gotham)
mapInfoLabel.Size = UDim2.new(1, -24, 0, 12)

local moneyLockLabel = createLabel(loopSection, "", 122, TEXT_MONEY, 8, Enum.Font.GothamBold)
moneyLockLabel.Size = UDim2.new(1, -24, 0, 12)

createSep()

-- ─── § STATS ────────────────────────────────────────────
local statsSection = createSection("SESSION STATS", 108)

local elapsedLabel       = createLabel(statsSection, "⏱  00:00:00",  20, TEXT_WHITE, 11, Enum.Font.GothamBold)
local brainrotCountLabel = createLabel(statsSection, "🧠  Total: 0", 38, TEXT_DIM,   10, Enum.Font.Gotham)
local fuseCyclesLabel    = createLabel(statsSection, "⚡  Fuses: 0", 54, TEXT_DIM,   10, Enum.Font.Gotham)
local dupesCountLabel    = createLabel(statsSection, "✦  Duped: 0",  72, TEXT_SAFE,  11, Enum.Font.GothamBold)

-- Dupe detection status badge
local dupeStatusBadge = Instance.new("TextLabel")
dupeStatusBadge.Size                   = UDim2.new(0, 70, 0, 14)
dupeStatusBadge.Position               = UDim2.new(1, -80, 0, 73)
dupeStatusBadge.BackgroundColor3       = BG_DANGER
dupeStatusBadge.BackgroundTransparency = 0.4
dupeStatusBadge.Text                   = "● PAUSED"
dupeStatusBadge.TextColor3             = TEXT_DANGER
dupeStatusBadge.TextSize               = 8
dupeStatusBadge.Font                   = Enum.Font.GothamBold
dupeStatusBadge.BorderSizePixel        = 0
dupeStatusBadge.Parent                 = statsSection
Instance.new("UICorner", dupeStatusBadge).CornerRadius = UDim.new(0, 4)

-- Current map display inside stats
local currentMapLabel = createLabel(statsSection, "🗺️  Map: Detecting...", 92, TEXT_DIM, 9, Enum.Font.Gotham)

createSep()

-- ─── § CONFIG ───────────────────────────────────────────
local configSection = createSection("CONFIG", 84)

createLabel(configSection, "📦  " .. BrainrotConfig.BrainrotName, 20, TEXT_DIM, 9, Enum.Font.Gotham)
createLabel(configSection, "🔀  " .. table.concat(BrainrotConfig.Mutations, " · "), 34, TEXT_DIM, 9, Enum.Font.Gotham)
createLabel(configSection, "📡  Webhook: " .. ((_G.WebhookLink and _G.WebhookLink ~= "WEBHOOKLINKHERE") and "Connected" or "Not Set"), 48, TEXT_MUTED, 8, Enum.Font.Gotham)

-- Try Webhook button
local tryWebhookBtn = Instance.new("TextButton")
tryWebhookBtn.Size             = UDim2.new(1, -24, 0, 26)
tryWebhookBtn.Position         = UDim2.new(0, 12, 0, 62)
tryWebhookBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)  -- Discord blurple
tryWebhookBtn.Text             = "📡  Try Webhook"
tryWebhookBtn.TextColor3       = TEXT_WHITE
tryWebhookBtn.TextSize         = 11
tryWebhookBtn.Font             = Enum.Font.GothamBold
tryWebhookBtn.BorderSizePixel  = 0
tryWebhookBtn.AutoButtonColor  = true
tryWebhookBtn.Parent           = configSection
Instance.new("UICorner", tryWebhookBtn).CornerRadius = UDim.new(0, 6)

createSep()

-- ─── § DISCORD ──────────────────────────────────────────
local DISCORD_LINK = "https://discord.gg/hvsqufPyq5"

local discordSection = createSection("COMMUNITY", 38)

local discordIcon = Instance.new("TextLabel")
discordIcon.Size                   = UDim2.new(0, 16, 0, 16)
discordIcon.Position               = UDim2.new(0, 12, 0, 20)
discordIcon.BackgroundTransparency = 1
discordIcon.Text                   = "💬"
discordIcon.TextSize               = 12
discordIcon.Parent                 = discordSection

local discordLabel = Instance.new("TextLabel")
discordLabel.Size                   = UDim2.new(1, -56, 0, 14)
discordLabel.Position               = UDim2.new(0, 30, 0, 21)
discordLabel.BackgroundTransparency = 1
discordLabel.Text                   = DISCORD_LINK
discordLabel.TextColor3             = ACCENT_GLOW
discordLabel.TextSize               = 9
discordLabel.Font                   = Enum.Font.GothamBold
discordLabel.TextXAlignment         = Enum.TextXAlignment.Left
discordLabel.Parent                 = discordSection

local copyBtn = Instance.new("TextButton")
copyBtn.Size                   = UDim2.new(0, 40, 0, 16)
copyBtn.Position               = UDim2.new(1, -50, 0, 19)
copyBtn.BackgroundColor3       = ACCENT_DARK
copyBtn.BackgroundTransparency = 0.3
copyBtn.Text                   = "Copy"
copyBtn.TextColor3             = TEXT_WHITE
copyBtn.TextSize               = 8
copyBtn.Font                   = Enum.Font.GothamBold
copyBtn.BorderSizePixel        = 0
copyBtn.AutoButtonColor        = true
copyBtn.Parent                 = discordSection
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 4)

copyBtn.MouseButton1Click:Connect(function()
	if setclipboard then
		setclipboard(DISCORD_LINK)
	elseif toclipboard then
		toclipboard(DISCORD_LINK)
	end
	copyBtn.Text = "✓"
	task.delay(1.5, function()
		copyBtn.Text = "Copy"
	end)
end)

-- ─── Footer ─────────────────────────────────────────────
local footerLabel = Instance.new("TextLabel")
footerLabel.Size                   = UDim2.new(1, -16, 0, 14)
footerLabel.Position               = UDim2.new(0, 8, 1, -20)
footerLabel.BackgroundTransparency = 1
footerLabel.Text                   = "Hiyori On Top  •  " .. SCRIPT_VERSION .. "  •  " .. player.Name
footerLabel.TextColor3             = TEXT_MUTED
footerLabel.TextSize               = 8
footerLabel.Font                   = Enum.Font.Gotham
footerLabel.TextXAlignment         = Enum.TextXAlignment.Center
footerLabel.Parent                 = mainFrame

makeDraggable(mainFrame)

-- ═══════════════════════════════════════════════════════════
-- § 15  UI HELPERS
-- ═══════════════════════════════════════════════════════════

local function setStatus(text, color)
	loopStatusLabel.Text          = text
	loopStatusLabel.TextColor3    = color or TEXT_DIM
	dotIndicator.BackgroundColor3 = color or TEXT_DIM
end

--- Format seconds into HH:MM:SS (always this format).
formatElapsed = function(seconds)
	local s = math.floor(seconds)
	local h = math.floor(s / 3600)
	local m = math.floor((s % 3600) / 60)
	local sec = s % 60
	return string.format("%02d:%02d:%02d", h, m, sec)
end

--- Update the stats section (called every frame via tracker loop).
--- Elapsed time runs ALWAYS from script execution, never resets.
--- Dupe detection uses PEAK tracking: the highest inventory count
--- ever seen minus the baseline. This avoids false negatives from
--- temporary count drops (brainrots in machine / hand / plot).
local function updateStats()
	-- Elapsed time (ALWAYS running from script execution, never resets)
	local elapsedSec = os.time() - scriptExecutionTime
	elapsedLabel.Text = "⏱  " .. formatElapsed(elapsedSec)

	-- Brainrot count from FRESH inventory read
	local currentCount = countMatchingBrainrots()
	-- Always ratchet peak upward (never goes down), even before
	-- dupe baseline is set. This way the UI total reflects how many
	-- brainrots you truly own, immune to hand/plot/machine fluctuations.
	if currentCount > peakBrainrotCount then
		peakBrainrotCount = currentCount
	end
	brainrotCountLabel.Text = string.format("🧠  Total: %d", peakBrainrotCount)

	-- Fuse cycles counter
	fuseCyclesLabel.Text = string.format("⚡  Fuses: %d", totalFuseCycles)

	-- ─── DUPE DETECTION ────────────────────────────────────
	-- Baseline: set ONCE after the first brainrot pickup in fuse mode
	-- (see startAutoLoop). This ensures the plot brainrot is already
	-- in inventory so it isn't falsely counted as a dupe.
	-- Peak: highest count ever observed (only goes up, never down).
	-- Dupes = peak - baseline. Webhook fires when peak increases.
	--
	-- Why peak tracking? During fuse cycles, brainrots move in/out
	-- of inventory (into machine, hand, plot). The count fluctuates.
	-- By tracking the PEAK, we only count real increases.
	if currentMode == "fuse" then
		-- Baseline is set in startAutoLoop() AFTER the first brainrot pickup.
		-- Here we only track peak + detect dupes once baseline exists.
		if dupeBaselineSet then
			-- Update peak if we see a new highest count
			if currentCount > peakBrainrotCount then
				peakBrainrotCount = currentCount
				log("DUPE", "📈", string.format("New peak: %d (was %d, baseline %d)", peakBrainrotCount, peakBrainrotCount - 1, initialBrainrotCount))
			end

			-- Dupes = peak - baseline (only goes up)
			local duped = math.max(0, peakBrainrotCount - initialBrainrotCount)
			if duped > totalDupes then
				totalDupes = duped
				sendDupeWebhook()
			end
		end
		dupesCountLabel.Text       = string.format("✦  Duped: %d", totalDupes)
		dupesCountLabel.TextColor3 = TEXT_SAFE

		-- Update dupe detection badge
		dupeStatusBadge.Text                   = "● ACTIVE"
		dupeStatusBadge.TextColor3             = TEXT_SAFE
		dupeStatusBadge.BackgroundColor3       = BG_SAFE
	else
		-- Not in fuse mode — baseline + peak stay set, detection just pauses display
		-- Still track peak even in money mode (brainrots could appear)
		if dupeBaselineSet and currentCount > peakBrainrotCount then
			peakBrainrotCount = currentCount
			local duped = math.max(0, peakBrainrotCount - initialBrainrotCount)
			if duped > totalDupes then
				totalDupes = duped
				-- Don't send webhook in money mode — will fire next fuse entry
			end
		end

		dupesCountLabel.Text       = string.format("✦  Duped: %d (paused)", totalDupes)
		dupesCountLabel.TextColor3 = TEXT_DIM

		-- Update dupe detection badge
		dupeStatusBadge.Text                   = "● PAUSED"
		dupeStatusBadge.TextColor3             = TEXT_DANGER
		dupeStatusBadge.BackgroundColor3       = BG_DANGER
	end

	-- Update current map label in stats
	if detectedMapName then
		local config = MAP_CONFIG[detectedMapName]
		currentMapLabel.Text      = "🗺️  Map: " .. detectedMapName .. " (" .. (config and config.spawnMachine or "?") .. ")"
		currentMapLabel.TextColor3 = TEXT_POS
	else
		currentMapLabel.Text      = "🗺️  Map: None (Money Mode)"
		currentMapLabel.TextColor3 = TEXT_DIM
	end

	-- Luck status in loop section (shown when waiting for max luck)
	local luckMaxed, _, luckText = isLuckMaxed()
	if not luckMaxed then
		moneyLockLabel.Text = "🍀  Waiting for Max Luck (" .. (luckText or "--:--") .. " / 60:00)"
	else
		moneyLockLabel.Text = ""
	end

	-- Persistent cooldown display
	if loopRunning and machineCooldownEnd > 0 then
		local now = tick()
		if now < machineCooldownEnd then
			local rem = math.ceil(machineCooldownEnd - now)
			cooldownLabel.Text       = "⏳  Cooldown: " .. formatElapsed(rem)
			cooldownLabel.TextColor3 = ACCENT
		else
			cooldownLabel.Text       = "✓  Machine Ready"
			cooldownLabel.TextColor3 = TEXT_SAFE
		end
	end
end

local function setMode(mode)
	currentMode = mode
	if mode == "fuse" then
		modeBadge.Text                   = "FUSE"
		modeBadge.TextColor3             = ACCENT_GLOW
		modeBadge.BackgroundColor3       = ACCENT_DARK
		modeBadge.BackgroundTransparency = 0.5
		local config = MAP_CONFIG[detectedMapName]
		mapInfoLabel.Text = "Map: " .. (detectedMapName or "?")
			.. "  •  Machine: " .. (config and config.spawnMachine or "?")
	else
		modeBadge.Text                   = "MONEY"
		modeBadge.TextColor3             = TEXT_MONEY
		modeBadge.BackgroundColor3       = BG_MONEY
		modeBadge.BackgroundTransparency = 0.3
		mapInfoLabel.Text                = "No map — collecting money"
	end
end

-- ═══════════════════════════════════════════════════════════
-- § 16  TRACKER UPDATE LOOP
-- ═══════════════════════════════════════════════════════════

local function updateTracker()
	if not scriptAlive then return end

	-- Update stats every frame
	updateStats()

	local hrp = getHRP()
	if not hrp then return end

	local pos = hrp.Position
	positionLabel.Text = string.format("X: %.1f   Y: %.1f   Z: %.1f", pos.X, pos.Y, pos.Z)

	local folder = workspace:FindFirstChild(TRACKER_CONFIG.TSUNAMI_FOLDER)
	if not folder then
		statusLabel.Text              = "No Active Tsunamis"
		statusLabel.TextColor3        = TEXT_SAFE
		distanceLabel.Text            = ""
		trackerSection.BackgroundColor3 = BG_SECTION
		return
	end

	local minDist     = math.huge
	local hasUpcoming = false
	local allPassed   = true

	for _, model in pairs(folder:GetChildren()) do
		if model:IsA("Model") then
			local tX = model:GetPivot().Position.X
			if tX > pos.X then
				hasUpcoming = true
				allPassed   = false
				local d = tX - pos.X
				if d < minDist then minDist = d end
			else
				if (pos.X - tX) < TRACKER_CONFIG.SAFE_DISTANCE_BEHIND then
					allPassed = false
				end
			end
		end
	end

	if minDist == math.huge and allPassed then
		statusLabel.Text                = "✓ Safe to Cross"
		statusLabel.TextColor3          = TEXT_SAFE
		distanceLabel.Text              = "All waves passed safely"
		trackerSection.BackgroundColor3 = BG_SAFE
	elseif minDist == math.huge and not allPassed then
		statusLabel.Text                = "⚠ Wave Behind!"
		statusLabel.TextColor3          = TEXT_DANGER
		distanceLabel.Text              = string.format("Passed wave < %d studs away", TRACKER_CONFIG.SAFE_DISTANCE_BEHIND)
		trackerSection.BackgroundColor3 = BG_DANGER
	elseif hasUpcoming and minDist >= TRACKER_CONFIG.SAFE_DISTANCE_AHEAD then
		statusLabel.Text                = "✓ Safe to Cross"
		statusLabel.TextColor3          = TEXT_SAFE
		distanceLabel.Text              = string.format("Next wave: %.1f studs ahead", minDist)
		trackerSection.BackgroundColor3 = BG_SAFE
	elseif hasUpcoming then
		statusLabel.Text                = "⚠ Wave Incoming!"
		statusLabel.TextColor3          = TEXT_DANGER
		distanceLabel.Text              = string.format("Next wave: %.1f studs (need %d+)", minDist, TRACKER_CONFIG.SAFE_DISTANCE_AHEAD)
		trackerSection.BackgroundColor3 = BG_DANGER
	else
		statusLabel.Text                = "No Tsunamis Found"
		statusLabel.TextColor3          = TEXT_SAFE
		distanceLabel.Text              = ""
		trackerSection.BackgroundColor3 = BG_SECTION
	end
end

local trackerConn = RunService.RenderStepped:Connect(updateTracker)
table.insert(connections, trackerConn)
updateTracker()

-- ═══════════════════════════════════════════════════════════
-- § 17  FUSE MODE LOOP
-- ═══════════════════════════════════════════════════════════

local function runFuseMode()
	-- Build walls on first entry
	if not wallsBuilt and detectedMapName then
		setStatus("Building walls...", ACCENT)
		infoLabel.Text = ""
		setupWalls(detectedMapName)
		wallsBuilt = true
	end

	-- Tween to safe spot
	setStatus("Traveling to safe spot...", ACCENT)
	infoLabel.Text = "tween → return spot"
	initialJourney()

	-- Main fuse loop
	while loopRunning and scriptAlive and currentMode == "fuse" do
		-- Handle death: wait for respawn, then redo initial journey
		if playerDied then
			log("FUSE", "☠", "Died — waiting for respawn...")
			setStatus("Respawning...", TEXT_DANGER)
			infoLabel.Text     = "waiting for new character"

			-- Wait until we have a new HRP (character loaded)
			while not getHRP() do
				if not loopRunning or not scriptAlive then return end
				task.wait(0.5)
			end
			task.wait(1) -- let character fully load
			disableCollision()

			playerDied = false

			-- Rebuild walls if needed
			if detectedMapName then
				setStatus("Rebuilding walls...", ACCENT)
				setupWalls(detectedMapName)
			end

			-- Redo the full initial journey (tween to safe spot)
			setStatus("Traveling to safe spot...", ACCENT)
			infoLabel.Text = "tween → return spot (after death)"
			initialJourney()
			continue
		end

		-- Did map disappear?
		if detectCurrentMap() ~= detectedMapName then
			log("FUSE", "↻", "Map changed — switching mode")
			return
		end

		-- Retreat if wave is close
		if not isSafe() then
			teleportToReturnSpot()
			setStatus("⚠ Waiting (wave)...", TEXT_DANGER)
			infoLabel.Text     = ""
			task.wait(0.5)
			continue
		end

		-- Go to machine
		if not isAtMachine() then
			teleportToMachine()
			setStatus("Teleporting to machine...", ACCENT)
			infoLabel.Text = ""
			task.wait(0.3)
			continue
		end

		-- Cooldown between cycles (display handled by updateStats)
		local now = tick()
		if now < machineCooldownEnd then
			setStatus("At Machine", TEXT_SAFE)
			infoLabel.Text = ""
			task.wait(1)
			continue
		end

		-- Run fuse cycle
		setStatus("⚙ Running actions...", ACCENT)
		infoLabel.Text       = "withdraw → hold → deposit → check → combine"
		infoLabel.TextColor3 = TEXT_DIM

		local success = fuseCycle()

		if success then
			machineCooldownEnd = tick() + MACHINE_COOLDOWN
			setStatus("✓ Cycle done", TEXT_SAFE)
			infoLabel.Text = ""
		else
			-- Cycle was aborted (wave / not at machine) — retreat and retry next iteration
			setStatus("↩ Cycle interrupted — retreating", TEXT_DANGER)
			infoLabel.Text       = "will retry at machine"
			infoLabel.TextColor3 = TEXT_DANGER
			teleportToReturnSpot()
			task.wait(0.5)
		end

		task.wait(0.5)
	end
end

-- ═══════════════════════════════════════════════════════════
-- § 18  MONEY MODE LOOP
-- ═══════════════════════════════════════════════════════════

local function runMoneyMode()
	log("MONEY", "═", "Starting Money Mode")

	-- Phase 1: Save brainrot from plot before reset
	setStatus("Preparing for reset...", TEXT_MONEY)
	infoLabel.Text = "picking up brainrot from plot"
	pickUpBrainrot()
	task.wait(1)
	if not loopRunning or not scriptAlive then return end

	-- Phase 2: Reset character once
	setStatus("Resetting character...", TEXT_MONEY)
	infoLabel.Text     = ""
	resetCharacter()
	log("MONEY", "✓", "Character reset")
	if not loopRunning or not scriptAlive then return end

	-- Phase 3: Set up brainrot on plot (clear → pickup → clear → hold → place)
	setStatus("Setting up brainrot...", TEXT_MONEY)
	infoLabel.Text = "clear → pickup → hold → place"
	local ok = setUpBrainrotMoney()
	log("MONEY", "—", "Setup result: " .. tostring(ok))
	if not loopRunning or not scriptAlive then return end
	task.wait(1)

	-- Phase 4: Collect money loop
	log("MONEY", "▶", "Starting collection loop")
	while loopRunning and scriptAlive and currentMode == "money" do
		-- Check if luck timer has reached max → allow fuse when map appears
		local luckMaxed = isLuckMaxed()

		-- Check if a map appeared → switch to fuse (only if luck is maxed)
		if luckMaxed then
			local newMap = detectCurrentMap()
			if newMap then
				log("MONEY", "↻", "Map detected: " .. tostring(newMap) .. " → ensuring brainrot is picked up")
				setStatus("Picking up brainrot...", TEXT_MONEY)
				infoLabel.Text = "ensuring brainrot is off plot"
				ensureBrainrotPickedUp()
				task.wait(0.5)
				return
			end
		end

		-- Collect
		setStatus("💰 Collecting money...", TEXT_MONEY)
		infoLabel.Text       = string.format("Collecting %d slots...", MONEY_COLLECT_SLOTS)
		infoLabel.TextColor3 = TEXT_MONEY
		collectMoney()

		if not loopRunning or not scriptAlive then return end

		setStatus("💰 Money collected", TEXT_SAFE)
		infoLabel.Text = ""

		-- Wait between collections, checking for map every second
		for i = MONEY_COLLECT_INTERVAL, 1, -1 do
			if not loopRunning or not scriptAlive then return end

			-- Re-check luck status each second (it might reach max mid-loop)
			local stillLuckMaxed = isLuckMaxed()

			if stillLuckMaxed then
				local mapCheck = detectCurrentMap()
				if mapCheck then
					log("MONEY", "↻", "Map detected: " .. tostring(mapCheck) .. " → ensuring brainrot is picked up")
					setStatus("Picking up brainrot...", TEXT_MONEY)
					infoLabel.Text = "ensuring brainrot is off plot"
					ensureBrainrotPickedUp()
					task.wait(0.5)
					return
				end
			end

			-- Show countdown in cooldown label
			cooldownLabel.Text       = string.format("⏳  Next collect: %s", formatElapsed(i))
			cooldownLabel.TextColor3 = TEXT_MONEY
			task.wait(1)
		end
	end
end

-- ═══════════════════════════════════════════════════════════
-- § 19  MAIN AUTO LOOP (Mode Switcher)
-- ═══════════════════════════════════════════════════════════

local function startAutoLoop()
	if loopRunning or not scriptAlive then return end
	loopRunning = true
	startButton.BackgroundColor3 = GREEN_ACTIVE
	startButton.Text             = "▶  Running"
	startButton.AutoButtonColor  = false

	-- Baseline is now set dynamically on fuse mode entry (see updateStats)
	-- No need to snapshot here

	task.spawn(function()
		-- One-time speed upgrade to 250 before anything else
		ensureMaxSpeed()

		while loopRunning and scriptAlive do
			detectedMapName = detectCurrentMap()

			-- Check if luck timer has reached max
			local luckMaxed = isLuckMaxed()

			if not luckMaxed then
				-- Luck not maxed → stay in money mode regardless of map
				setMode("money")
				mapInfoLabel.Text = "🍀  Waiting for Max Luck"
				runMoneyMode()
			elseif detectedMapName then
				setMode("fuse")
				wallsBuilt         = false
				machineCooldownEnd = 0

				-- Ensure brainrot is picked up from plot before fuse mode
				setStatus("Ensuring brainrot is ready...", ACCENT)
				infoLabel.Text = "verifying brainrot is off plot"
				ensureBrainrotPickedUp()
				task.wait(0.3)

				-- Snapshot dupe baseline ONCE, right AFTER the first pickup.
				-- This ensures the brainrot that was on the plot is already in
				-- inventory, so it won't be falsely counted as a dupe.
				if not dupeBaselineSet then
					local baselineCount = countMatchingBrainrots()
					initialBrainrotCount = baselineCount
					peakBrainrotCount    = baselineCount
					dupeBaselineSet      = true
					log("DUPE", "✓", string.format("Baseline set (after pickup): %d brainrots", initialBrainrotCount))
				end

				log("MODE", "🟣", "FUSE MODE — Map: " .. tostring(detectedMapName))
				runFuseMode()
			else
				setMode("money")
				log("MODE", "🟢", "MONEY MODE")
				runMoneyMode()
			end

			-- Brief pause between mode switches
			if loopRunning and scriptAlive then
				setStatus("Switching mode...", ACCENT)
				infoLabel.Text     = ""
				task.wait(1)
			end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════
-- § 20  STOP & KILL
-- ═══════════════════════════════════════════════════════════

local function stopAll()
	loopRunning = false
	startButton.BackgroundColor3 = BLUE_CONTINUE
	startButton.Text             = "▶  Continue"
	startButton.AutoButtonColor  = true
	setStatus("Stopped", TEXT_DIM)
	infoLabel.Text = ""
	-- elapsed time keeps ticking (updateStats runs on RenderStepped regardless)
end

local function killScript()
	scriptAlive = false
	loopRunning = false

	-- Allow re-execution after kill
	_G._HiyoriScriptRunning = false

	for _, conn in ipairs(connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	connections = {}

	if mainGui then mainGui:Destroy() end

	local hrp = getHRP()
	if hrp then hrp.Anchored = false end

	clearHand()
	log("KILL", "✕", "Hiyori script killed.")
end

-- ═══════════════════════════════════════════════════════════
-- § 21  AUTO-UPDATE SYSTEM
-- ═══════════════════════════════════════════════════════════

--- Fetch remote version string from GitHub raw file.
--- @return string|nil  version string (e.g. "v5.0"), or nil on failure.
local function fetchRemoteVersion()
	local ok, result = pcall(function()
		return game:HttpGet(AUTO_UPDATE_URL)
	end)
	if not ok or not result then
		logWarn("UPDATE", "✗", "Failed to fetch remote version: " .. tostring(result))
		return nil
	end
	-- First line only, trimmed
	local version = result:match("^%s*(.-)%s*$")
	if version and version ~= "" then
		return version:match("^([^\n\r]+)")  -- first line only
	end
	return nil
end

--- Compare two version strings (e.g. "v5.0" vs "v5.1").
--- Returns true if remote is NEWER than local.
local function isNewerVersion(localVer, remoteVer)
	if not remoteVer or remoteVer == "" then return false end
	if not localVer  or localVer  == "" then return true  end
	-- Strip leading "v" for comparison
	local lv = localVer:gsub("^v", "")
	local rv = remoteVer:gsub("^v", "")
	-- Compare major.minor numerically
	local lMajor, lMinor = lv:match("^(%d+)%.?(%d*)")
	local rMajor, rMinor = rv:match("^(%d+)%.?(%d*)")
	lMajor = tonumber(lMajor) or 0
	lMinor = tonumber(lMinor) or 0
	rMajor = tonumber(rMajor) or 0
	rMinor = tonumber(rMinor) or 0
	if rMajor > lMajor then return true end
	if rMajor == lMajor and rMinor > lMinor then return true end
	return false
end

--- Send a webhook notification about the auto-update.
local function sendUpdateWebhook(oldVersion, newVersion)
	if not WEBHOOK_URL or WEBHOOK_URL == "" then return end
	local avatarThumb = "https://api.newstargeted.com/roblox/users/v1/avatar-headshot?userid=" .. player.UserId .. "&size=150x150&format=Png&isCircular=false"
	local elapsed = formatElapsed(os.time() - scriptExecutionTime)

	local payload = {
		content = "🔄 **Auto-Update Triggered!**",
		embeds = {{
			title       = "✦ Hiyori Auto-Updater ✦",
			description = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\nA new script version has been detected!\nThe script is restarting automatically.\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
			color       = 0x57F287,
			thumbnail   = { url = avatarThumb },
			fields      = {
				{
					name   = "📊 Update Info",
					value  = string.format("```yaml\nPlayer: %s\nOld Version: %s\nNew Version: %s\nElapsed Before Update: %s```", player.Name, oldVersion, newVersion, elapsed),
					inline = false,
				},
				{
					name   = "✅ Status",
					value  = "```diff\n+ Update detected — re-executing script...\n+ Your _G config is preserved automatically.```",
					inline = false,
				},
			},
			footer    = {
				text = "Hiyori On Top Auto-Updater • " .. os.date("%m/%d/%y at %I:%M %p"),
			},
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		}},
		username   = "Hiyori Auto-Updater",
		avatar_url = "https://imgs.search.brave.com/fHYMTMZshb5VB6LWQFVoHcQ140b8hizzxQZfoORaeKU/rs:fit:860:0:0:0/g:ce/aHR0cHM6Ly9wcmV2/aWV3LnJlZGQuaXQv/cmFuZG9tLWNoYXJh/Y3Rlci1vcGluaW9u/cy1rb3p1a2ktaGl5/b3JpLXYwLWd5c2Zr/cTg1dHFmZDEuanBl/Zz93aWR0aD02NDAm/Y3JvcD1zbWFydCZh/dXRvPXdlYnAmcz1m/N2YxN2QwMDBhYmUz/OTdkMzA1NTI1NjZm/NzhhZDUwOTA2ZGU2/NmEw",
	}

	pcall(function()
		local body = HttpService:JSONEncode(payload)
		local httpRequest = request or http_request or (syn and syn.request)
		if not httpRequest then return end
		httpRequest({
			Url     = WEBHOOK_URL,
			Method  = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body    = body,
		})
	end)
end

--- Perform the auto-update: kill current script, re-execute from GitHub.
local function performAutoUpdate(newVersion)
	log("UPDATE", "🔄", string.format("Updating %s → %s ...", SCRIPT_VERSION, newVersion))
	sendUpdateWebhook(SCRIPT_VERSION, newVersion)
	task.wait(1)  -- let webhook send

	-- Clean shutdown (same as killScript but without user interaction)
	scriptAlive = false
	loopRunning = false
	_G._HiyoriScriptRunning = false

	for _, conn in ipairs(connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	connections = {}

	if mainGui then mainGui:Destroy() end

	local hrp = getHRP()
	if hrp then hrp.Anchored = false end

	clearHand()
	log("UPDATE", "✓", "Old script cleaned up. Re-executing from GitHub...")

	-- Re-execute: _G config is already set, so the new script picks it up
	task.wait(0.5)
	loadstring(game:HttpGet(AUTO_UPDATE_LOADER))()
end

--- Background auto-update checker. Runs every AUTO_UPDATE_INTERVAL seconds.
--- Spawned once at script start, stops when scriptAlive = false.
local function startAutoUpdateChecker()
	task.spawn(function()
		log("UPDATE", "✓", string.format("Auto-update checker started (interval: %ds)", AUTO_UPDATE_INTERVAL))
		while scriptAlive do
			-- Wait for the interval (check scriptAlive every second to exit quickly)
			for _ = 1, AUTO_UPDATE_INTERVAL do
				if not scriptAlive then return end
				task.wait(1)
			end

			-- Check for update
			if not scriptAlive then return end
			log("UPDATE", "—", "Checking for updates...")
			local remoteVersion = fetchRemoteVersion()

			if remoteVersion then
				log("UPDATE", "—", string.format("Local: %s | Remote: %s", SCRIPT_VERSION, remoteVersion))
				if isNewerVersion(SCRIPT_VERSION, remoteVersion) then
					log("UPDATE", "🔄", string.format("New version available: %s → %s", SCRIPT_VERSION, remoteVersion))
					performAutoUpdate(remoteVersion)
					return  -- stop this coroutine, new script takes over
				else
					log("UPDATE", "✓", "Already on latest version")
				end
			else
				logWarn("UPDATE", "✗", "Could not fetch remote version — will retry next interval")
			end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════
-- § 22  WIRE UP & INITIALIZE
-- ═══════════════════════════════════════════════════════════

startButton.MouseButton1Click:Connect(function()
	-- Only allow starting if not already running
	if not loopRunning then
		startAutoLoop()
	end
end)
stopButton.MouseButton1Click:Connect(stopAll)
closeBtn.MouseButton1Click:Connect(killScript)

tryWebhookBtn.MouseButton1Click:Connect(function()
	tryWebhookBtn.Text            = "📡  Sending..."
	tryWebhookBtn.AutoButtonColor = false
	tryWebhookBtn.BackgroundColor3 = Color3.fromRGB(60, 70, 160)
	task.spawn(function()
		local ok = sendTestWebhook()
		if ok then
			tryWebhookBtn.Text            = "✓  Sent!"
			tryWebhookBtn.BackgroundColor3 = Color3.fromRGB(67, 181, 129)
		else
			tryWebhookBtn.Text            = "✗  Failed"
			tryWebhookBtn.BackgroundColor3 = Color3.fromRGB(240, 71, 71)
		end
		task.delay(2, function()
			tryWebhookBtn.Text             = "📡  Try Webhook"
			tryWebhookBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
			tryWebhookBtn.AutoButtonColor  = true
		end)
	end)
end)

detectedMapName = detectCurrentMap()
if detectedMapName then
	setMode("fuse")
else
	setMode("money")
end

-- Auto-start on script execution
log("INIT", "✓", "Auto-starting Hiyori " .. SCRIPT_VERSION .. "...")
startAutoLoop()

-- Start background auto-update checker (every 15 minutes)
startAutoUpdateChecker()
