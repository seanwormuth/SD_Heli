-- SD_Heli dev helper
-- F8: print player location/rotation/map, plus diagnostics for ModActor and BP_Heli.
-- NOTE: only plain field reads on struct variables. Calling UFunctions or :ToString() on
-- struct (Transform) values crashes UE4SS natively (pcall can't catch it).

local function fmt3(x, y, z) return string.format("X=%.0f Y=%.0f Z=%.0f", x, y, z) end

local function d3(ax, ay, az, bx, by, bz)
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function safe(label, fn)
    local ok, err = pcall(fn)
    if not ok then print(string.format("[SD_Heli]   %s failed: %s\n", label, tostring(err))) end
end

-- Read a Transform variable field by field. Yaw is derived from the rotation quaternion.
local function showTransform(m, name, px, py, pz)
    local ok, t = pcall(function() return m[name] end)
    if not ok or t == nil then return end
    safe(name, function()
        -- Vector variable: read X/Y/Z directly (field read only; safe).
        local okV, vx = pcall(function() return t.X end)
        if okV and type(vx) == "number" then
            local x, y, z = t.X, t.Y, t.Z
            print(string.format("[SD_Heli]      %s (vector): %s | player distance=%.0f\n",
                name, fmt3(x, y, z), d3(px, py, pz, x, y, z)))
            return
        end
        local tr, q, sc = t.Translation, t.Rotation, t.Scale3D
        local x, y, z = tr.X, tr.Y, tr.Z
        if type(x) ~= "number" then
            print(string.format("[SD_Heli]      %s: unreadable from Lua (got %s) - check it in the editor\n", name, type(x)))
            return
        end
        local yaw = math.deg(math.atan(2 * (q.W * q.Z + q.X * q.Y), 1 - 2 * (q.Y * q.Y + q.Z * q.Z)))
        print(string.format("[SD_Heli]      %s: Loc %s | Yaw=%.0f | Scale %.2f,%.2f,%.2f | player distance=%.0f\n",
            name, fmt3(x, y, z), yaw, sc.X, sc.Y, sc.Z, d3(px, py, pz, x, y, z)))
    end)
end

RegisterKeyBind(Key.F8, function()
    ExecuteInGameThread(function()
        local pc = FindFirstOf("PlayerController")
        if not pc or not pc:IsValid() then print("[SD_Heli] No PlayerController\n") return end
        local pawn = pc.Pawn
        if not pawn or not pawn:IsValid() then print("[SD_Heli] No pawn\n") return end
        local loc = pawn:K2_GetActorLocation()
        local rot = pawn:K2_GetActorRotation()
        local px, py, pz = loc.X, loc.Y, loc.Z
        local world = pawn:GetWorld()
        local map = world and world:IsValid() and world:GetFullName() or "?"
        print(string.format("[SD_Heli] Location %s | Yaw=%.0f | Map=%s\n", fmt3(px, py, pz), rot.Yaw, map))

        local activeSlots = {}
        local mods = FindAllOf("ModActor_C") or {}
        print(string.format("[SD_Heli] ModActor instances: %d\n", #mods))
        for i, m in ipairs(mods) do
            print(string.format("[SD_Heli]   #%d %s\n", i, m:GetFullName()))
            for _, name in ipairs({ "DefaultTransform", "SpawnTransform", "SpawnLocation" }) do
                showTransform(m, name, px, py, pz)
            end
            safe("DebugStep", function()
                local s = m.DebugStep
                if type(s) == "number" then print(string.format("[SD_Heli]      DebugStep = %d\n", s)) end
            end)
            safe("SpawnRadius", function()
                print(string.format("[SD_Heli]      SpawnRadius = %.0f\n", m.SpawnRadius))
            end)
            safe("SpawnedHeli", function()
                local h = m.SpawnedHeli
                print(string.format("[SD_Heli]      SpawnedHeli = %s\n", (h and h:IsValid()) and h:GetFullName() or "None"))
            end)
            safe("LuaManaged", function()
                print(string.format("[SD_Heli]      LuaManaged = %s\n", tostring(m.LuaManaged)))
            end)
            local lastName = ""
            -- per-save slot names (FString variables; ToString is safe on strings, not on structs)
            for _, name in ipairs({ "SaveSlotName", "ActiveSlot" }) do
                safe(name, function()
                    local s = m[name]:ToString()
                    print(string.format("[SD_Heli]      %s = \"%s\"\n", name, s))
                    if name == "SaveSlotName" then lastName = s end
                    -- the idle second ModActor has both empty: skip it
                    if name == "ActiveSlot" and (s ~= "" or lastName ~= "") then activeSlots[#activeSlots + 1] = s end
                end)
            end
        end

        local helis = FindAllOf("BP_Heli_C") or {}
        print(string.format("[SD_Heli] BP_Heli instances: %d\n", #helis))
        for i, h in ipairs(helis) do
            safe("BP_Heli " .. i, function()
                local hl = h:K2_GetActorLocation()
                print(string.format("[SD_Heli]   #%d at %s | distance=%.0f\n", i, fmt3(hl.X, hl.Y, hl.Z),
                    d3(px, py, pz, hl.X, hl.Y, hl.Z)))
            end)
        end

        local dir = (os.getenv("LOCALAPPDATA") or "") .. "\\SurrounDead\\Saved\\SaveGames\\"
        if #activeSlots == 0 then print("[SD_Heli] No ActiveSlot read - nothing to check on disk\n") end
        for _, slot in ipairs(activeSlots) do
            if slot == "" then
                print("[SD_Heli] ActiveSlot is EMPTY - SaveHeli has no slot to write to\n")
            else
                local f = io.open(dir .. slot .. ".sav", "rb")
                if f then
                    local size = f:seek("end"); f:close()
                    print(string.format("[SD_Heli] %s.sav exists (%d bytes)\n", slot, size))
                else
                    print(string.format("[SD_Heli] %s.sav NOT found - the helicopter hasn't been saved for this save yet\n", slot))
                end
            end
        end
    end)
end)

-- Storage placement (see storage.lua).
-- F7: move the invisible cabin box (storage + prompt) to the player's fore/aft position and
--     height, centred across the helicopter, and print the value to put in storage.lua
-- F6: show/hide the cabin box
local storage_visible = false
local function storage_mod()
    local s = package.loaded["storage"]
    if type(s) == "table" then return s end
    print("[SD_Heli] storage.lua isn't loaded\n")
    return nil
end

RegisterKeyBind(Key.F7, function()
    ExecuteInGameThread(function()
        local s = storage_mod(); if not s then return end
        local heli = FindFirstOf("BP_Heli_C")
        local pc = FindFirstOf("PlayerController")
        local pawn = pc and pc.Pawn
        if not heli or not heli:IsValid() or not pawn or not pawn:IsValid() then
            print("[SD_Heli] F7: need the helicopter and the player\n") return
        end
        local p, h = pawn:K2_GetActorLocation(), heli:K2_GetActorLocation()
        local d = { X = p.X - h.X, Y = p.Y - h.Y, Z = p.Z - h.Z }
        local fw, rt, up = heli:GetActorForwardVector(), heli:GetActorRightVector(), heli:GetActorUpVector()
        local off = {
            X = math.floor(d.X * fw.X + d.Y * fw.Y + d.Z * fw.Z + 0.5),
            Y = math.floor(d.X * rt.X + d.Y * rt.Y + d.Z * rt.Z + 0.5),
            Z = math.floor(d.X * up.X + d.Y * up.Y + d.Z * up.Z + 0.5),
        }
        -- the player stands outside: keep their fore/aft position and height, centred across
        off.Y = 0
        s.move_to(off, heli)
        print(string.format("[SD_Heli] F7: cabin box moved. Put this in storage.lua: M.CENTER = { X = %d, Y = %d, Z = %d }\n",
            off.X, off.Y, off.Z))
    end)
end)

RegisterKeyBind(Key.F6, function()
    ExecuteInGameThread(function()
        local s = storage_mod(); if not s then return end
        storage_visible = not storage_visible
        s.set_visible(storage_visible)
        print("[SD_Heli] F6: storage crate " .. (storage_visible and "visible" or "hidden") .. "\n")
    end)
end)

-- F2: collision responses of the cabin box, every part of the helicopter and the nearest game
-- vehicle, per channel (0-31), to find the channel the game's interact trace uses.
-- Response letters: I ignore, O overlap, B block. Channels 14-31 are the game's custom ones.
local function responses(comp)
    local out = {}
    for ch = 0, 31 do
        local ok, r = pcall(function() return comp:GetCollisionResponseToChannel(ch) end)
        out[#out + 1] = (not ok or r == nil) and "?" or ({ [0] = "I", [1] = "O", [2] = "B" })[r] or tostring(r)
    end
    return table.concat(out)
end

local function dump_actor(label, actor)
    if not actor or not actor:IsValid() then print("[SD_Heli] F2: " .. label .. ": none\n") return end
    print("[SD_Heli] F2: " .. label .. ": " .. actor:GetFullName() .. "\n")
    local cls = StaticFindObject("/Script/Engine.PrimitiveComponent")
    local ok, err = pcall(function()
        local comps = actor:K2_GetComponentsByClass(cls)
        -- UE4SS hands the array back either as a TArray or as a plain Lua table
        local list = {}
        if type(comps) == "table" then
            for _, e in ipairs(comps) do list[#list + 1] = e end
        else
            comps:ForEach(function(_, e) list[#list + 1] = e:get() end)
        end
        if #list == 0 then print("[SD_Heli]   no primitive components found\n") end
        for _, c in ipairs(list) do
            -- entries can come wrapped: unwrap with :get() when IsValid isn't callable directly
            local okc, isv = pcall(function() return c:IsValid() end)
            if not okc then
                local okg, inner = pcall(function() return c:get() end)
                if okg and inner then
                    c = inner
                    okc, isv = pcall(function() return c:IsValid() end)
                end
            end
            if okc and isv then
                local name, enabled, profile = "?", "?", "?"
                pcall(function() name = c:GetFName():ToString() end)
                pcall(function() enabled = tostring(c:GetCollisionEnabled()) end)
                pcall(function() profile = c:GetCollisionProfileName():ToString() end)
                print(string.format("[SD_Heli]   %-28s enabled=%s profile=%-20s %s\n", name, enabled, profile, responses(c)))
            else
                print(string.format("[SD_Heli]   (unreadable component: %s, %s)\n", type(c), tostring(isv)))
            end
        end
    end)
    if not ok then print("[SD_Heli]   components unreadable: " .. tostring(err) .. "\n") end
end

RegisterKeyBind(Key.F2, function()
    ExecuteInGameThread(function()
        -- the game's named custom channels (Project Settings > Collision), read from the engine
        local okp, perr = pcall(function()
            local cp = StaticFindObject("/Script/Engine.Default__CollisionProfile")
            if not cp or not cp:IsValid() then error("CollisionProfile not found") end
            local n = 0
            cp.DefaultChannelResponses:ForEach(function(_, e)
                local s = e:get()
                local ch, name, trace, resp = "?", "?", "?", "?"
                pcall(function() ch = tostring(s.Channel) end)
                pcall(function() name = s.Name:ToString() end)
                pcall(function() trace = tostring(s.bTraceType) end)
                pcall(function() resp = tostring(s.DefaultResponse) end)
                print(string.format("[SD_Heli] F2: channel %s = \"%s\" (trace=%s, default response=%s)\n", ch, name, trace, resp))
                n = n + 1
            end)
            if n == 0 then print("[SD_Heli] F2: no custom channels listed\n") end
        end)
        if not okp then print("[SD_Heli] F2: channel names unreadable: " .. tostring(perr) .. "\n") end
        print("[SD_Heli] F2: responses for channels 0-31 in order (I ignore, O overlap, B block)\n")
        local heli = FindFirstOf("BP_Heli_C")
        local s = package.loaded["storage"]
        local box = type(s) == "table" and s.crate() or nil
        -- after a UE4SS reload storage.lua may not have found the crate yet: take the one at the heli
        if (not box) and heli and heli:IsValid() then
            local h = heli:K2_GetActorLocation()
            local bestD = 600
            for _, c in ipairs(FindAllOf("Buildable_StorageCrate_C") or {}) do
                if c:IsValid() then
                    local l = c:K2_GetActorLocation()
                    local d = d3(h.X, h.Y, h.Z, l.X, l.Y, l.Z)
                    if d < bestD then box, bestD = c, d end
                end
            end
        end
        dump_actor("cabin box", box)
        dump_actor("helicopter", heli)
        -- every actor attached to the helicopter (entry trigger, doors, seats...): they sit at the
        -- cabin and can block the interact trace there
        if heli and heli:IsValid() then
            local n = 0
            for _, a in ipairs(FindAllOf("Actor") or {}) do
                local okp, parent = pcall(function() return a:GetAttachParentActor() end)
                if okp and parent and parent:IsValid() and parent:GetAddress() == heli:GetAddress()
                    and not (box and a:GetAddress() == box:GetAddress()) then
                    n = n + 1
                    dump_actor("attached to the heli", a)
                end
            end
            print(string.format("[SD_Heli] F2: %d other actor(s) attached to the heli\n", n))
        end
        -- nearest game vehicle
        local pc = FindFirstOf("PlayerController")
        local pawn = pc and pc:IsValid() and pc.Pawn
        local best, bestD = nil, math.huge
        if pawn and pawn:IsValid() then
            local p = pawn:K2_GetActorLocation()
            for _, v in ipairs(FindAllOf("BP_VehicleMaster_C") or {}) do
                if v:IsValid() then
                    local l = v:K2_GetActorLocation()
                    local d = d3(p.X, p.Y, p.Z, l.X, l.Y, l.Z)
                    if d < bestD then best, bestD = v, d end
                end
            end
        end
        dump_actor("nearest vehicle", best)
    end)
end)

print("[SD_Heli] Dev helper loaded - F8 diagnostics, F7 move box, F6 show/hide box, F2 collision dump\n")
