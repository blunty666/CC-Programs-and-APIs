local function checkPositiveNumber(value)
	return type(value) == "number" and value >= 0
end

local pidMethods = {
	GetSetpoint = function(self)
		return self.setpoint
	end,
	SetSetpoint = function(self, newSetpoint)
		if type(newSetpoint) == "number" then
			self.setpoint = newSetpoint
			return true
		end
		return false
	end,

	GetKp = function(self)
		return self.Kp
	end,
	SetKp = function(self, newKp)
		if checkPositiveNumber(newKp) then
			self.Kp = newKp
			return true
		end
		return false
	end,
	
	GetKi = function(self)
		return self.Ki
	end,
	SetKi = function(self, newKi)
		if checkPositiveNumber(newKi) then
			self.Ki = newKi
			return true
		end
		return false
	end,
	
	GetKd = function(self)
		return self.Kd
	end,
	SetKd = function(self, newKd)
		if checkPositiveNumber(newKd) then
			self.Kd = newKd
			return true
		end
		return false
	end,

	CalculateOutput = function(self, measured, deltaTime)
		local thisError = self.setpoint - measured
		self.integral = self.integral + thisError*deltaTime
		local derivative = (thisError - self.prevError)/deltaTime
		local output = self.Kp*thisError + self.Ki*self.integral + self.Kd*derivative
		self.prevError = thisError
		return output
	end,
	Reset = function(self)
		self.prevError = 0
		self.integral = 0
	end,
}
local pidMetatable = {__index = pidMethods}

function new(setpoint, Kp, Ki, Kd)
	if type(setpoint) ~= "number" then
		error("new - number expected: setpoint", 2)
	end
	local pid = {
		setpoint = setpoint,

		Kp = checkPositiveNumber(Kp) and Kp or 1,
		Ki = checkPositiveNumber(Ki) and Ki or 1,
		Kd = checkPositiveNumber(Kd) and Kd or 1,
		
		prevError = 0,
		integral = 0,
	}
	return setmetatable(pid, pidMetatable)
end
