--[[
    Auto 1-700 Rebirth + Select Farm  |  CLEAN REWRITE
    Logic giữ nguyên từ bản gốc:
      Place 3177438863 -> Bandit / Rebirth / Upgrade / Brawly -> Crimson
      Place 7040546583 -> Calci Army + LockOn + Skill101 + Rebirth
    Fix:
      - Load UI an toàn (pcall)
      - Không còn Library nil
      - Toggle ID không trùng
      - Không còn anti-fall / remote / function trùng lặp
]]

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------
local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")

local LP = Players.LocalPlayer

----------------------------------------------------------------
-- LOAD OBSIDIAN UI (safe)
----------------------------------------------------------------
local Obsidian
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"
        ))()
    end)
    if not ok or type(result) ~= "table" then
        warn("[Auto1-700] Không load được Obsidian UI:", result)
        return
    end
    Obsidian = result
end

local Window = Obsidian:CreateWindow({
    Title   = "Auto 1-700 Rebirth",
    Footer  = "Clean Rewrite",
    Center  = true,
    AutoShow= true,
})

local TabFarm   = Window:AddTab("Farm", "home")
local BoxMain   = TabFarm:AddLeftGroupbox("Auto 1-700")
local BoxUtil   = TabFarm:AddLeftGroupbox("Utility")
local BoxSelect = TabFarm:AddRightGroupbox("Select Farm")
local BoxSkill  = TabFarm:AddRightGroupbox("Skills")

----------------------------------------------------------------
-- GLOBAL STATE
----------------------------------------------------------------
_G.Auto1_700 = false

local MainThread, ResetThread
local SafeCFrame
local AntiVoidThread
local AntiFallConn

local VOID_Y         = -100
local FLOAT_Y_OFFSET = 8
local RESET_INTERVAL = 20 * 60  -- 20 phút

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------
local function GetRoot()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(model)
    return model and model:FindFirstChildOfClass("Humanoid")
end

local function GetMobRoot(mob)
    if not mob then return nil end
    return mob:FindFirstChild("HumanoidRootPart")
        or mob.PrimaryPart
        or mob:FindFirstChildWhichIsA("BasePart")
end

local function WaitForCharacter()
    if not _G.Auto1_700 then return nil end
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then
        return char, hum
    end
    char = LP.CharacterAdded:Wait()
    if not _G.Auto1_700 then return nil end
    hum = char:WaitForChild("Humanoid", 10)
    return char, hum
end

-- Knit path helper (game có thể đổi version package)
local function GetKnitService(serviceName, remoteType, remoteName)
    local ok, result = pcall(function()
        local packages = ReplicatedStorage:WaitForChild("Packages", 5)
        local index    = packages:WaitForChild("_Index", 5)
        -- tìm folder knit bất kỳ version
        local knitFolder
        for _, child in ipairs(index:GetChildren()) do
            if child.Name:find("sleitnick_knit") then
                knitFolder = child
                break
            end
        end
        if not knitFolder then
            knitFolder = index:WaitForChild("sleitnick_knit@1.4.7", 3)
        end
        return knitFolder
            :WaitForChild("knit", 5)
            :WaitForChild("Services", 5)
            :WaitForChild(serviceName, 5)
            :WaitForChild(remoteType, 5)
            :WaitForChild(remoteName, 5)
    end)
    return ok and result or nil
end

local function FireSkill(skillId, aimPos, cf)
    local remote = ReplicatedStorage:FindFirstChild("Remotes")
        and ReplicatedStorage.Remotes:FindFirstChild("SkillRemote")
    if not remote then return end
    local root = GetRoot()
    if not root then return end
    cf = cf or root.CFrame
    pcall(function()
        remote:FireServer({
            Camera  = workspace.CurrentCamera and workspace.CurrentCamera.CFrame or cf,
            SkillId = tostring(skillId),
            Began   = true,
            CFrame  = cf,
            ["Typ\208\181"] = 1,
            Aim     = aimPos or cf.Position,
        })
    end)
end

----------------------------------------------------------------
-- ANTI VOID + ANTI FALL
----------------------------------------------------------------
local function StartAntiVoid()
    if AntiVoidThread then return end
    AntiVoidThread = task.spawn(function()
        while _G.Auto1_700 do
            local root = GetRoot()
            if root then
                local pos = root.Position
                local vel = root.AssemblyLinearVelocity
                if pos.Y > VOID_Y and pos.Y < 100000 and vel.Magnitude < 1000 then
                    SafeCFrame = root.CFrame
                end
                if pos.Y <= VOID_Y then
                    local recovery = SafeCFrame
                    if not recovery then
                        if game.PlaceId == 7040546583 then
                            recovery = CFrame.new(-1028.61804, 66.1857834, -1514.43213)
                        else
                            recovery = CFrame.new(2034.02405, 1154.9751, -122.715225)
                        end
                    end
                    root.AssemblyLinearVelocity  = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    root.CFrame = recovery + Vector3.new(0, 4, 0)
                    task.wait(0.2)
                end
            end
            task.wait(0.05)
        end
        AntiVoidThread = nil
    end)
end

local function StopAntiVoid()
    if AntiVoidThread then
        pcall(task.cancel, AntiVoidThread)
        AntiVoidThread = nil
    end
    SafeCFrame = nil
end

local function StartAntiFall()
    if AntiFallConn then return end
    AntiFallConn = RunService.Heartbeat:Connect(function()
        if not _G.Auto1_700 then return end
        local root = GetRoot()
        if not root then return end
        if root.Position.Y < 0 and SafeCFrame then
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = SafeCFrame + Vector3.new(0, FLOAT_Y_OFFSET, 0)
        end
        -- chặn rơi tự do
        local v = root.AssemblyLinearVelocity
        if v.Y < -5 then
            root.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
        end
    end)
end

local function StopAntiFall()
    if AntiFallConn then
        AntiFallConn:Disconnect()
        AntiFallConn = nil
    end
end

----------------------------------------------------------------
-- RESET WATCHER (mỗi 20 phút)
----------------------------------------------------------------
local function StartResetWatcher()
    if ResetThread then return end
    ResetThread = task.spawn(function()
        while _G.Auto1_700 do
            local remaining = RESET_INTERVAL
            while _G.Auto1_700 and remaining > 0 do
                local step = math.min(1, remaining)
                task.wait(step)
                remaining -= step
            end
            if not _G.Auto1_700 then break end
            local char = LP.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                print("🔄 Auto 1-700: Reset sau 20 phút")
                hum.Health = 0
            end
            if _G.Auto1_700 then task.wait(3) end
        end
        ResetThread = nil
    end)
end

local function StopResetWatcher()
    if ResetThread then
        pcall(task.cancel, ResetThread)
        ResetThread = nil
    end
end

----------------------------------------------------------------
-- PLACE 3177438863  (Bandit → Rebirth → Brawly → Crimson)
----------------------------------------------------------------
local function RunPlace3177438863()
    if not _G.Auto1_700 then return end
    if not WaitForCharacter() then return end

    local SKILL_DELAY    = 0.25
    local TWEEN_SPEED    = 180
    local MIN_STRENGTH   = 200000
    local MIN_REBIRTH    = 2
    local HIGH_STRENGTH  = 60000000
    local TARGET_REBIRTH = 50
    local WAIT_POS = Vector3.new(2034.02405, 1149.9751, -122.715225)

    local SkillRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SkillRemote")
    local RebirthRemote = GetKnitService("PlayerLevelService", "RF", "RequestRebirth")
    local PromptRemote  = GetKnitService("PromptService", "RE", "Prompt")

    local Stats    = LP:WaitForChild("Stats")
    local Strength = Stats:WaitForChild("Strength")
    local Rebirth  = Stats:WaitForChild("Rebirth")

    local function findMob(name)
        local folder = workspace:FindFirstChild("World Mobs")
        folder = folder and folder:FindFirstChild("Mobs")
        if not folder then return nil end
        for _, mob in ipairs(folder:GetChildren()) do
            if not _G.Auto1_700 then return nil end
            if mob.Name == name then
                local hum = GetHumanoid(mob)
                if hum and hum.Health > 0 then
                    return mob
                end
            end
        end
        return nil
    end

    local function tweenTo(cf)
        if not _G.Auto1_700 then return false end
        local root = GetRoot()
        if not root then return false end
        local dist = (root.Position - cf.Position).Magnitude
        local dur  = math.max(dist / TWEEN_SPEED, 0.05)
        local tw = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = cf})
        tw:Play()
        while tw.PlaybackState == Enum.PlaybackState.Playing do
            if not _G.Auto1_700 then tw:Cancel() return false end
            task.wait()
        end
        return true
    end

    local function tweenAboveMob(mob)
        local mobRoot = GetMobRoot(mob)
        if not mobRoot then return false end
        if mobRoot.Position.Y <= VOID_Y or mobRoot.Position.Y > 100000 then
            return false
        end
        local pos = mobRoot.Position + Vector3.new(0, 8, 0)
        return tweenTo(CFrame.lookAt(pos, mobRoot.Position))
    end

    local function attackMob(mob)
        if not _G.Auto1_700 then return end
        local root = GetRoot()
        local mobRoot = GetMobRoot(mob)
        if not root or not mobRoot then return end
        local target = mobRoot.Position
        local above  = target + Vector3.new(0, 8, 0)
        local cf     = CFrame.lookAt(above, target)
        root.CFrame  = cf
        pcall(function()
            SkillRemote:FireServer({
                Camera  = cf,
                SkillId = "1",
                Began   = true,
                CFrame  = cf,
                ["Typ\208\181"] = 1,
                Aim     = target,
            })
        end)
    end

    local function farmMob(name)
        local currentMob = nil
        while _G.Auto1_700 and game.PlaceId == 3177438863 do
            local mob = findMob(name)
            if not mob then return false end
            if currentMob ~= mob then
                currentMob = mob
                if not tweenAboveMob(mob) then return false end
            end
            local hum = GetHumanoid(mob)
            if not hum or hum.Health <= 0 then
                currentMob = nil
            else
                attackMob(mob)
                task.wait(SKILL_DELAY)
            end
        end
        return false
    end

    local function doRebirthUntil(target)
        if not RebirthRemote then return false end
        local lastValue = Rebirth.Value
        local noChange  = 0
        while _G.Auto1_700 and game.PlaceId == 3177438863 and Rebirth.Value < target do
            pcall(function() RebirthRemote:InvokeServer(true) end)
            task.wait(0.2)
            if Rebirth.Value == lastValue then
                noChange += 1
            else
                lastValue = Rebirth.Value
                noChange  = 0
            end
            if noChange >= 10 then return false end
        end
        return Rebirth.Value >= target
    end

    local function upgrade(path)
        if not PromptRemote or not _G.Auto1_700 then return end
        pcall(function()
            PromptRemote:FireServer({
                Timer       = 15,
                Description = "Upgrade Energy Blast>" .. path .. " for 1 Skill Points?",
                LeftButton  = "Upgrade",
                PathName    = path,
                Prompt      = "UpgradeSkill",
                RightButton = "Return",
                SkillId     = "101",
            }, "Upgrade")
        end)
    end

    local function upgradeOneMinute()
        local finish = os.clock() + 60
        while _G.Auto1_700 and game.PlaceId == 3177438863 and os.clock() < finish do
            upgrade("Path1")
            task.wait(0.5)
            upgrade("Path2")
            task.wait(0.5)
        end
    end

    local function crimson()
        if not PromptRemote or not _G.Auto1_700 then return end
        pcall(function()
            PromptRemote:FireServer({
                UniqueTag   = "TeleporterGui",
                Description = "Join World [Crimson Planet]?",
                LeftButton  = "Join",
                Timer       = 30,
                Prompt      = "TeleportDirect",
                RightButton = "Cancel",
                PlaceDataId = 2,
            }, "Join")
        end)
    end

    -- Main loop place 1
    while _G.Auto1_700 and game.PlaceId == 3177438863 do
        local str = tonumber(Strength.Value) or 0
        local reb = tonumber(Rebirth.Value) or 0

        if reb > 50 then
            crimson()
            task.wait(1)
            break

        elseif str > HIGH_STRENGTH then
            local ok = doRebirthUntil(TARGET_REBIRTH)
            if ok or Rebirth.Value >= TARGET_REBIRTH then
                crimson()
                task.wait(1)
                break
            end

        elseif str >= MIN_STRENGTH and reb >= MIN_REBIRTH then
            local brawly = findMob("Brawly Minion")
            if brawly then
                farmMob("Brawly Minion")
            else
                tweenTo(CFrame.new(WAIT_POS))
                while _G.Auto1_700 and game.PlaceId == 3177438863 do
                    if findMob("Brawly Minion") then break end
                    task.wait(0.25)
                end
            end

        elseif str >= MIN_STRENGTH then
            local before = Rebirth.Value
            doRebirthUntil(999999)
            if _G.Auto1_700 and Rebirth.Value == before then
                upgradeOneMinute()
            end

        else
            farmMob("Bandit")
        end

        task.wait(0.1)
    end
end

----------------------------------------------------------------
-- PLACE 7040546583  (Calci Army + Lock + Skill101 + Rebirth)
----------------------------------------------------------------
local function RunPlace7040546583()
    if not _G.Auto1_700 then return end
    if not WaitForCharacter() then return end

    local SKILL1_DELAY  = 0.25
    local LOCK_DELAY    = 0.25
    local REBIRTH_DELAY = 0.25
    local TWEEN_SPEED   = 180
    local LOCK_RADIUS   = 200
    local WAIT_POS = Vector3.new(-1028.61804, 61.1857834, -1514.43213)

    local SkillRemote  = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SkillRemote")
    local LockOnRemote = GetKnitService("SkillManager", "RE", "LockedOnChanged")
    local RebirthRemote= GetKnitService("PlayerLevelService", "RF", "RequestRebirth")

    local function getCalciList()
        local folder = workspace:FindFirstChild("World Mobs")
        folder = folder and folder:FindFirstChild("Mobs")
        if not folder then return {} end
        local result = {}
        for _, mob in ipairs(folder:GetChildren()) do
            if mob.Name == "Calci Army" then
                local hum  = GetHumanoid(mob)
                local root = GetMobRoot(mob)
                if hum and hum.Health > 0 and root then
                    table.insert(result, mob)
                end
            end
        end
        return result
    end

    local currentTweenTarget = nil

    local function getRandomLockTarget(exclude)
        local root = GetRoot()
        if not root then return nil end
        local list = {}
        for _, mob in ipairs(getCalciList()) do
            if mob ~= exclude then
                local mobRoot = GetMobRoot(mob)
                if mobRoot then
                    local d = (root.Position - mobRoot.Position).Magnitude
                    if d <= LOCK_RADIUS then
                        table.insert(list, mob)
                    end
                end
            end
        end
        if #list == 0 then return nil end
        return list[math.random(1, #list)]
    end

    local function tweenAbove(mob)
        if not _G.Auto1_700 then return false end
        local root = GetRoot()
        local mobRoot = GetMobRoot(mob)
        if not root or not mobRoot then return false end
        if mobRoot.Position.Y <= VOID_Y or mobRoot.Position.Y > 100000 then
            return false
        end
        local position = mobRoot.Position + Vector3.new(0, 8, 0)
        local cf = CFrame.lookAt(position, mobRoot.Position)
        local dist = (root.Position - position).Magnitude
        local dur  = math.max(dist / TWEEN_SPEED, 0.05)
        local tw = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = cf})
        tw:Play()
        while tw.PlaybackState == Enum.PlaybackState.Playing do
            if not _G.Auto1_700 or game.PlaceId ~= 7040546583 then
                tw:Cancel()
                return false
            end
            task.wait()
        end
        return true
    end

    local function tweenWait()
        if not _G.Auto1_700 then return end
        local root = GetRoot()
        if not root then return end
        local dist = (root.Position - WAIT_POS).Magnitude
        local dur  = math.max(dist / TWEEN_SPEED, 0.05)
        local tw = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = CFrame.new(WAIT_POS)})
        tw:Play()
        while tw.PlaybackState == Enum.PlaybackState.Playing do
            if not _G.Auto1_700 or game.PlaceId ~= 7040546583 then
                tw:Cancel()
                return
            end
            task.wait()
        end
    end

    local function skill1(mob)
        if not _G.Auto1_700 then return end
        local root = GetRoot()
        local mobRoot = GetMobRoot(mob)
        if not root or not mobRoot then return end
        local target = mobRoot.Position
        local above  = target + Vector3.new(0, 8, 0)
        local cf     = CFrame.lookAt(above, target)
        root.CFrame  = cf
        pcall(function()
            SkillRemote:FireServer({
                Camera  = cf,
                SkillId = "1",
                Began   = true,
                CFrame  = cf,
                ["Typ\208\181"] = 1,
                Aim     = target,
            })
        end)
    end

    local function lockSkill101(mob)
        if not _G.Auto1_700 then return end
        local mobRoot = GetMobRoot(mob)
        local root = GetRoot()
        if not mobRoot or not root then return end
        local target = mobRoot.Position
        local above  = target + Vector3.new(0, 8, 0)
        local cf     = CFrame.lookAt(above, target)
        if LockOnRemote then
            pcall(function() LockOnRemote:FireServer(mob) end)
        end
        pcall(function()
            SkillRemote:FireServer({
                Camera  = cf,
                SkillId = "101",
                Began   = true,
                CFrame  = cf,
                ["Typ\208\181"] = 1,
                Aim     = target,
            })
        end)
    end

    local calciRunning = true

    -- Thread 1: tween + skill 1
    task.spawn(function()
        while _G.Auto1_700 and calciRunning and game.PlaceId == 7040546583 do
            local list = getCalciList()
            if #list == 0 then
                currentTweenTarget = nil
                tweenWait()
                task.wait(0.1)
            else
                if not currentTweenTarget
                    or not GetHumanoid(currentTweenTarget)
                    or GetHumanoid(currentTweenTarget).Health <= 0
                    or not GetMobRoot(currentTweenTarget) then
                    currentTweenTarget = list[math.random(1, #list)]
                    if not tweenAbove(currentTweenTarget) then break end
                end
                if currentTweenTarget then
                    local hum = GetHumanoid(currentTweenTarget)
                    if hum and hum.Health > 0 then
                        skill1(currentTweenTarget)
                    else
                        currentTweenTarget = nil
                    end
                end
                task.wait(SKILL1_DELAY)
            end
        end
    end)

    -- Thread 2: lock + skill 101
    task.spawn(function()
        while _G.Auto1_700 and calciRunning and game.PlaceId == 7040546583 do
            local target = getRandomLockTarget(currentTweenTarget)
            if target then
                pcall(lockSkill101, target)
            end
            task.wait(LOCK_DELAY)
        end
    end)

    -- Thread 3: auto rebirth
    task.spawn(function()
        while _G.Auto1_700 and calciRunning and game.PlaceId == 7040546583 do
            if RebirthRemote then
                pcall(function() RebirthRemote:InvokeServer(true) end)
            end
            task.wait(REBIRTH_DELAY)
        end
    end)

    while _G.Auto1_700 and game.PlaceId == 7040546583 do
        task.wait(0.25)
    end
    calciRunning = false
end

----------------------------------------------------------------
-- MAIN CONTROLLER
----------------------------------------------------------------
local function StartAuto1700()
    if MainThread then return end
    _G.Auto1_700 = true
    StartAntiVoid()
    StartAntiFall()
    StartResetWatcher()

    MainThread = task.spawn(function()
        while _G.Auto1_700 do
            if not WaitForCharacter() then break end
            local place = game.PlaceId
            if place == 3177438863 then
                RunPlace3177438863()
            elseif place == 7040546583 then
                RunPlace7040546583()
            else
                warn("❌ Auto 1-700: PlaceId không hỗ trợ:", place)
                task.wait(1)
            end
            task.wait(0.25)
        end
        MainThread = nil
    end)
    print("✅ Auto 1-700 Rebirth ON | Reset mỗi 20 phút")
end

local function StopAuto1700()
    _G.Auto1_700 = false
    StopAntiVoid()
    StopAntiFall()
    StopResetWatcher()
    MainThread = nil
    print("🛑 Auto 1-700 Rebirth OFF")
end

----------------------------------------------------------------
-- SELECT FARM
----------------------------------------------------------------
local AutoFarm      = false
local SelectedMob   = nil
local TweenSpeed    = 200
local FarmThread    = nil
local ActiveTween   = nil
local MIN_MOB_Y     = -250
local MAX_MOB_Y     = 1000
local MAX_DIST      = 1000

local LockOnRemoteSF = GetKnitService("SkillManager", "RE", "LockedOnChanged")
local SkillRemoteSF  = ReplicatedStorage:FindFirstChild("Remotes")
    and ReplicatedStorage.Remotes:FindFirstChild("SkillRemote")

local function GetMobList()
    local folder = workspace:FindFirstChild("World Mobs")
    if not folder then return {} end
    local seen, list = {}, {}
    for _, obj in ipairs(folder:GetDescendants()) do
        if obj:IsA("Model") and not seen[obj.Name] then
            local hum = GetHumanoid(obj)
            if hum then
                seen[obj.Name] = true
                table.insert(list, obj.Name)
            end
        end
    end
    table.sort(list)
    return list
end

local function FindMobByName(name)
    if not name then return nil end
    local folder = workspace:FindFirstChild("World Mobs")
    if not folder then return nil end
    for _, obj in ipairs(folder:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == name then
            local hum  = GetHumanoid(obj)
            local root = GetMobRoot(obj)
            if hum and root and hum.Health > 0
                and root.Position.Y > MIN_MOB_Y
                and root.Position.Y <= MAX_MOB_Y then
                return obj
            end
        end
    end
    return nil
end

local function IsSafeMob(mob, root)
    if not mob or not mob.Parent or not root then return false end
    local mr = GetMobRoot(mob)
    if not mr then return false end
    local y = mr.Position.Y
    if y <= MIN_MOB_Y or y > MAX_MOB_Y then return false end
    if (root.Position - mr.Position).Magnitude > MAX_DIST then return false end
    return true
end

local function TweenToMob(mob)
    local root = GetRoot()
    local mr   = GetMobRoot(mob)
    if not root or not mr or not IsSafeMob(mob, root) then return false end
    local pos = mr.Position + Vector3.new(0, 8, 0)
    local cf  = CFrame.lookAt(pos, mr.Position)
    local dist = (root.Position - pos).Magnitude
    local dur  = math.max(dist / TweenSpeed, 0.05)
    if ActiveTween then pcall(function() ActiveTween:Cancel() end) end
    local tw = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = cf})
    ActiveTween = tw
    tw:Play()
    while tw.PlaybackState == Enum.PlaybackState.Playing do
        if not AutoFarm or not IsSafeMob(mob, root) then
            tw:Cancel()
            ActiveTween = nil
            return false
        end
        task.wait()
    end
    ActiveTween = nil
    return true
end

local function LockAndSkill(mob)
    if LockOnRemoteSF then
        pcall(function() LockOnRemoteSF:FireServer(mob) end)
    end
    local mr = GetMobRoot(mob)
    local root = GetRoot()
    if not mr or not root or not SkillRemoteSF then return end
    local target = mr.Position
    local above  = target + Vector3.new(0, 6, 0)
    local cf     = CFrame.lookAt(above, target)
    pcall(function()
        SkillRemoteSF:FireServer({
            Camera  = workspace.CurrentCamera and workspace.CurrentCamera.CFrame or cf,
            SkillId = "101",
            Began   = true,
            CFrame  = cf,
            ["Typ\208\181"] = 1,
            Aim     = target,
        })
        SkillRemoteSF:FireServer({
            Camera  = workspace.CurrentCamera and workspace.CurrentCamera.CFrame or cf,
            SkillId = "1",
            Began   = true,
            CFrame  = cf,
            ["Typ\208\181"] = 1,
            Aim     = target,
        })
    end)
end

----------------------------------------------------------------
-- AUTO TOOLBAR
----------------------------------------------------------------
local AutoToolbar   = false
local SelectedSlot  = 1
local ToolbarThread = nil

local function StartToolbar()
    if ToolbarThread then return end
    local ToolRemote = GetKnitService("ToolService", "RE", "UpdatePlayerToolbarSelection")
    if not ToolRemote then return end
    ToolbarThread = task.spawn(function()
        while AutoToolbar do
            pcall(function() ToolRemote:FireServer(SelectedSlot) end)
            task.wait(0.15)
        end
        ToolbarThread = nil
    end)
end

----------------------------------------------------------------
-- BASIC SKILLS (transform / fusion / beast)
----------------------------------------------------------------
local AutoTransform = false
local AutoFusion    = false
local AutoBeast     = false

local function HasMode()
    local chars = workspace:FindFirstChild("Characters")
    local char  = chars and chars:FindFirstChild(LP.Name)
    return char and char:FindFirstChild("Mode") ~= nil
end

local function HasTechniqueEffect()
    local chars = workspace:FindFirstChild("Characters")
    local char  = chars and chars:FindFirstChild(LP.Name)
    return char and char:FindFirstChild("TechniqueEffect") ~= nil
end

-- Transform (Skill 10)
task.spawn(function()
    while task.wait(1.6) do
        if AutoTransform and not HasMode() then
            FireSkill("10", nil, nil)
        end
    end
end)

-- Fusion (Skill 9) mỗi 9s
task.spawn(function()
    while task.wait(9) do
        if AutoFusion then
            FireSkill("9", nil, nil)
        end
    end
end)

-- Beast / Kaioken (Skill 8) – chỉ khi không có TechniqueEffect
task.spawn(function()
    while task.wait(0.15) do
        if AutoBeast and not HasTechniqueEffect() then
            FireSkill("8", nil, nil)
        end
    end
end)

----------------------------------------------------------------
-- UI TOGGLES / CONTROLS
----------------------------------------------------------------
BoxMain:AddToggle("Auto1700", {
    Text    = "Auto 1-700 Rebirth",
    Default = false,
    Callback = function(v)
        if v then StartAuto1700() else StopAuto1700() end
    end,
})

BoxUtil:AddToggle("AntiFallToggle", {
    Text    = "Anti Fall / Anti Void",
    Default = true,
    Callback = function(v)
        if v then
            if _G.Auto1_700 then
                StartAntiVoid()
                StartAntiFall()
            end
        else
            StopAntiVoid()
            StopAntiFall()
        end
    end,
})

BoxUtil:AddDropdown("ToolbarSlot", {
    Values  = {"1", "2", "3", "4", "5", "6"},
    Default = "1",
    Multi   = false,
    Text    = "Auto Equip Slot",
    Callback = function(v)
        SelectedSlot = tonumber(v) or 1
        AutoToolbar  = true
        StartToolbar()
    end,
})

BoxSelect:AddDropdown("SelectFarmMob", {
    Text    = "Select Mob",
    Values  = GetMobList(),
    Default = nil,
    Multi   = false,
    Callback = function(v)
        SelectedMob = v
    end,
})

BoxSelect:AddSlider("FarmTweenSpeed", {
    Text     = "Tween Speed",
    Default  = 200,
    Min      = 50,
    Max      = 500,
    Rounding = 0,
    Callback = function(v)
        TweenSpeed = v
    end,
})

BoxSelect:AddToggle("SelectAutoFarm", {
    Text    = "Auto Farm Select",
    Default = false,
    Callback = function(v)
        AutoFarm = v
        if not v then
            if ActiveTween then pcall(function() ActiveTween:Cancel() end) end
            ActiveTween = nil
            FarmThread  = nil
            return
        end
        if FarmThread then return end
        FarmThread = task.spawn(function()
            while AutoFarm do
                if not SelectedMob then
                    task.wait(0.5)
                    continue
                end
                local mob = FindMobByName(SelectedMob)
                if not mob then
                    task.wait(0.3)
                    continue
                end
                if not TweenToMob(mob) then
                    task.wait(0.15)
                    continue
                end
                -- farm loop trên mob này
                while AutoFarm and SelectedMob == mob.Name and mob.Parent do
                    local hum = GetHumanoid(mob)
                    local mr  = GetMobRoot(mob)
                    if not hum or hum.Health <= 0 or not mr
                        or not IsSafeMob(mob, GetRoot()) then
                        break
                    end
                    LockAndSkill(mob)
                    task.wait(0.12)
                end
                -- giữ vị trí 0.4s sau khi mob chết
                if AutoFarm then
                    local holdRoot = GetRoot()
                    local holdCF   = holdRoot and holdRoot.CFrame
                    local untilT   = os.clock() + 0.4
                    while AutoFarm and os.clock() < untilT do
                        local r = GetRoot()
                        if r and holdCF then
                            r.CFrame = holdCF
                            r.AssemblyLinearVelocity  = Vector3.zero
                            r.AssemblyAngularVelocity = Vector3.zero
                        end
                        task.wait()
                    end
                end
            end
            FarmThread = nil
        end)
    end,
})

BoxSelect:AddButton({
    Text = "Refresh Mob List",
    Func = function()
        -- Obsidian dropdown không có SetValues chuẩn trên mọi version,
        -- nên chỉ print danh sách mới để user biết.
        local list = GetMobList()
        print("[Select Farm] Mobs hiện tại:", table.concat(list, ", "))
        pcall(function()
            if Obsidian and Obsidian.Notify then
                Obsidian:Notify({
                    Title = "Mob List",
                    Description = #list .. " mobs found (xem F9)",
                    Time = 3,
                })
            end
        end)
    end,
})

BoxSkill:AddToggle("AutoTransform", {
    Text    = "Auto Transform (Skill 10)",
    Default = true,
    Callback = function(v) AutoTransform = v end,
})

BoxSkill:AddToggle("AutoFusion", {
    Text    = "Auto Fusion (Skill 9)",
    Default = false,
    Callback = function(v) AutoFusion = v end,
})

BoxSkill:AddToggle("AutoBeast", {
    Text    = "Auto Beast / Kaioken (Skill 8)",
    Default = false,
    Callback = function(v) AutoBeast = v end,
})

----------------------------------------------------------------
-- DONE
----------------------------------------------------------------
pcall(function()
    if Obsidian and Obsidian.Notify then
        Obsidian:Notify({
            Title       = "Auto 1-700 Clean",
            Description = "Đã load sạch – bật Auto 1-700 Rebirth để farm",
            Time        = 4,
        })
    end
end)

print("✅ Auto 1-700 Clean Rewrite loaded")
