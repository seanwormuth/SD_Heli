-- SD_Heli parking: a parked helicopter doesn't simulate physics.
-- SurrounDead loads a save (even from the main menu) without loading a new map: it rebuilds the
-- world (terrain, buildings) around the helicopter, which stays in place. For a moment there is
-- no ground under it, and a simulating helicopter drops through the map. Distant terrain
-- streaming in and out can do the same.
-- So once the player is out and the helicopter has come to rest, its physics is switched off; it
-- stays exactly where it is. Physics is switched back on as the player gets in.
--
-- It also decides which helicopter is the current one (the one ModActor spawned for the loaded
-- save) and removes a helicopter left over from a previously loaded save.

local M = {}

local HELI_CLASS = "/Game/CustomMods/Vehicles/NewsHeli/Blueprints/BP_Heli.BP_Heli_C"
M.CHECK_MS = 250
M.REST_SPEED = 5      -- cm/s: slower than this counts as at rest
M.REST_TIME = 2.0     -- seconds at rest before freezing

local function log(msg) print("[SD_Heli] parking: " .. msg .. "\n") end

local function valid(o)
    local ok, v = pcall(function() return o ~= nil and o:IsValid() end)
    return ok and v
end

local function addr(o)
    local ok, a = pcall(function() return o:GetAddress() end)
    return ok and a or nil
end

local function same(a, b)
    local x, y = addr(a), addr(b)
    return x ~= nil and x == y
end

-- the ModActors live for the whole session: find them once, not on every check
local mods = {}
local function mod_actors()
    local ok = #mods > 0
    for _, m in ipairs(mods) do if not valid(m) then ok = false end end
    if not ok then mods = FindAllOf("ModActor_C") or {} end
    return mods
end

-- the helicopter ModActor spawned for the loaded save (nil while there is none)
function M.current_heli()
    for _, m in ipairs(mod_actors()) do
        local h = nil
        pcall(function() h = m.SpawnedHeli end)
        if valid(h) then return h end
    end
    return nil
end

-- the BP_HeliEntry attached to a helicopter
local entry_cache = { heli = nil, entry = nil }
function M.entry_for(heli)
    if not valid(heli) then return nil end
    local a = addr(heli)
    if entry_cache.heli == a and valid(entry_cache.entry) then return entry_cache.entry end
    for _, e in ipairs(FindAllOf("BP_HeliEntry_C") or {}) do
        local p = nil
        pcall(function() p = e:GetAttachParentActor() end)
        if valid(e) and valid(p) and same(p, heli) then
            entry_cache.heli, entry_cache.entry = a, e
            return e
        end
    end
    return nil
end

local function player_pawn()
    local pc = FindFirstOf("PlayerController")
    if not valid(pc) then return nil end
    local pawn = nil
    pcall(function() pawn = pc.Pawn end)
    return valid(pawn) and pawn or nil
end

local function body(heli)
    local root = nil
    pcall(function() root = heli:K2_GetRootComponent() end)
    return valid(root) and root or nil
end

-- helicopters left over from a previously loaded save: not ModActor's, and not the player's ride.
-- Checked every 2 s; each one is destroyed once (it stays findable until the engine cleans it up).
local destroyed = {}
local last_sweep = 0
local function remove_leftovers(current, pawn)
    if os.clock() - last_sweep < 2 then return end
    last_sweep = os.clock()
    for _, h in ipairs(FindAllOf("BP_Heli_C") or {}) do
        local a = addr(h)
        if a and not destroyed[a] and valid(h) and not same(h, current) and not (pawn and same(h, pawn)) then
            destroyed[a] = true
            local entry = M.entry_for(h)
            if entry then pcall(function() entry:K2_DestroyActor() end) end
            local ok, err = pcall(function() h:K2_DestroyActor() end)
            log(ok and "removed a helicopter left over from another save" or ("couldn't remove a leftover helicopter: " .. tostring(err)))
        end
    end
end

local frozen = nil      -- address of the helicopter we froze
local rest_since = nil  -- os.clock() when it came to rest
local reported = {}     -- errors already logged

local function report(key, msg)
    if reported[key] then return end
    reported[key] = true
    log(msg)
end

local function set_physics(heli, on)
    local b = body(heli)
    if not b then report("nobody", "helicopter has no root component") return false end
    local ok, err = pcall(function() b:SetSimulatePhysics(on) end)
    if not ok then report("set" .. tostring(on), "SetSimulatePhysics failed: " .. tostring(err)) end
    return ok
end

local function thaw(heli, why)
    if not frozen or addr(heli) ~= frozen then return end
    if set_physics(heli, true) then
        frozen, rest_since = nil, nil
        log("helicopter physics on (" .. why .. ")")
    end
end

local function tick()
    local heli = M.current_heli()
    local pawn = player_pawn()
    if not heli then frozen, rest_since = nil, nil return end
    remove_leftovers(heli, pawn)
    if frozen and addr(heli) ~= frozen then frozen = nil end -- a different helicopter now

    if pawn and same(pawn, heli) then -- flying
        thaw(heli, "player in the helicopter")
        rest_since = nil
        return
    end
    if frozen then return end

    local b = body(heli)
    if not b then return end
    local okS, sim = pcall(function() return b:IsSimulatingPhysics(FName("None")) end)
    if not okS then report("issim", "IsSimulatingPhysics failed: " .. tostring(sim)) return end
    if not sim then rest_since = nil return end -- not ours to manage

    local okV, speed = pcall(function()
        local v = heli:GetVelocity()
        return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
    end)
    if not okV then report("vel", "GetVelocity failed: " .. tostring(speed)) return end
    if speed > M.REST_SPEED then rest_since = nil return end
    rest_since = rest_since or os.clock()
    if os.clock() - rest_since < M.REST_TIME then return end

    if set_physics(heli, false) then
        frozen = addr(heli)
        local l = heli:K2_GetActorLocation()
        log(string.format("helicopter parked: physics off at X=%.0f Y=%.0f Z=%.0f", l.X, l.Y, l.Z))
    end
end

local hooked = false
local function install_hooks()
    if hooked or not valid(StaticFindObject(HELI_CLASS)) then return end
    hooked = true
    -- switch physics back on before the helicopter's own enter logic runs
    local ok, err = pcall(RegisterHook, HELI_CLASS .. ":EnterHeli", function(self)
        local h = self:get()
        if valid(h) then thaw(h, "getting in") end
    end)
    if not ok then log("EnterHeli hook failed: " .. tostring(err)) end
end

function M.reset()
    frozen, rest_since, mods, destroyed = nil, nil, {}, {}
    entry_cache.heli, entry_cache.entry = nil, nil
end

function M.init()
    LoopAsync(M.CHECK_MS, function()
        ExecuteInGameThread(function()
            if not hooked then pcall(install_hooks) end
            local ok, err = pcall(tick)
            if not ok then report("tick:" .. tostring(err), "error: " .. tostring(err)) end
        end)
        return false
    end)
    log("enabled")
end

return M
