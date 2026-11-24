loadstring(game:HttpGet("https://scripts.wabisabi.mom/wabisabi2.lua"))()
local UI = WabiSabi2

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local lp = Players.LocalPlayer

local State = {
    Enabled = false,
    SkipAnim = true,
    ChestESP = true,
    AutoChest = false,
    SetSafeMode = false,
    SetStopMode = false,
    SafeX = 550, SafeY = 500,
    StopX = nil, StopY = nil,
    SkipDelay = 0.22,
    CastDelay = 0.22,
    ChestDelay = 0.35,
    NearTolerance = 9,
    ClickCooldown = 0.14,
    Status = "Idle"
}

local Win = UI:Window({
    Title = "ICE FISHING // +GEMS",
    SubTitle = "Wabi Sabi 2",
    IntroText = "ICE FISHING",
    ToggleKey = "Insert",
    Config = true
})

local MainTab = Win:Tab("Fishing & Farm")
MainTab:Section("Automation")

local CatchToggle = MainTab:Toggle("Auto-Catch [F1]", false, function(on)
    State.Enabled = on
end)

local SkipToggle = MainTab:Toggle("Skip Animation", true, function(on)
    State.SkipAnim = on
end)

local EspToggle = MainTab:Toggle("Gem & Chest ESP", true, function(on)
    State.ChestESP = on
end)

local FarmToggle = MainTab:Toggle("Farm Gems & Chests [F5]", false, function(on)
    State.AutoChest = on
end)

MainTab:Section("Live Monitor")
local StatusLabel = MainTab:Label("Status: Idle")

local PosTab = Win:Tab("Positions & Delays")
PosTab:Section("Screen Coordinates")

local SafeLabel = PosTab:Label("Safe Pos: 550, 500")
PosTab:Button("Set Safe Pos [F2]", function()
    State.SetSafeMode = true
    State.SetStopMode = false
    UI:Notify("Safe Pos", "Click anywhere on main screen", 2.5)
end)

local StopLabel = PosTab:Label("Stop Pos: AUTO")
PosTab:Button("Set Stop Pos [F3]", function()
    State.SetStopMode = true
    State.SetSafeMode = false
    UI:Notify("Stop Pos", "Click on Stop button position", 2.5)
end)

PosTab:Button("Reset Stop Pos to AUTO", function()
    State.StopX, State.StopY = nil, nil
    StopLabel:Set("Stop Pos: AUTO")
end)

PosTab:Section("Timings")
local SkipSlider = PosTab:Slider("Skip Delay", 0, 2, 0.22, { Suffix = "s", Decimals = 2 })
local CastSlider = PosTab:Slider("Cast Delay", 0, 2, 0.22, { Suffix = "s", Decimals = 2 })
local ChestSlider = PosTab:Slider("Chest Delay", 0, 3, 0.35, { Suffix = "s", Decimals = 2 })

Win:SettingsTab()
pcall(function() UI:LoadConfig() end)

local ChestBox = Drawing.new("Square")
ChestBox.Size = Vector2.new(24, 24)
ChestBox.Color = Color3.fromRGB(0, 255, 190)
ChestBox.Filled = false
ChestBox.ZIndex = 8
ChestBox.Visible = false

local ChestLabel = Drawing.new("Text")
ChestLabel.Text = "GEM CHEST"
ChestLabel.Size = 14
ChestLabel.Color = Color3.fromRGB(0, 255, 190)
ChestLabel.Outline = true
ChestLabel.ZIndex = 9
ChestLabel.Visible = false

local lastStatusStr = ""
local function setStatus(txt)
    State.Status = txt
    if txt ~= lastStatusStr then
        lastStatusStr = txt
        pcall(function() StatusLabel:Set("Status: " .. txt) end)
    end
end
local cachedMouse = nil
local function getCursor()
    for _, fn in ipairs({getmousepos, get_mouse_pos, getcursorpos}) do
        if type(fn) == "function" then
            local ok, p = pcall(fn)
            if ok and p and (p.X ~= 0 or p.Y ~= 0) then return p.X, p.Y end
        end
    end
    if not cachedMouse then pcall(function() cachedMouse = lp:GetMouse() end) end
    if cachedMouse then
        local ok, mx, my = pcall(function() return cachedMouse.X, cachedMouse.Y end)
        if ok and mx and my then return mx, my end
    end
    local ok2, loc = pcall(function() return UIS:GetMouseLocation() end)
    return (ok2 and loc) and loc.X or 0, (ok2 and loc) and loc.Y or 0
end

local function moveMouseSafe(x, y)
    local moveFn = mousemoveabs or mouse_move_abs
    if type(moveFn) == "function" then pcall(moveFn, x, y) end
end

local function rawClick(hold)
    if type(isrbxactive) == "function" and not isrbxactive() then return end
    mouse1press()
    task.wait(hold or 0.015)
    mouse1release()
end

local function doCatchClick()
    moveMouseSafe(State.SafeX, State.SafeY)
    rawClick(0.015)
end

local function pressKeyE()
    if type(isrbxactive) == "function" and not isrbxactive() then return end
    if type(keypress) == "function" and type(keyrelease) == "function" then
        keypress(0x45)
        task.wait(0.06)
        keyrelease(0x45)
    elseif type(keyclick) == "function" then
        keyclick(0x45)
    end
end

local function pressJump()
    if type(isrbxactive) == "function" and not isrbxactive() then return end
    if type(keypress) == "function" and type(keyrelease) == "function" then
        keypress(0x20)
        task.wait(0.03)
        keyrelease(0x20)
    elseif type(keyclick) == "function" then
        keyclick(0x20)
    end
end

local function getPartPos(part)
    if not part then return nil end
    local ok1, p1 = pcall(function() return part.Position end)
    if ok1 and p1 and (p1.X ~= 0 or p1.Y ~= 0 or p1.Z ~= 0) then return p1 end
    local ok2, cf = pcall(function() return part.CFrame end)
    if ok2 and cf then return cf.Position end
    return nil
end

local function worldToScreen2D(worldPos)
    for _, fn in ipairs({WorldToScreen, worldtoscreen, world_to_screen}) do
        if type(fn) == "function" then
            local ok, res, vis = pcall(fn, worldPos)
            if ok and res and (type(res) == "userdata" or type(res) == "table") then
                return res.X, res.Y, (vis ~= false and (res.Z == nil or res.Z > 0))
            end
        end
    end

    local cam = workspace.CurrentCamera
    if not cam then return 0, 0, false end

    local ok, cf, fov, vp = pcall(function()
        return cam.CFrame, cam.FieldOfView, cam.ViewportSize
    end)
    if not ok or not cf or not vp then return 0, 0, false end

    local rel = worldPos - cf.Position
    local z = rel:Dot(cf.LookVector)
    if z <= 0.1 then return 0, 0, false end

    local vpW = (vp.X > 0) and vp.X or 1920
    local vpH = (vp.Y > 0) and vp.Y or 1080
    local tanHalf = math.tan(math.rad((fov or 70) * 0.5))
    local aspect = vpW / vpH

    local sx = (vpW * 0.5) * (1 + rel:Dot(cf.RightVector) / (z * tanHalf * aspect))
    local sy = (vpH * 0.5) * (1 - rel:Dot(cf.UpVector) / (z * tanHalf))
    return sx, sy, true
end
local openedChests, chestTries, chestNearSince, chestBackoffUntil = {}, {}, {}, {}
local lastChestETime, lastGemMineTime, lastJumpTime, noJumpUntil = 0, 0, 0, 0

local function makeChestKey(pos)
    return string.format("%.1f_%.1f_%.1f", pos.X, pos.Y, pos.Z)
end

local function getGemChestMain()
    local temp = workspace:FindFirstChild("Temp")
    if not temp then return nil, nil end

    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local rPos = root and getPartPos(root) or nil

    local bestMain, bestChest, bestDist = nil, nil, math.huge
    for _, obj in ipairs(temp:GetChildren()) do
        if string.find(obj.Name, "GemChest", 1, true) and not openedChests[obj] then
            local m = obj:FindFirstChild("Main") or obj:FindFirstChildWhichIsA("BasePart")
            local pos = getPartPos(m)
            if m and pos then
                local d = rPos and (pos - rPos).Magnitude or 0
                if d < bestDist then
                    bestDist, bestMain, bestChest = d, m, obj
                end
            end
        end
    end
    return bestMain, bestChest
end

local function getNearestGemOre()
    local res = workspace:FindFirstChild("Resources")
    if not res then return nil, "No Resources" end
    local gems = res:FindFirstChild("Gems")
    if not gems then return nil, "No Gems folder" end

    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local rPos = root and getPartPos(root) or nil

    local bestMain, bestDist = nil, math.huge
    for _, obj in ipairs(gems:GetDescendants()) do
        if obj.Name == "Main" then
            local pos = getPartPos(obj)
            if pos then
                local d = rPos and (pos - rPos).Magnitude or 0
                if d < bestDist then bestDist, bestMain = d, obj end
            end
        end
    end
    if not bestMain then return nil, "No Main in Gems" end
    return bestMain, nil
end

local function updateESP()
    if not State.ChestESP then
        ChestBox.Visible, ChestLabel.Visible = false, false
        return
    end

    local targetMain = getGemChestMain()
    local labelTitle = "GEM CHEST"
    local espColor = Color3.fromRGB(0, 255, 190)

    if not targetMain then
        targetMain = getNearestGemOre()
        labelTitle = "GEM ORE"
        espColor = Color3.fromRGB(210, 110, 255)
    end

    if not targetMain then
        ChestBox.Visible, ChestLabel.Visible = false, false
        return
    end

    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local pos = getPartPos(targetMain)
    if pos then
        local sx, sy, onScreen = worldToScreen2D(pos + Vector3.new(0, 2, 0))
        if onScreen then
            local distStr = ""
            local rPos = getPartPos(root)
            if rPos then distStr = string.format(" [%.0fm]", (pos - rPos).Magnitude) end
            ChestBox.Color = espColor
            ChestBox.Position = Vector2.new(sx - 12, sy - 12)
            ChestBox.Visible = true
            ChestLabel.Color = espColor
            ChestLabel.Text = labelTitle .. distStr
            ChestLabel.Position = Vector2.new(sx - 38, sy - 28)
            ChestLabel.Visible = true
            return
        end
    end
    ChestBox.Visible, ChestLabel.Visible = false, false
end
local walkingW, walkingS, strafeKey, holdingRMB = false, false, nil, false

local function stopWalking()
    if walkingW then
        walkingW = false
        if type(keyrelease) == "function" then pcall(keyrelease, 0x57) end
    end
    if walkingS then
        walkingS = false
        if type(keyrelease) == "function" then pcall(keyrelease, 0x53) end
    end
    if strafeKey then
        if type(keyrelease) == "function" then pcall(keyrelease, strafeKey) end
        strafeKey = nil
    end
    if holdingRMB then
        holdingRMB = false
        if type(mouse2release) == "function" then pcall(mouse2release) end
        moveMouseSafe(State.SafeX, State.SafeY)
    end
end

local function recoverFocusOnMainScreen()
    stopWalking()
    setStatus("Recovering Focus...")
    moveMouseSafe(State.SafeX, State.SafeY)
    task.wait(0.08)
    if type(mouse1press) == "function" and type(mouse1release) == "function" then
        pcall(mouse1press)
        task.wait(0.04)
        pcall(mouse1release)
    end
    task.wait(0.15)
    moveMouseSafe(State.SafeX, State.SafeY)
end

local function steerToPoint(targetPos)
    if walkingS then
        walkingS = false
        if type(keyrelease) == "function" then pcall(keyrelease, 0x53) end
    end
    if strafeKey then
        if type(keyrelease) == "function" then pcall(keyrelease, strafeKey) end
        strafeKey = nil
    end

    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local cam = workspace.CurrentCamera
    local rPos = getPartPos(root)
    if not rPos or not cam then return end

    local active = (type(isrbxactive) ~= "function") or isrbxactive()
    if active then
        local flatTarget = Vector3.new(targetPos.X, rPos.Y, targetPos.Z)
        local okCam, lookVec = pcall(function() return cam.CFrame.LookVector end)
        if okCam and lookVec then
            local toTarget = (flatTarget - rPos).Unit
            local flatLook = Vector3.new(lookVec.X, 0, lookVec.Z)
            if flatLook.Magnitude > 0.01 then
                flatLook = flatLook.Unit
                local crossY = flatLook.X * toTarget.Z - flatLook.Z * toTarget.X
                local dot = flatLook.X * toTarget.X + flatLook.Z * toTarget.Z
                local angle = math.atan2(crossY, dot)

                local relFn = mousemoverel or mouse_move_rel
                if math.abs(angle) > 0.04 and type(relFn) == "function" then
                    if not holdingRMB and type(mouse2press) == "function" then
                        moveMouseSafe(State.SafeX, State.SafeY)
                        pcall(mouse2press)
                        holdingRMB = true
                    end
                    local turnPx = math.min(90, math.max(-90, angle * 220))
                    pcall(relFn, turnPx, 0)
                elseif holdingRMB and type(mouse2release) == "function" then
                    pcall(mouse2release)
                    holdingRMB = false
                    moveMouseSafe(State.SafeX, State.SafeY)
                end
            end
        end
    else
        if holdingRMB and type(mouse2release) == "function" then
            pcall(mouse2release)
            holdingRMB = false
        end
    end

    if type(keypress) == "function" then
        pcall(keypress, 0x57)
        walkingW = true
    end
end

local function goToChest(mainPart, chestModel)
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local rPos = getPartPos(root)
    local targetPos = getPartPos(mainPart)
    if not rPos or not targetPos then return end

    local now = tick()
    local cKey = makeChestKey(targetPos)

    if chestBackoffUntil[cKey] and now < chestBackoffUntil[cKey] then
        if walkingW then
            walkingW = false
            if type(keyrelease) == "function" then pcall(keyrelease, 0x57) end
        end
        if type(keypress) == "function" then
            if not walkingS then
                pcall(keypress, 0x53)
                walkingS = true
            end
            if not strafeKey then
                strafeKey = (math.random(1, 2) == 1) and 0x41 or 0x44
                pcall(keypress, strafeKey)
            end
        end
        setStatus("Sliding off / Backing...")
        return
    else
        if walkingS then
            walkingS = false
            if type(keyrelease) == "function" then pcall(keyrelease, 0x53) end
        end
        if strafeKey then
            if type(keyrelease) == "function" then pcall(keyrelease, strafeKey) end
            strafeKey = nil
        end
    end

    local flatDist = (Vector3.new(targetPos.X, rPos.Y, targetPos.Z) - rPos).Magnitude
    local heightDiff = rPos.Y - targetPos.Y

    if flatDist > 3.8 then
        chestNearSince[cKey] = nil
        setStatus(string.format("Going Chest (%.0fm)...", flatDist))
        steerToPoint(targetPos)
        if now >= noJumpUntil and (now - lastJumpTime) >= 0.45 then
            pressJump()
            lastJumpTime = now
        end
    else
        stopWalking()
        local stuckLimit = (heightDiff > 2.2) and 1.2 or 2.2

        if not chestNearSince[cKey] then
            chestNearSince[cKey] = now
            lastChestETime = 0
        elseif (now - chestNearSince[cKey]) >= stuckLimit then
            chestNearSince[cKey] = nil
            chestBackoffUntil[cKey] = now + 0.85
            noJumpUntil = now + 2.2
            chestTries[cKey] = (chestTries[cKey] or 0) + 1
            if chestTries[cKey] >= 4 and chestModel then
                openedChests[chestModel] = true
            end
            return
        end

        setStatus((heightDiff > 2.2) and "On Top -> Adjusting..." or "Chest Delay / [E]...")
        if (now - lastChestETime) >= math.max(0.1, State.ChestDelay) then
            if lastChestETime == 0 and State.ChestDelay > 0 then
                task.wait(State.ChestDelay)
            end
            pressKeyE()
            lastChestETime = tick()
        end
    end
end

local function goToGemOre(gemMain)
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local rPos = getPartPos(root)
    local targetPos = getPartPos(gemMain)
    if not rPos or not targetPos then return end

    local dist = (Vector3.new(targetPos.X, rPos.Y, targetPos.Z) - rPos).Magnitude
    if dist > 4.5 then
        lastGemMineTime = 0
        setStatus(string.format("Going Gem (%.0fm)...", dist))
        steerToPoint(targetPos)
    else
        stopWalking()
        setStatus("Mining Gem [E]...")
        if (tick() - lastGemMineTime) >= 2.5 then
            pressKeyE()
            lastGemMineTime = tick()
        end
    end
end

local function skipAndRecast()
    setStatus(string.format("Skip Delay (%.2fs)", State.SkipDelay))
    if State.SkipDelay > 0 then task.wait(State.SkipDelay) end

    if State.StopX and State.StopY then
        moveMouseSafe(State.StopX, State.StopY)
        task.wait(0.04)
        rawClick(0.04)
    else
        local pgui = lp:FindFirstChild("PlayerGui")
        local stopGui = pgui and pgui:FindFirstChild("StopButton")
        local frame = stopGui and stopGui:FindFirstChild("Frame")
        local btn = frame and frame:FindFirstChild("Button")
        if btn then
            local pos = btn.AbsolutePosition
            if pos and (pos.X > 0 or pos.Y > 0) then
                local insetY = 36
                pcall(function()
                    local g = GuiService:GetGuiInset()
                    if g and g.Y > 0 then insetY = g.Y end
                end)
                moveMouseSafe(pos.X + 95, pos.Y + insetY + 25)
                task.wait(0.04)
                rawClick(0.04)
            end
        end
    end

    task.wait(0.04)
    moveMouseSafe(State.SafeX, State.SafeY)
    setStatus(string.format("Cast Delay (%.2fs)", State.CastDelay))
    if State.CastDelay > 0 then task.wait(State.CastDelay) end

    setStatus("Recasting [E]...")
    pressKeyE()
    task.wait(0.55)
end
local prev = { m1 = false, f1 = false, f2 = false, f3 = false, f5 = false, click = 0 }
local activeTargetObj, activeTargetSince = nil, 0
local STUCK_TIMEOUT = 360

local function resetChestTracking()
    openedChests, chestTries, chestNearSince, chestBackoffUntil = {}, {}, {}, {}
    lastChestETime, lastGemMineTime = 0, 0
    activeTargetObj, activeTargetSince = nil, 0
end

local function checkTargetTimeout(targetObj)
    local now = tick()
    if targetObj ~= activeTargetObj then
        activeTargetObj = targetObj
        activeTargetSince = now
        return false
    end
    if activeTargetSince > 0 and (now - activeTargetSince) >= STUCK_TIMEOUT then
        activeTargetSince = now
        recoverFocusOnMainScreen()
        return true
    end
    return false
end

local function syncUIAndHotkeys()
    pcall(function()
        State.Enabled = CatchToggle:Get()
        State.SkipAnim = SkipToggle:Get()
        State.ChestESP = EspToggle:Get()
        local newFarm = FarmToggle:Get()
        if newFarm ~= State.AutoChest then
            State.AutoChest = newFarm
            if newFarm then resetChestTracking() else stopWalking() end
        end
        State.SkipDelay = SkipSlider:Get()
        State.CastDelay = CastSlider:Get()
        State.ChestDelay = ChestSlider:Get()
    end)

    local mx, my = getCursor()
    local hasKey = (type(iskeypressed) == "function")
    local m1 = hasKey and iskeypressed(0x01) or false

    if m1 and not prev.m1 then
        if State.SetSafeMode then
            State.SafeX, State.SafeY, State.SetSafeMode = mx, my, false
            pcall(function() SafeLabel:Set(string.format("Safe Pos: %d, %d", math.floor(mx), math.floor(my))) end)
            UI:Notify("Safe Pos", "Saved: " .. math.floor(mx) .. ", " .. math.floor(my), 2)
        elseif State.SetStopMode then
            State.StopX, State.StopY, State.SetStopMode = mx, my, false
            pcall(function() StopLabel:Set(string.format("Stop Pos: %d, %d", math.floor(mx), math.floor(my))) end)
            UI:Notify("Stop Pos", "Saved: " .. math.floor(mx) .. ", " .. math.floor(my), 2)
        end
    end
    prev.m1 = m1

    if hasKey then
        local f1Down = iskeypressed(0x70)
        if f1Down and not prev.f1 then
            State.Enabled = not State.Enabled
            pcall(function() CatchToggle:Set(State.Enabled) end)
        end
        prev.f1 = f1Down

        local f2Down = iskeypressed(0x71)
        if f2Down and not prev.f2 then
            State.SetSafeMode, State.SetStopMode = not State.SetSafeMode, false
            if State.SetSafeMode then UI:Notify("Safe Pos", "Click anywhere on main screen", 2.5) end
        end
        prev.f2 = f2Down

        local f3Down = iskeypressed(0x72)
        if f3Down and not prev.f3 then
            State.SetStopMode, State.SetSafeMode = not State.SetStopMode, false
            if State.SetStopMode then UI:Notify("Stop Pos", "Click on Stop button position", 2.5) end
        end
        prev.f3 = f3Down

        local f5Down = iskeypressed(0x74)
        if f5Down and not prev.f5 then
            State.AutoChest = not State.AutoChest
            pcall(function() FarmToggle:Set(State.AutoChest) end)
            if State.AutoChest then resetChestTracking() else stopWalking() end
        end
        prev.f5 = f5Down
    end
end

local function mainStep()
    syncUIAndHotkeys()
    updateESP()

    if State.AutoChest then
        local chestMain, chestModel = getGemChestMain()
        if chestMain then
            checkTargetTimeout(chestMain)
            goToChest(chestMain, chestModel)
            return
        else
            local gemMain, errReason = getNearestGemOre()
            if gemMain then
                local char = lp.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local rPos = getPartPos(root)
                local gPos = getPartPos(gemMain)
                if rPos and gPos and (Vector3.new(gPos.X, rPos.Y, gPos.Z) - rPos).Magnitude <= 4.5 then
                    activeTargetObj, activeTargetSince = gemMain, tick()
                else
                    checkTargetTimeout(gemMain)
                end
                goToGemOre(gemMain)
                return
            else
                activeTargetObj, activeTargetSince = nil, 0
                stopWalking()
                setStatus(errReason or "No Chests / Gems")
                return
            end
        end
    else
        activeTargetObj, activeTargetSince = nil, 0
        stopWalking()
    end

    if State.Enabled then
        local pgui = lp:FindFirstChild("PlayerGui")
        local fg = pgui and pgui:FindFirstChild("FishGameTemplate")
        if fg then
            setStatus("Fishing...")
            local main = fg:FindFirstChild("Main")
            local tf = main and main:FindFirstChild("TargetFrame")
            local targetLine = tf and tf:FindFirstChild("TargetLine")
            local target = tf and tf:FindFirstChild("Target")
            local perfect = target and target:FindFirstChild("Perfect")

            if targetLine and target and perfect then
                local prevY, lastPerfY = targetLine.AbsolutePosition.Y, 0
                local activeFrames, miss = 0, 0
                while State.Enabled and miss < 6 do
                    updateESP()
                    local okAlive, alive = pcall(function() return fg.Parent ~= nil end)
                    if not okAlive or not alive then
                        miss = miss + 1
                    else
                        miss = 0
                        local okPos, currY, targetTopY, perfTopY = pcall(function()
                            return targetLine.AbsolutePosition.Y, target.AbsolutePosition.Y, perfect.AbsolutePosition.Y
                        end)
                        local now = tick()

                        if okPos and currY > 0 and perfTopY > 0 and targetTopY > 0 then
                            activeFrames = activeFrames + 1
                            if prevY > 0 then
                                if lastPerfY > 0 and math.abs(perfTopY - lastPerfY) > 6 then prev.click = 0 end
                                local offset = math.min(14, math.max(3, (perfTopY - targetTopY) * 0.3))
                                local perfCenterY = perfTopY + offset
                                if (prevY <= perfCenterY and currY >= perfCenterY) or (prevY >= perfCenterY and currY <= perfCenterY) or math.abs(currY - perfCenterY) <= State.NearTolerance then
                                    if (now - prev.click) >= State.ClickCooldown then
                                        doCatchClick()
                                        prev.click = tick()
                                        lastPerfY = perfTopY
                                    end
                                end
                            end
                        end
                        if okPos then prevY = currY end
                    end
                    if type(iskeypressed) == "function" and iskeypressed(0x70) and not prev.f1 then
                        State.Enabled, prev.f1 = false, true
                        pcall(function() CatchToggle:Set(false) end)
                        break
                    end
                    task.wait()
                end
                if State.Enabled and activeFrames >= 25 and State.SkipAnim then
                    skipAndRecast()
                end
            end
        else
            setStatus("Waiting for bite...")
        end
    else
        setStatus("Paused [F1]")
    end
end

while true do
    local ok, err = pcall(mainStep)
    if not ok then
        warn("[Matcha Error]: " .. tostring(err))
    end
    task.wait(0.02)
end
