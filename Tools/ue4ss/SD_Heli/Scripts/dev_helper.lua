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

print("[SD_Heli] Dev helper loaded - press F8 for location + spawn diagnostics\n")
