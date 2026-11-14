-- SD_Heli helicopter storage + vehicle-style prompt
-- Gives the helicopter storage and a car-like "Enter Helicopter / Open Storage" prompt, using the
-- game's own pieces:
--   * a player storage crate (Buildable_StorageCrate), which the game already saves with its
--     contents in the normal game save and which never refills with loot;
--   * the utility truck's storage window (SC_UtilityPickupTruck) instead of the crate's own.
-- The crate is invisible, stretched over the cabin and attached to the helicopter. Looking at the
-- cabin shows the game's interact prompt with "Enter Helicopter" and "Open Storage".
--
-- Each game save has its own crate, saved with the save's world. It's recognised by its stretched
-- scale (the game never scales a crate); SaveGames\<SaveName>_SDHeli_Storage.txt remembers its
-- last object name as a tie-breaker. A watchdog re-attaches the crate whenever the helicopter is
-- (re)spawned, and everything is reset on a map load (e.g. back to the main menu).
--
-- BP_HeliEntry's range sphere is set to only notice pawns: as shipped it blocks traces (the
-- interact trace, bullets) on an invisible ball around the heli.
--
-- It also guards BP_HeliEntry's own F-to-enter: F only enters when the player is really inside the
-- entry sphere (its NearbyPC can go stale when you get out), and not while the player is looking
-- at the cabin prompt (the prompt handles F there).

local M = {}

local CRATE_CLASS = "/Game/Blueprints/BuildingSystem/Actors/Containers/Buildable_StorageCrate.Buildable_StorageCrate_C"
local WINDOW_CLASS = "/Game/Blueprints/Vehicles/Types/UtilityPickupTruck/SC_UtilityPickupTruck.SC_UtilityPickupTruck_C"
local HELI_CLASS = "/Game/CustomMods/Vehicles/NewsHeli/Blueprints/BP_Heli.BP_Heli_C"
local BUILDABLE = "/Game/Blueprints/BuildingSystem/Actors/Buildable_MASTER.Buildable_MASTER_C:"
local CONTAINER = "/Game/Blueprints/BuildingSystem/Actors/Containers/BuildableMaster_Container.BuildableMaster_Container_C:"

local NAME = "Helicopter"
-- prompt options: the vehicles' "Interact" tag enters, the crate's "Option1" opens the storage
local TAG_ENTER = "Jig.InteractOptions.Interact"
local TAG_STORAGE = "Jig.InteractOptions.Option1"
local OPTIONS = { { TAG_ENTER, "Enter Helicopter" }, { TAG_STORAGE, "Open Storage" } }

-- The invisible box over the cabin, in helicopter space (cm): X forward, Y right, Z up.
-- It must stick out of the hull: the game's interact trace stops on the heli's body, so a box
-- fully inside the cabin can't be targeted.
M.CENTER = { X = 37, Y = 0, Z = 182 }  -- placed with F7, centred across the heli
M.HALF = { X = 240, Y = 150, Z = 128 } -- half size of the box
M.CHECK_MS = 500

local SAVE_DIR = (os.getenv("LOCALAPPDATA") or "") .. "\\SurrounDead\\Saved\\SaveGames\\"

local function log(msg) print("[SD_Heli] storage: " .. msg .. "\n") end

local function valid(o)
    local ok, v = pcall(function() return o ~= nil and o:IsValid() end)
    return ok and v
end

local function full_path(o)
    local ok, s = pcall(function() return o:GetFullName() end)
    if not ok or type(s) ~= "string" then return nil end
    return (s:gsub("^%S+%s+", "")) -- drop the "ClassName " prefix
end

local function same(a, b)
    local ok, r = pcall(function() return a:GetAddress() == b:GetAddress() end)
    return ok and r
end

local function tag_name(t)
    local ok, s = pcall(function() return t.TagName:ToString() end)
    return ok and s or nil
end

local function record_file(save) return SAVE_DIR .. save .. "_SDHeli_Storage.txt" end

local function read_record(save)
    local f = io.open(record_file(save), "r")
    if not f then return nil end
    local s = f:read("l"); f:close()
    if s and s ~= "" then return s end
    return nil
end

local function write_record(save, path)
    local f = io.open(record_file(save), "w")
    if f then f:write(path, "\n"); f:close() end
end

-- the helicopter ModActor spawned for the loaded save, and its entry trigger (parking.lua decides;
-- a helicopter left over from another save must not get this save's crate)
local parking = nil
local function first_heli()
    parking = parking or package.loaded["parking"]
    if type(parking) == "table" then return parking.current_heli() end
    for _, h in ipairs(FindAllOf("BP_Heli_C") or {}) do
        if valid(h) then return h end
    end
    return nil
end

local function heli_entry(heli)
    parking = parking or package.loaded["parking"]
    if type(parking) == "table" then return parking.entry_for(heli) end
    return FindFirstOf("BP_HeliEntry_C")
end

local function player()
    local pc = FindFirstOf("PlayerController")
    if not valid(pc) then return nil, nil end
    local pawn = nil
    pcall(function() pawn = pc.Pawn end)
    return pc, valid(pawn) and pawn or nil
end

local function to_world(heli, o)
    local l = heli:K2_GetActorLocation()
    local fw, rt, up = heli:GetActorForwardVector(), heli:GetActorRightVector(), heli:GetActorUpVector()
    return {
        X = l.X + fw.X * o.X + rt.X * o.Y + up.X * o.Z,
        Y = l.Y + fw.Y * o.X + rt.Y * o.Y + up.Y * o.Z,
        Z = l.Z + fw.Z * o.X + rt.Z * o.Y + up.Z * o.Z,
    }
end

local function dist(a, b)
    return math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2 + (a.Z - b.Z) ^ 2)
end

-- crate mesh bounds (local, unscaled): centre and half size
local mesh_center, mesh_half = nil, nil
local function mesh_bounds(crate)
    if mesh_half then return mesh_center, mesh_half end
    local ok, err = pcall(function()
        -- local-space bounds of the mesh component (out params are filled into the tables)
        local mn, mx = {}, {}
        crate.StaticMesh:GetLocalBounds(mn, mx)
        if mn.X == nil or mx.X == nil then error("GetLocalBounds returned nothing") end
        mesh_center = { X = (mn.X + mx.X) / 2, Y = (mn.Y + mx.Y) / 2, Z = (mn.Z + mx.Z) / 2 }
        mesh_half = { X = (mx.X - mn.X) / 2, Y = (mx.Y - mn.Y) / 2, Z = (mx.Z - mn.Z) / 2 }
        log(string.format("crate mesh centre %.0f,%.0f,%.0f half size %.0f x %.0f x %.0f",
            mesh_center.X, mesh_center.Y, mesh_center.Z, mesh_half.X, mesh_half.Y, mesh_half.Z))
    end)
    if not ok then log("crate mesh bounds unreadable: " .. tostring(err)) end
    if not mesh_half or mesh_half.X <= 0 or mesh_half.Y <= 0 or mesh_half.Z <= 0 then
        mesh_center, mesh_half = { X = 0, Y = 0, Z = 50 }, { X = 50, Y = 50, Z = 50 } -- guess
    end
    return mesh_center, mesh_half
end

-- scale that stretches the crate over the cabin, and where the actor origin must sit
local function box_fit(crate)
    local c, h = mesh_bounds(crate)
    local s = { X = M.HALF.X / h.X, Y = M.HALF.Y / h.Y, Z = M.HALF.Z / h.Z }
    local origin = { X = M.CENTER.X - c.X * s.X, Y = M.CENTER.Y - c.Y * s.Y, Z = M.CENTER.Z - c.Z * s.Z }
    return s, origin
end

local function set_options(crate)
    local ok, err = pcall(function()
        local m = crate.InteractOptions
        m:Empty()
        for _, o in ipairs(OPTIONS) do
            m:Add({ TagName = FName(o[1]) }, FText(o[2]))
        end
    end)
    if not ok then log("couldn't set the prompt options: " .. tostring(err)) end
end

-- Invisible and not solid: it must not push or carry the helicopter, block the player or the
-- camera, or count as something entering BP_HeliEntry's range sphere. It stays query-only so the
-- game's interact check can still find it. ECollisionChannel: 2 Pawn, 4 Camera, 5 PhysicsBody,
-- 6 Vehicle.
local function make_ghost(crate)
    pcall(function() crate:SetActorHiddenInGame(true) end)
    pcall(function()
        local m = crate.StaticMesh
        m:SetCollisionEnabled(1)                 -- QueryOnly
        m:SetGenerateOverlapEvents(false)
        m:SetCollisionResponseToChannel(2, 0)    -- Pawn: ignore (walk through it)
        m:SetCollisionResponseToChannel(4, 0)    -- Camera: ignore (spring arm)
        m:SetCollisionResponseToChannel(5, 0)    -- PhysicsBody: ignore
        m:SetCollisionResponseToChannel(6, 0)    -- Vehicle: ignore
    end)
    pcall(function()
        crate.NavObstacleBox:SetCollisionEnabled(0)
        crate.NavObstacleBox:SetGenerateOverlapEvents(false)
    end)
    -- child actors (Storage1-5, SnapPoints): no collision at all
    for _, n in ipairs({ "Storage1", "Storage2", "Storage3", "Storage4", "Storage5", "SnapPoints" }) do
        pcall(function()
            local ca = crate[n].ChildActor
            if valid(ca) then ca:SetActorEnableCollision(false) end
        end)
    end
end

local function configure(crate)
    make_ghost(crate)
    pcall(function()
        local ui = StaticFindObject(WINDOW_CLASS)
        if valid(ui) then crate.BP_JigMultiplayer.InventoryWidgetClass = ui end
    end)
    pcall(function() crate.ContainerName = FText(NAME) end)
    set_options(crate)
end

local function attach(crate, heli)
    local s, origin = box_fit(crate)
    local r = heli:K2_GetActorRotation()
    pcall(function() crate:K2_DetachFromActor(1, 1, 1) end)
    crate:SetActorScale3D(s)
    crate:K2_SetActorLocationAndRotation(to_world(heli, origin), r, false, {}, true)
    -- KeepWorld for location/rotation/scale, no welding (the crate must not join the heli's physics body)
    crate:K2_AttachToActor(heli, FName("None"), 1, 1, 1, false)
end

local function spawn_crate(heli)
    local cls = StaticFindObject(CRATE_CLASS)
    if not valid(cls) then return nil end
    local spot = to_world(heli, M.CENTER)
    local r = heli:K2_GetActorRotation()
    local c = heli:GetWorld():SpawnActor(cls, spot, { Pitch = 0, Yaw = r.Yaw, Roll = 0 })
    if valid(c) then make_ghost(c) return c end
    return nil
end

local get_save_name = nil
local crate = nil        -- this save's crate
local crate_save = nil   -- the save it belongs to
local configured = {}    -- addresses of the crates already configured in this world
local focused = false    -- the player is looking at the cabin prompt
local heli_seen = nil    -- os.clock() when the helicopter was first seen in this world
local warned_dupes = 0   -- duplicate count last reported
M.NEW_CRATE_WAIT = 30    -- seconds to look for the saved crate before making a new one

-- Our crates are the only stretched ones: the game never scales a storage crate, and the game
-- save keeps the scale. That finds the save's crate however the game renamed it on loading.
local function scale_of(c)
    local ok, s = pcall(function() return c:GetActorScale3D() end)
    if not ok or not s then return nil end
    local okx, x, y, z = pcall(function() return s.X, s.Y, s.Z end)
    if not okx or type(x) ~= "number" then return nil end
    return math.max(x, y, z)
end

local function marked_crates()
    local out = {}
    for _, c in ipairs(FindAllOf("Buildable_StorageCrate_C") or {}) do
        if valid(c) then
            local k = scale_of(c)
            if k and k > 1.5 then out[#out + 1] = c end
        end
    end
    return out
end

local function configure_once(c)
    local a = c:GetAddress()
    -- an address can be reused by a crate the game re-created: also check it's still hidden
    local hidden = false
    pcall(function() hidden = c.bHidden end)
    if configured[a] and hidden then return end
    configure(c)
    configured[a] = true
end

-- the save's crate: the remembered one if its name still matches, else the one nearest the cabin
local function pick_crate(list, save, heli)
    local rec = read_record(save)
    if rec then
        for _, c in ipairs(list) do
            if full_path(c) == rec then return c end
        end
    end
    if not heli then return list[1] end
    local spot = to_world(heli, M.CENTER)
    local best, bestD = nil, math.huge
    for _, c in ipairs(list) do
        local ok, l = pcall(function() return c:K2_GetActorLocation() end)
        if ok then
            local d = dist(l, spot)
            if d < bestD then best, bestD = c, d end
        end
    end
    return best or list[1]
end

-- extra stretched crates (left over from a bug): hidden and fully inert, but kept, as they may
-- hold items
local function park_duplicates(list)
    local n = 0
    for _, c in ipairs(list) do
        if not same(c, crate) then
            n = n + 1
            pcall(function() c:SetActorHiddenInGame(true) end)
            pcall(function() c:SetActorEnableCollision(false) end)
        end
    end
    if n > 0 and n ~= warned_dupes then
        log(string.format("found %d extra helicopter storage crate(s) in this save; hidden and kept", n))
    end
    warned_dupes = n
end

local function is_our_crate(o)
    return valid(crate) and valid(o) and same(o, crate)
end

-- BP_HeliEntry's HeliRange sphere is meant to only notice the player walking in, but it blocks
-- traces (Visibility, Weapons, Buildable...): the interact trace stops on its invisible surface
-- whenever the camera is outside it, and bullets hit it. Make it ignore everything except an
-- overlap with pawns, which is all F-to-enter needs.
local entry_fixed = nil -- address of the HeliRange already fixed
local function fix_entry_sphere(heli)
    local entry = heli_entry(heli)
    if not valid(entry) then return end
    local ok, err = pcall(function()
        local s = entry.HeliRange
        if not valid(s) then error("HeliRange not found") end
        if entry_fixed == s:GetAddress() then return end
        s:SetCollisionResponseToAllChannels(0)   -- ignore
        s:SetCollisionResponseToChannel(2, 1)    -- Pawn: overlap
        s:SetGenerateOverlapEvents(true)
        entry_fixed = s:GetAddress()
        log("entry sphere: now only overlaps pawns")
    end)
    if not ok and entry_fixed ~= "failed" then log("entry sphere: " .. tostring(err)) entry_fixed = "failed" end
end

local last_scan = 0      -- os.clock() of the last full crate scan

local function ensure()
    local save = get_save_name and get_save_name()
    if not save then return end
    if crate_save ~= save then crate, crate_save, focused = nil, save, false end
    -- our crate vanished: the game is reloading its save (it deletes and re-creates every crate,
    -- without loading a new map). Wait for the restored one instead of making a new one.
    if crate ~= nil and not valid(crate) then
        crate, configured, focused = nil, {}, false
        heli_seen = os.clock()
        log("storage crate gone (save reloading?): waiting for the game to restore it")
    end

    -- make every crate of ours harmless as soon as it exists, before the helicopter lands on it.
    -- Scanning all crates is costly: every tick only while ours is missing, else every 5 s
    -- (that still catches a crate the game re-creates on a save reload, and duplicates).
    local heli = first_heli()
    if not valid(crate) or os.clock() - last_scan >= 5 then
        last_scan = os.clock()
        local list = marked_crates()
        for _, c in ipairs(list) do configure_once(c) end
        if not valid(crate) then crate = pick_crate(list, save, heli) end
        if #list > 1 then park_duplicates(list) end
    end

    if not heli then heli_seen = nil return end
    heli_seen = heli_seen or os.clock()
    fix_entry_sphere(heli)

    if valid(crate) then
        local parent = nil
        pcall(function() parent = crate:GetAttachParentActor() end)
        if valid(parent) and same(parent, heli) then return end -- all good
    end

    local how = "from the save"
    if not valid(crate) then
        -- give the game time to restore the saved crate before deciding this save has none
        if os.clock() - heli_seen < M.NEW_CRATE_WAIT then return end
        crate, how = spawn_crate(heli), "new"
        if not crate then log("couldn't spawn the storage crate") return end
        configure_once(crate)
    end

    local ok, err = pcall(attach, crate, heli)
    if not ok then log("attach failed: " .. tostring(err)) return end
    local path = full_path(crate)
    if path then write_record(save, path) end
    log(string.format("helicopter storage ready for %s (%s)", save, how))
end

local function safe_ensure()
    local ok, err = pcall(ensure)
    if not ok then log("error: " .. tostring(err)) end
end

-- Game hooks. The classes are only loaded once a save is in progress.
local hooked = false
local entering = 0
local function hook(path, fn)
    local ok, err = pcall(RegisterHook, path, fn)
    if not ok then log("hook " .. path:match("[^:]+$") .. " failed: " .. tostring(err)) end
    return ok
end

local function install_hooks()
    if hooked then return end
    -- the game's classes only exist once a save is loaded
    if not valid(StaticFindObject(BUILDABLE:sub(1, -2))) then return end
    hooked = true

    -- looking at / away from the cabin prompt
    local function on_begin(self)
        if is_our_crate(self:get()) then
            focused = true; set_options(crate)
        end
    end
    hook(BUILDABLE .. "OnBeginInteract", on_begin)
    hook(CONTAINER .. "OnBeginInteract", on_begin)
    hook(BUILDABLE .. "OnEndInteract", function(self)
        if is_our_crate(self:get()) then focused = false end
    end)

    -- "Enter Helicopter" chosen in the prompt
    hook(BUILDABLE .. "OnExecuteInteract", function(self, actor, option)
        if not is_our_crate(self:get()) then return end
        local t = tag_name(option:get())
        if t ~= TAG_ENTER then return end
        local now = os.clock()
        if now - entering < 1 then return end
        entering = now
        ExecuteWithDelay(50, function()
            ExecuteInGameThread(function()
                local heli = first_heli()
                local pc = player()
                if heli and pc then
                    focused = false
                    local ok, err = pcall(function() heli:EnterHeli(pc) end)
                    if not ok then log("EnterHeli failed: " .. tostring(err)) end
                end
            end)
        end)
    end)

    log("hooks installed")
end

-- BP_HeliEntry's own F-to-enter. It adds IMC_HeliEntry (F) when the player walks into its sphere
-- and removes it when they leave, but the "leave" can be missed when getting out of the
-- helicopter, leaving F armed everywhere. Here F is allowed only while the player is really
-- inside the sphere and not looking at the cabin prompt (which then owns F).
local IMC_PATH = "/Game/CustomMods/Vehicles/NewsHeli/Inputs/IMC_HeliEntry.IMC_HeliEntry"
local gate = nil   -- last applied state: true = F may enter, false = blocked
local function set_entry_mapping(on)
    local ok, err = pcall(function()
        local imc = StaticFindObject(IMC_PATH)
        local sub = FindFirstOf("EnhancedInputLocalPlayerSubsystem")
        if not valid(imc) or not valid(sub) then error("input subsystem or IMC_HeliEntry not found") end
        if on then
            sub:AddMappingContext(imc, 1, { bIgnoreAllPressedKeysUntilRelease = false, bForceImmediately = true, bNotifyUserSettings = false })
        else
            sub:RemoveMappingContext(imc, { bIgnoreAllPressedKeysUntilRelease = false, bForceImmediately = true, bNotifyUserSettings = false })
        end
    end)
    if not ok then log("entry mapping: " .. tostring(err)) end
end

local function gate_entry()
    local heli = first_heli()
    local entry = heli_entry(heli)
    local pc, pawn = player()
    if not valid(entry) or not heli or not pawn then gate = nil return end
    if same(pawn, heli) then gate = nil return end -- flying: leave it alone
    local r = 600
    pcall(function() r = entry.HeliRange:GetScaledSphereRadius() end)
    local near = dist(pawn:K2_GetActorLocation(), heli:K2_GetActorLocation()) <= r
    local want = near and not focused
    if want then
        if want == gate then return end
        pcall(function() entry.NearbyPC = pc end)
        set_entry_mapping(true)
    else
        -- BP_HeliEntry re-arms F by itself when it sees the player walk into its sphere, so while
        -- F is blocked, keep it blocked every tick (cheap: only while near the heli or looking at it)
        if gate == false and not near and not focused then return end
        pcall(function() entry.NearbyPC = nil end)
        set_entry_mapping(false)
    end
    gate = want
end

-- dev helpers (used by dev_helper.lua)
function M.crate() return valid(crate) and crate or nil end

function M.move_to(center, heli)
    M.CENTER = center
    if valid(crate) and valid(heli) then
        local ok, err = pcall(attach, crate, heli)
        if not ok then log("move failed: " .. tostring(err)) end
    end
end

function M.set_visible(on)
    if valid(crate) then pcall(function() crate:SetActorHiddenInGame(not on) end) end
end

-- a new map (main menu, another save): forget everything from the old world
function M.reset()
    crate, crate_save, configured, focused = nil, nil, {}, false
    heli_seen, warned_dupes, entry_fixed, gate = nil, 0, nil, nil
end

function M.init(save_name_fn)
    get_save_name = save_name_fn
    LoopAsync(M.CHECK_MS, function()
        ExecuteInGameThread(function()
            if not hooked then pcall(install_hooks) end -- also covers a UE4SS hot reload (Ctrl+R)
            safe_ensure()
        end)
        return false -- keep looping
    end)
    LoopAsync(200, function()
        ExecuteInGameThread(function()
            local ok, err = pcall(gate_entry)
            if not ok then log("entry gate error: " .. tostring(err)) end
        end)
        return false
    end)
    -- the helicopter is about to exist: make the save's crate harmless right away
    pcall(NotifyOnNewObject, HELI_CLASS, function()
        ExecuteInGameThread(safe_ensure)
    end)
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function() end, function()
        ExecuteWithDelay(3000, function() ExecuteInGameThread(install_hooks) end)
    end)
    log("enabled")
end

return M
