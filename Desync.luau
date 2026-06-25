local Desync = {}
Desync.__index = Desync

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

function Desync.new()
    local self = setmetatable({}, Desync)
    
	self._isShouldClean = false
    self._targetCFrame = nil
    self._backedUpCFrames = {}
    self._isActive = false
    self._connection = nil
    self._oldIndex = nil
    
    return self
end

function Desync:SetTarget(cframe)
	self._backedUpCFrames = {}
    self._targetCFrame = cframe
end

function Desync:ClearTarget()
    self._targetCFrame = nil
	self._isShouldClean = true
end

function Desync:_updateLoop()
    if not self._targetCFrame then
		if self._isShouldClean then
			self._isShouldClean = false
			local character = LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			
			local shouldMove = hrp.AssemblyLinearVelocity.Magnitude < 0.01
			
			if shouldMove then
				local rv = Vector3.new(math.random(-1, 1)/100, math.random(-1, 1)/100, math.random(-1, 1)/100)
				humanoid:Move(rv, true)
			end
		end
		return
	end
    
    local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp or not humanoid then return end
    
    if not self._backedUpCFrames then
        self._backedUpCFrames = {}
    end
    table.clear(self._backedUpCFrames)
    
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            self._backedUpCFrames[part] = part.CFrame
        end
    end
    
	local shouldMove = hrp.AssemblyLinearVelocity.Magnitude < 0.01
	
    hrp.CFrame = self._targetCFrame

    RunService.PreRender:Wait()
    if shouldMove then
		local rv = Vector3.new(math.random(-1, 1)/100, math.random(-1, 1)/100, math.random(-1, 1)/100)
		humanoid:Move(rv, true)
	end
	
    hrp.CFrame = self._backedUpCFrames[hrp]
end

function Desync:_hookMetatable()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    
    self._oldIndex = mt.__index
    local selfRef = self
    
    mt.__index = newcclosure(function(obj, key)
        if not checkcaller() and selfRef._targetCFrame and key == "CFrame" then
            local character = LocalPlayer.Character

            if character then
                local hum = character:FindFirstChild("Humanoid")
                
                if hum and hum.Health > 0 then
					if not selfRef._backedUpCFrames then print("NO") end
					local backedUpCFrame = selfRef._backedUpCFrames and selfRef._backedUpCFrames[obj]
					if backedUpCFrame then
						return backedUpCFrame
					end
                end
            end
        end
        
        if selfRef._oldIndex then
            local success, result = pcall(selfRef._oldIndex, obj, key)
            if success then
                return result
            end
        end
        
        return nil
    end)
    
    setreadonly(mt, true)
end

function Desync:_unhookMetatable()
    if self._oldIndex then
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        mt.__index = self._oldIndex
        setreadonly(mt, true)
        self._oldIndex = nil
    end
end

function Desync:Start()
    if self._isActive then return end
    self._isActive = true
    
    self._connection = RunService.Heartbeat:Connect(function()
        self:_updateLoop()
    end)
    
    self:_hookMetatable()
end

function Desync:Stop()
    if not self._isActive then return end
    self._isActive = false
    self._targetCFrame = nil
    
    if self._backedUpCFrames then
        table.clear(self._backedUpCFrames)
    end
    
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    
    self:_unhookMetatable()
end

return Desync
