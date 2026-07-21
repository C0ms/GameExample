-- @ScriptType: ModuleScript
local ITERATIONS = 8
local TAU = math.pi * 2

local SPRING = {}

function SPRING.new(frequency, dampingRatio, speed)
	local spring = {
		Target = Vector3.zero,
		Position = Vector3.zero,
		Velocity = Vector3.zero,

		Frequency = frequency or 2,
		DampingRatio = dampingRatio or 0.3,
		Speed = speed or 1,
	}

	function spring:getstats()
		return self.Frequency, self.DampingRatio, self.Speed
	end

	function spring:changestats(frequency, dampingRatio, speed)
		self.Frequency = frequency or self.Frequency
		self.DampingRatio = dampingRatio or self.DampingRatio
		self.Speed = speed or self.Speed
	end

	function spring:shove(force)
		local x, y, z = force.X, force.Y, force.Z

		if x ~= x or x == math.huge or x == -math.huge then
			x = 0
		end

		if y ~= y or y == math.huge or y == -math.huge then
			y = 0
		end

		if z ~= z or z == math.huge or z == -math.huge then
			z = 0
		end

		self.Velocity += Vector3.new(x, y, z)
	end

	function spring:update(dt)
		local omega = TAU * self.Frequency
		local h = (dt * self.Speed) / ITERATIONS

		local position = self.Position
		local velocity = self.Velocity

		for _ = 1, ITERATIONS do
			local acceleration =
				(self.Target - position) * (omega * omega)
			- velocity * (2 * self.DampingRatio * omega)

			velocity += acceleration * h
			position += velocity * h
		end

		self.Position = position
		self.Velocity = velocity

		return position
	end

	return spring
end

return SPRING