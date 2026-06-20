local Desync = {}
Desync.__index = Desync

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

function Desync.new()
    local self = setmetatable({}, Desync)
    
    self._targetCFrame = nil
    self._backedUpCFrames = {}
    self._realVelocity = nil
    self._isActive = false
    self._connection = nil
    self._oldIndex = nil
    
    return self
end

function Desync:SetTarget(cframe)
    self._targetCFrame = cframe
end

function Desync:ClearTarget()
    self._targetCFrame = nil
end

function Desync:_updateLoop()
    if not self._targetCFrame then return end
    
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    table.clear(self._backedUpCFrames)
    
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            self._backedUpCFrames[part] = part.CFrame
        end
    end
    
    self._realVelocity = hrp.AssemblyLinearVelocity
    
    local forceVelocity = Vector3.new(0, -338, 0) + Vector3.new(
        math.random(-10, 10) / 100, 
        0, 
        math.random(-10, 10) / 100
    )

    hrp.CFrame = self._targetCFrame
    hrp.AssemblyLinearVelocity = forceVelocity
    
    RunService.RenderStepped:Wait()
    
    hrp.CFrame = self._backedUpCFrames[hrp]
    hrp.AssemblyLinearVelocity = self._realVelocity
end

function Desync:_hookMetatable()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    
    self._oldIndex = mt.__index
    local selfRef = self
    
    mt.__index = newcclosure(function(obj, key)
        if not checkcaller() and selfRef._targetCFrame and key == "CFrame" then
            local character = LocalPlayer.Character
            local hum = character and character:FindFirstChild("Humanoid")
            
            if hum and hum.Health > 0 then
                local backedUpCFrame = selfRef._backedUpCFrames[obj]
                if backedUpCFrame then
                    return backedUpCFrame
                end
            end
        end
        
        return selfRef._oldIndex(obj, key)
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
    self._realVelocity = nil
    table.clear(self._backedUpCFrames)
    
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    
    self:_unhookMetatable()
end

return Desync
