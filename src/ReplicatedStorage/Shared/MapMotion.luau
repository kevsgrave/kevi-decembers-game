-- The maths for everything that moves on the map, so it can be tested without pressing Play. MapLife.client plays it.
local MapMotion = {}

-- a ghost drifts around its home spot, bobbing and swaying
function MapMotion.ghost(home: CFrame, t: number, phase: number, drift: number): CFrame
	local p = t + phase
	return home
		* CFrame.new(math.sin(p * 0.5) * drift, math.sin(p * 1.6) * 0.9, math.cos(p * 0.37) * drift)
		* CFrame.Angles(0, math.sin(p * 0.7) * 0.3, math.sin(p * 1.1) * 0.07)
end

-- a machine part spins and/or bobs on the spot
function MapMotion.part(home: CFrame, t: number, phase: number, spin: Vector3?, bob: number, bobSpeed: number): CFrame
	local cf = home
	if bob ~= 0 then cf *= CFrame.new(0, math.sin((t + phase) * bobSpeed) * bob, 0) end
	if spin then cf *= CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t) end
	return cf
end

-- a glowing panel breathes between its own transparency and a bit more see-through
function MapMotion.pulse(base: number, t: number, speed: number): number
	return base + (1 - base) * 0.35 * (0.5 + 0.5 * math.sin(t * speed))
end

function MapMotion.blinking(t: number, phase: number): boolean
	return (t + phase) % 4.5 < 0.14
end

return MapMotion
