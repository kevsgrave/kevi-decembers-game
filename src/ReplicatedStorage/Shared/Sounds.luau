-- Every sound the game plays, in one list. It's empty on purpose: each id needs the owner's approval, because only licensed
-- audio may be used. docs/phase8/ASSETS.md has the candidates. Fill in an id and that sound starts working; nil plays nothing.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Sounds = {}

Sounds.IDS = {
	scare = nil, -- when a monster pops up
	scareSoft = nil, -- the same moment with reduced scares on
	payout = nil,
	hatch = nil,
	buy = nil,
	music = nil, -- loops quietly
}

local function volume(attribute: string): number
	local player = Players.LocalPlayer
	local v = player and player:GetAttribute(attribute)
	return if type(v) == "number" then v else 1
end

local function make(id: number, parent)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Parent = parent or SoundService
	return s
end

-- plays one effect, at a part to fade with distance or everywhere if none
function Sounds.play(name: string, at: BasePart?)
	local id = Sounds.IDS[name]
	if not id then return end
	local s = make(id, at)
	s.Volume = 0.6 * volume("SfxVolume")
	s.RollOffMaxDistance = 90
	s.Ended:Once(function() s:Destroy() end)
	s:Play()
end

local music = nil

-- starts the music if it has an id, and follows the volume setting
function Sounds.startMusic()
	local id = Sounds.IDS.music
	if not id then return end
	if not music then
		music = make(id)
		music.Looped = true
		music:Play()
	end
	music.Volume = 0.25 * volume("MusicVolume")
end

return Sounds
