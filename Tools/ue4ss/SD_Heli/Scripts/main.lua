-- SD_Heli companion script
-- Gives every SurrounDead save its own helicopter and parked position.
--
-- SurrounDead loads ModActor once at startup, while the main menu is up, and loading a save
-- doesn't reload the level. So ModActor can't pick the right helicopter in BeginPlay. Instead:
--   1. BeginPlay calls the custom event SDHeli_RequestSaveName. This script answers by setting
--      ModActor.LuaManaged = true, telling the Blueprint to wait instead of loading.
--   2. When the player's character appears in a loaded save (PlayerController:ClientRestart),
--      this script reads the save's name, sets ModActor.SaveSlotName to "<SaveName>_SDHeli"
--      and calls ModActor's custom event SDHeli_LoadForSave.
-- The helicopter file is SaveGames\<SaveName>_SDHeli.sav, next to the game's own
-- <SaveName>_Quests.sav and <SaveName>_SkillTree.sav.
-- Without this script LuaManaged stays false and ModActor uses the old shared "SD_Heli_Save".

local LEGACY_SLOT = "SD_Heli_Save"
local SUFFIX = "_SDHeli"
local SAVE_DIR = (os.getenv("LOCALAPPDATA") or "") .. "\\SurrounDead\\Saved\\SaveGames\\"
local SETTLE_MS = 1000 -- give the game a moment to finish loading the save

local function log(msg) print("[SD_Heli] " .. msg .. "\n") end

local function valid(o)
    local ok, v = pcall(function() return o ~= nil and o:IsValid() end)
    return ok and v
end

local function to_str(v)
    if type(v) == "string" then return v end
    local ok, s = pcall(function() return v:ToString() end)
    if ok and type(s) == "string" then return s end
    return nil
end

-- The game saves with Easy Multi Save; its EMSObject holds the name of the loaded save.
local ems = nil
local function current_save_name()
    pcall(function()
        if valid(ems) then return end
        ems = nil
        for _, o in ipairs(FindAllOf("EMSObject") or {}) do
            if valid(o) and o:GetClass():GetFName():ToString() == "EMSObject" then ems = o end
        end
    end)
    if not ems then return nil end
    local name
    pcall(function() name = to_str(ems.CurrentSaveGameName) end)
    -- slot names become file names: refuse anything with path characters
    if not name or name == "" or name:find("[\\/:%*%?\"<>|]") or name:find("%.%.") then return nil end
    return name
end

local function exists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

-- One-time move: the helicopter parked under the old shared save goes to the first save
-- loaded after updating. The old file is renamed, not deleted.
local function migrate_legacy(slot)
    local old = SAVE_DIR .. LEGACY_SLOT .. ".sav"
    local new = SAVE_DIR .. slot .. ".sav"
    if not exists(old) or exists(new) then return end
    local src = io.open(old, "rb"); if not src then return end
    local data = src:read("a"); src:close()
    local dst = io.open(new, "wb"); if not dst then return end
    dst:write(data); dst:close()
    os.rename(old, SAVE_DIR .. LEGACY_SLOT .. ".migrated")
    log("moved the old shared helicopter save to " .. slot)
end

-- SurrounDead starts two ModActors. Only one of them gets to manage the helicopter.
local owner = nil
local function pick_owner()
    if valid(owner) then return owner end
    owner = nil
    for _, m in ipairs(FindAllOf("ModActor_C") or {}) do
        if valid(m) then owner = m break end
    end
    return owner
end

local in_game = false   -- a save has been loaded and the player is in it
local last_slot = nil   -- slot ModActor was last told to load

local function load_for_current_save(reason)
    local actor = pick_owner()
    if not actor then log("no ModActor yet (" .. reason .. ")") return end
    local name = current_save_name()
    if not name then
        log("couldn't read the loaded save's name (" .. reason .. ") - helicopter not loaded")
        return
    end
    local slot = name .. SUFFIX
    if slot == last_slot then return end -- same save (e.g. respawn after death): keep the helicopter
    pcall(migrate_legacy, slot)
    local ok, err = pcall(function()
        actor.SaveSlotName = slot
        actor:SDHeli_LoadForSave()
    end)
    if ok then
        last_slot = slot
        log("loaded helicopter for save " .. name .. " (slot " .. slot .. ", " .. reason .. ")")
    else
        log("SDHeli_LoadForSave failed: " .. tostring(err))
    end
end

local function schedule_load(reason)
    ExecuteWithDelay(SETTLE_MS, function()
        ExecuteInGameThread(function() load_for_current_save(reason) end)
    end)
end

-- ModActor's BeginPlay asks whether this script is here.
RegisterCustomEvent("SDHeli_RequestSaveName", function(ctx)
    local actor = ctx:get()
    pcall(function() actor.LuaManaged = true end)
    -- If a ModActor shows up while already in a save, load for it right away.
    if in_game then schedule_load("ModActor started in game") end
end)

-- Fires when the player's character is spawned into a loaded save.
RegisterHook("/Script/Engine.PlayerController:ClientRestart", function() end, function()
    in_game = true
    schedule_load("player spawned")
end)

log("per-save helicopters enabled")

-- Optional dev helper (F8 diagnostics), only if dev_helper.lua sits next to this file.
pcall(require, "dev_helper")
