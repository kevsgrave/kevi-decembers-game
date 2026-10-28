-- From the LihFolk vault, "Saved Inventory End to End" 4.2, with a Studio-only unsaved fallback.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataTemplate = require(script.Parent.DataTemplate)

local STORE_NAME = "JumpscareRNG_PlayerData_v1"
local LEASE_SECONDS = 120
local AUTOSAVE_SECONDS = 60
local CLAIM_ATTEMPTS = if game:GetService("RunService"):IsStudio() then 1 else 5 -- Studio falls back to an unsaved session quickly
local SAVE_ATTEMPTS = 3
local MIN_SAVE_SPACING = 6 -- seconds between writes to one key (rule of thumb)
local IS_STUDIO = RunService:IsStudio()

-- GetDataStore throws in an unpublished place; every call below is pcall'd, so a nil store just means "failed" loads
local storeOk, store = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
if not storeOk then
	warn("[PlayerData] DataStores unavailable: " .. tostring(store))
	store = nil :: any
end

type Session = { Token: string, JobId: string, ExpiresAt: number }
type Record = { Data: any?, Session: Session? }
type ClaimStatus = "ready" | "locked" | "failed"

export type Profile = {
	Player: Player,
	Key: string,
	Token: string,
	Data: DataTemplate.Data,
	State: "active" | "lost" | "released",
	Unsaved: boolean?, -- Studio without API access: play on defaults that never save
	Saving: boolean,
	LastSave: number,
}

local PlayerData = {}

local profiles: { [Player]: Profile } = {}
local releasing: { [Profile]: boolean } = {}
local loadedCallbacks: { (Profile) -> () } = {}

local function keyFor(userId: number): string
	if IS_STUDIO then
		-- Studio never touches live saves. Set ServerStorage attribute TestProfileKey
		-- to a short word to get a fresh profile; clear it to return to your Studio save.
		local test = ServerStorage:GetAttribute("TestProfileKey")
		if type(test) == "string" and test ~= "" and #test <= 20 then
			return `STUDIO_{test}_{userId}`
		end
		return `STUDIO_{userId}`
	end
	return `U_{userId}`
end

local function claimAsync(key: string, token: string): (ClaimStatus, any)
	local status: ClaimStatus = "failed"
	local data: any = nil
	for attempt = 1, CLAIM_ATTEMPTS do
		status = "failed"
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old: Record?): Record?
				local now = os.time()
				local record: Record = old or {}
				local session = record.Session
				if session and session.Token ~= token and session.ExpiresAt > now then
					status = "locked"
					return nil -- cancel the write: someone else owns it
				end
				record.Session = { Token = token, JobId = game.JobId, ExpiresAt = now + LEASE_SECONDS }
				status = "ready"
				data = record.Data
				return record
			end)
		end)
		if not ok then
			status = "failed"
			warn(`[PlayerData] claim {key} attempt {attempt} failed: {err}`)
		elseif status == "ready" then
			return "ready", data
		end
		if attempt < CLAIM_ATTEMPTS then
			task.wait(if status == "locked" then 5 else 2 ^ attempt)
		end
	end
	return status, nil
end

local function releaseUnused(key: string, token: string)
	pcall(function()
		store:UpdateAsync(key, function(old: Record?): Record?
			if old and old.Session and old.Session.Token == token then
				old.Session = nil
				return old
			end
			return nil
		end)
	end)
end

local function saveAsync(profile: Profile, release: boolean): boolean
	while profile.Saving do
		task.wait(0.1)
	end
	if profile.State ~= "active" or profile.Unsaved then
		return false
	end
	profile.Saving = true
	-- Snapshot now: gameplay keeps mutating Data while the request yields.
	local snapshot = DataTemplate.deepCopy(profile.Data)
	local success = false
	for attempt = 1, SAVE_ATTEMPTS do
		local lost = false
		local ok, err = pcall(function()
			store:UpdateAsync(profile.Key, function(old: Record?): Record?
				local session = if old then old.Session else nil
				if old == nil or session == nil or session.Token ~= profile.Token then
					lost = true
					return nil
				end
				old.Data = snapshot
				old.Session = if release
					then nil
					else { Token = profile.Token, JobId = game.JobId, ExpiresAt = os.time() + LEASE_SECONDS }
				return old
			end)
		end)
		if ok and lost then
			profile.State = "lost"
			warn(`[PlayerData] lost session for {profile.Key}`)
			if profile.Player.Parent == Players then
				profile.Player:Kick("Your data was opened on another server. Please rejoin.")
			end
			break
		elseif ok then
			success = true
			break
		end
		warn(`[PlayerData] save {profile.Key} attempt {attempt} failed: {err}`)
		if attempt < SAVE_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end
	profile.LastSave = os.clock()
	if release and success then
		profile.State = "released"
	end
	profile.Saving = false
	return success
end

local function onPlayerAdded(player: Player)
	local key = keyFor(player.UserId)
	if IS_STUDIO and ServerStorage:GetAttribute("SimulateLoadFailure") == true then
		player:Kick("[Studio] Simulated load failure. Nothing was saved.")
		return
	end
	local token = HttpService:GenerateGUID(false)
	local status, raw = claimAsync(key, token)

	if player.Parent ~= Players then
		if status == "ready" then
			releaseUnused(key, token) -- left while loading; give the lease back
		end
		return
	end
	if status == "failed" and IS_STUDIO then
		-- usually "Enable Studio Access to API Services" is off; play on defaults that are never written
		warn("[PlayerData] Studio could not reach DataStores; this session will NOT be saved")
		local profile: Profile = {Player = player, Key = key, Token = token, Data = DataTemplate.new(), State = "active", Saving = false, LastSave = os.clock(), Unsaved = true}
		profiles[player] = profile
		player:SetAttribute("DataReady", true)
		player:SetAttribute("DataUnsaved", true)
		for _, callback in loadedCallbacks do
			task.spawn(callback, profile)
		end
		return
	end
	if status ~= "ready" then
		player:Kick(if status == "locked"
			then "Your progress is still saving on another server. Please rejoin in a minute."
			else "We could not load your progress. Nothing was changed. Please rejoin.")
		return
	end

	local data, reason = DataTemplate.prepare(raw)
	if not data then
		releaseUnused(key, token)
		warn(`[PlayerData] refused {key}: {reason}`)
		player:Kick(if reason == "newer"
			then "This server is out of date. Please rejoin to get a newer server."
			else "Your save could not be read. Nothing was changed. Please contact support.")
		return
	end

	local profile: Profile = {
		Player = player,
		Key = key,
		Token = token,
		Data = data,
		State = "active",
		Saving = false,
		LastSave = os.clock(),
	}
	profiles[player] = profile
	player:SetAttribute("DataReady", true)
	for _, callback in loadedCallbacks do
		task.spawn(callback, profile)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	-- Remove first so no service mutates Data after the final snapshot.
	profiles[player] = nil
	releasing[profile] = true
	saveAsync(profile, true)
	releasing[profile] = nil
end

-- Public API -------------------------------------------------------------

-- The active profile, or nil while loading, after leaving, or after a failed load.
function PlayerData.Get(player: Player): Profile?
	local profile = profiles[player]
	if profile and profile.State == "active" then
		return profile
	end
	return nil
end

function PlayerData.WaitForProfile(player: Player, timeout: number): Profile?
	local deadline = os.clock() + timeout
	while player.Parent == Players and os.clock() < deadline do
		local profile = PlayerData.Get(player)
		if profile then
			return profile
		end
		task.wait(0.25)
	end
	return PlayerData.Get(player)
end

-- Runs for every profile that loads, including ones that loaded before the call.
function PlayerData.OnLoaded(callback: (Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for _, profile in profiles do
		if profile.State == "active" then
			task.spawn(callback, profile)
		end
	end
end

-- Write now (after purchases, rare grants). Respects MIN_SAVE_SPACING.
function PlayerData.SaveNowAsync(player: Player): boolean
	local profile = PlayerData.Get(player)
	if not profile then
		return false
	end
	local waitFor = MIN_SAVE_SPACING - (os.clock() - profile.LastSave)
	if waitFor > 0 then
		task.wait(waitFor)
	end
	return saveAsync(profile, false)
end

function PlayerData.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, profile in profiles do
				if profile.State == "active" then
					task.spawn(saveAsync, profile, false)
					task.wait(0.5) -- spread writes so a full server is not one burst
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			profiles[player] = nil
			pending += 1
			task.spawn(function()
				saveAsync(profile, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25 -- BindToClose has about 30 s in total (Roblox docs)
		while (pending > 0 or next(releasing) ~= nil) and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return PlayerData
