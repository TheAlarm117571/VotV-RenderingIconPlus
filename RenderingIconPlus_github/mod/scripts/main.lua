local PROCESSOR_CLASS = "/Game/objects/propProcessor.propProcessor_C"
local PROPS_TABLE = "/Game/main/datatables/list_props.list_props"
local GAME_LIB = "/Game/main/lib.Default__lib_C"
local GAME_LIB_CLASS = "/Game/main/lib.lib_C"
local KISMET_SYSTEM = "/Script/Engine.Default__KismetSystemLibrary"
local KISMET_RENDERING = "/Script/Engine.Default__KismetRenderingLibrary"
local DATATABLE_LIB = "/Script/Engine.Default__DataTableFunctionLibrary"
local FILE_SDK = "/Script/FileSDK.Default__FileSDKBPLibrary"
local MESH_FIELD = "mesh_2_28374D6C4A557F350BB1138B77DED9D3"
local MOD_ROOT = "/game/mods/"

local SET_NAMES_FN = "setPropNames"
local FINISH_FN = "intComs_propRenderer_finishProps"

local GAME_VERSIONS = {
    {
        functions = { SET_NAMES_FN, FINISH_FN, "exportItemBounds" },
        properties = { "propsNames", "propsNames_len", "names", "toTex", "itemIconBounds" },
        bounds = true,
    },
    {
        functions = { SET_NAMES_FN, FINISH_FN },
        properties = { "propsNames", "propsNames_len", "names", "toTex" },
        bounds = false,
    },
}

local INDEX_NAME = "index.txt"
local PAD_NAME = "renderingiconplus.pad"
local BOUNDS_FILE = "propbounds"
local FALLBACK_BOUNDS = "0|0|1|1"

local CONFIG_MENU_CLASSES = {
    "/Game/Mods/ConfigMenu/ConfigMenuInstance.ConfigMenuInstance_C",
    "/Game/Mods/ConfigMenu/ModActor.ModActor_C",
}
local CONFIG_MENU_PAKS = { "TheAlarm-ConfigMenu\\ConfigMenu.pak", "ConfigMenu\\ConfigMenu.pak", "ConfigMenu.pak" }
local CONFIG_MENU_PREFIX = "renderingiconplus.main."
local CONFIG_FILE = "RenderingIconPlus.cfg"
local CACHE_FOLDER = "RenderingIconPlusCache"
local SETTINGS = {
    { id = "cacheMods", menuKey = "cachemodded", fileKey = "CacheModdedIcons", default = false },
    { id = "notify", menuKey = "shownotifications", fileKey = "ShowNotifications", default = true },
}
local TRUE_WORDS = { ["true"] = true, ["1"] = true, ["yes"] = true, ["on"] = true }

local HINT_PREFIX = "RenderingIconPlus: "
local HINT_INFO = 0
local HINT_WARNING = 1
local HINT_SECONDS = 10.0
local WARNING_DELAY_MS = 3000

local SCRIPT_FILE = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("/", "\\")
local GAME_ROOT = SCRIPT_FILE:match("^(.*)\\[Bb][Ii][Nn][Aa][Rr][Ii][Ee][Ss]\\")
local UE4SS_DIR = SCRIPT_FILE:match("^(.*)\\[Mm][Oo][Dd][Ss]\\[^\\]+\\[Ss][Cc][Rr][Ii][Pp][Tt][Ss]\\[^\\]+$")
local CONFIG_DIR = GAME_ROOT and (GAME_ROOT .. "\\Config\\")

local state = {
    hooked = false,
    blocked = false,
    warned = false,
    warnOnIcons = false,
    warnScheduled = false,
    hintDuration = nil,
    notify = true,
    bounds = false,
    paths = nil,
}
local session = nil

local function try(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    return nil
end

local function valid(o)
    return o ~= nil and try(function() return o:IsValid() end) == true
end

local function find(path)
    local o = try(StaticFindObject, path)
    if valid(o) then
        return o
    end
    return nil
end

local function text(v)
    if type(v) == "string" then
        return v
    end
    return try(function() return v:ToString() end)
end

local function objectPath(o)
    return o:GetFullName():match("^%S+%s+(.+)$") or ""
end

local function plural(n, word)
    if n == 1 then
        return "1 " .. word
    end
    return n .. " " .. word .. "s"
end

local function fileExists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    local data = f:read("a")
    f:close()
    return data
end

local function writeFile(path, data)
    local f = io.open(path, "wb")
    if not f then
        return false
    end
    f:write(data)
    f:close()
    return true
end

local function copyFile(from, to)
    local data = readFile(from)
    return data ~= nil and #data > 0 and writeFile(to, data)
end

local function memberNames(cls, kind)
    local names = {}
    try(function()
        local each = kind == "property" and cls.ForEachProperty or cls.ForEachFunction
        each(cls, function(m)
            names[m:GetFName():ToString():lower()] = m
        end)
    end)
    return names
end

local function functionPath(cls, name)
    local f = memberNames(cls, "function")[name:lower()]
    return f and try(function() return objectPath(f) end)
end

local function hintTakesDuration()
    if state.hintDuration == nil then
        state.hintDuration = false
        local cls = find(GAME_LIB_CLASS)
        local fn = cls and memberNames(cls, "function")["addhint"]
        if fn then
            state.hintDuration = memberNames(fn, "property")["duration"] ~= nil
        end
    end
    return state.hintDuration
end

local function hint(message, kind, context, important)
    if not important and not state.notify then
        return
    end
    local function show()
        try(function()
            local lib = StaticFindObject(GAME_LIB)
            local line = FText(HINT_PREFIX .. message)
            if hintTakesDuration() then
                lib:addHint(line, kind, false, HINT_SECONDS, context)
            else
                lib:addHint(line, kind, false, context)
            end
        end)
    end
    if ExecuteInGameThread then
        try(ExecuteInGameThread, show)
    else
        show()
    end
end

local function gameKey()
    local candidates = { "..\\..\\Content\\Paks\\VotV-WindowsNoEditor.pak" }
    local content = try(function() return text(StaticFindObject(KISMET_SYSTEM):GetProjectContentDirectory()) end)
    if content then
        table.insert(candidates, 1, content .. "Paks/VotV-WindowsNoEditor.pak")
    end
    for _, path in ipairs(candidates) do
        local f = io.open(path, "rb")
        if f then
            local size = f:seek("end")
            f:close()
            return "pak" .. size
        end
    end
    return nil
end

local function ensureFolder(path)
    local function writable()
        local f = io.open(path .. "\\" .. INDEX_NAME, "ab")
        if f then
            f:close()
            return true
        end
        return false
    end
    if writable() then
        return true
    end
    try(function() StaticFindObject(FILE_SDK):CreateDirectory(path, true) end)
    return writable()
end

local function resolvePaths()
    if state.paths then
        return state.paths
    end
    local base = os.getenv("LOCALAPPDATA")
    local key = gameKey()
    if not base or not UE4SS_DIR or not key then
        return nil
    end
    local icons = base .. "\\VotV\\Assets\\icons\\"
    local cache = UE4SS_DIR .. "\\" .. CACHE_FOLDER .. "\\"
    local p = {
        items = icons .. "items",
        bounds = icons .. BOUNDS_FILE,
        game = cache .. "game",
        mods = cache .. "mods",
        key = key,
    }
    if not ensureFolder(p.game) then
        return nil
    end
    state.paths = p
    return p
end

local function configFilePath()
    return CONFIG_DIR and (CONFIG_DIR .. CONFIG_FILE)
end

local function defaults()
    local values = {}
    for _, s in ipairs(SETTINGS) do
        values[s.id] = s.default
    end
    return values
end

local function readConfigFile(path)
    local values, found = defaults(), {}
    for line in (readFile(path) or ""):gmatch("[^\r\n]+") do
        local key, value = line:match("^%s*([^=]-)%s*=%s*(.-)%s*$")
        for _, s in ipairs(SETTINGS) do
            if key and key:lower() == s.fileKey:lower() then
                values[s.id] = TRUE_WORDS[value:lower()] == true
                found[s.id] = true
            end
        end
    end
    local missing = {}
    for _, s in ipairs(SETTINGS) do
        if not found[s.id] then
            missing[#missing + 1] = s.fileKey .. "=" .. tostring(s.default) .. "\n"
        end
    end
    if #missing > 0 then
        local f = io.open(path, "ab")
        if f then
            f:write(table.concat(missing))
            f:close()
        end
    end
    return values
end

local function createConfigEarly()
    if not GAME_ROOT then
        return
    end
    for _, pak in ipairs(CONFIG_MENU_PAKS) do
        if fileExists(GAME_ROOT .. "\\Content\\Paks\\LogicMods\\" .. pak) then
            return
        end
    end
    readConfigFile(configFilePath())
end

local function configMenuLoaded()
    for _, path in ipairs(CONFIG_MENU_CLASSES) do
        if find(path) then
            return true
        end
    end
    return false
end

local function readConfigMenu()
    local values = defaults()
    local dir = try(function() return text(StaticFindObject(KISMET_SYSTEM):GetProjectSavedDirectory()) end)
    if not dir then
        return values
    end
    dir = dir:gsub("/", "\\")
    if dir:sub(-1) ~= "\\" then
        dir = dir .. "\\"
    end
    local data = readFile(dir .. "SaveGames\\ConfigMenu.sav")
    if not data then
        return values
    end
    local lower = data:lower()
    for _, s in ipairs(SETTINGS) do
        local needle = CONFIG_MENU_PREFIX .. s.menuKey .. "\0"
        local at = lower:find(needle, 1, true)
        if at then
            local v = at + #needle
            local a, b, c, d = data:byte(v, v + 3)
            local len = (a or 0) + (b or 0) * 256 + (c or 0) * 65536 + (d or 0) * 16777216
            if len >= 1 and len <= 16 then
                values[s.id] = TRUE_WORDS[data:sub(v + 4, v + 2 + len):lower()] == true
            end
        end
    end
    return values
end

local function loadSettings()
    if configMenuLoaded() then
        return readConfigMenu()
    end
    local path = configFilePath()
    if not path then
        return defaults()
    end
    return readConfigFile(path)
end

local function readIndex(folder, key)
    local entries, left = {}, {}
    local data = readFile(folder .. "\\" .. INDEX_NAME)
    if not data then
        return entries, left
    end
    local sameGame = false
    for line in data:gmatch("[^\r\n]+") do
        local leftName = line:match("^left=(.+)$")
        if leftName then
            left[#left + 1] = leftName
        elseif line:sub(1, 4) == "key=" then
            sameGame = line == "key=" .. key
        elseif sameGame then
            local name, stamp, bounds = line:match("^([^\t]+)\t([^\t]*)\t?(.*)$")
            if name then
                entries[name] = { stamp = stamp, bounds = bounds ~= "" and bounds or nil }
            end
        end
    end
    return entries, left
end

local function writeIndex(folder, key, entries, left)
    local names = {}
    for name in pairs(entries) do
        names[#names + 1] = name
    end
    table.sort(names)
    local out = { "key=" .. key }
    for _, name in ipairs(names) do
        local e = entries[name]
        out[#out + 1] = name .. "\t" .. e.stamp .. (e.bounds and ("\t" .. e.bounds) or "")
    end
    for _, name in ipairs(left or {}) do
        out[#out + 1] = "left=" .. name
    end
    writeFile(folder .. "\\" .. INDEX_NAME, table.concat(out, "\n") .. "\n")
end

local function readLines(path)
    local lines = {}
    for line in (readFile(path) or ""):gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end
    return lines
end

local function rowMesh(tbl, name)
    return tbl and try(function()
        local row = tbl:FindRow(name)
        local mesh = row and row[MESH_FIELD]
        if valid(mesh) then
            return mesh
        end
        return nil
    end)
end

local function isModAsset(mesh)
    return mesh ~= nil and objectPath(mesh):lower():sub(1, #MOD_ROOT) == MOD_ROOT
end

local function modTableRows()
    local rows = {}
    try(function()
        local dtl = StaticFindObject(DATATABLE_LIB)
        for _, t in ipairs(FindAllOf("DataTable") or {}) do
            local path = objectPath(t):lower()
            if path:sub(1, #MOD_ROOT) == MOD_ROOT and path:find("list_props", 1, true) then
                local names = {}
                try(function() dtl:GetDataTableRowNames(t, names) end)
                for _, n in pairs(names) do
                    local name = text(n) or try(function() return n:get():ToString() end)
                    if name then
                        rows[name:lower()] = true
                    end
                end
            end
        end
    end)
    return rows
end

local function fingerprint(mesh)
    if not mesh then
        return "none"
    end
    local parts = { objectPath(mesh) }
    try(function()
        local b = mesh:GetBounds()
        parts[#parts + 1] = string.format("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f",
            b.Origin.X, b.Origin.Y, b.Origin.Z, b.BoxExtent.X, b.BoxExtent.Y, b.BoxExtent.Z, b.SphereRadius)
    end)
    try(function()
        parts[#parts + 1] = mesh:GetNumLODs() .. "," .. mesh:GetNumSections(0)
    end)
    try(function()
        for i = 0, 15 do
            local mat = mesh:GetMaterial(i)
            if not valid(mat) then
                break
            end
            parts[#parts + 1] = objectPath(mat)
        end
    end)
    return table.concat(parts, "|")
end

local function readArray(arr)
    local list = {}
    arr:ForEach(function(_, elem)
        list[#list + 1] = elem:get()
    end)
    return list
end

local function writeArray(arr, values, count)
    arr:Empty()
    for i = 1, count or #values do
        local v = values[i]
        if not pcall(function() arr[i] = v end) then
            arr[i] = values[1]
        end
    end
end

local function folderCount(dir)
    return try(function()
        local result = StaticFindObject(FILE_SDK):GetDirectoryContentsWithFileInfo(dir, false)
        if type(result) == "table" then
            return #result
        end
        return result:GetArrayNum()
    end)
end

local function gameInstanceHasIcons()
    return try(function()
        local gi = FindFirstOf("mainGameInstance_C")
        return valid(gi) and gi.texs_GAMEINST:GetArrayNum() > 0
    end) == true
end

local function startHint(s, proc)
    if s.gameHits == 0 and s.modHits == 0 then
        hint("building icon cache (" .. plural(#s.full, "icon") .. ")", HINT_WARNING, proc)
    end
end

local function newCounts()
    return { loaded = 0, rendered = 0, added = 0 }
end

local function groupHints(counts, word, proc)
    if counts.loaded > 0 then
        hint(plural(counts.loaded, word) .. " loaded from cache", HINT_INFO, proc)
    end
    if counts.rendered > 0 then
        hint(plural(counts.rendered, word) .. " rendered", HINT_INFO, proc)
    end
    if counts.added > 0 then
        hint(plural(counts.added, word) .. " added to cache", HINT_INFO, proc)
    end
end

local function resultHints(c, proc)
    groupHints(c.game, "game icon", proc)
    groupHints(c.mods, "modded icon", proc)
    if c.failed > 0 then
        hint(plural(c.failed, "icon") .. " failed to load, re-rendered next start", HINT_WARNING, proc, true)
    end
end

local function usable(entry, stamp, file)
    return entry ~= nil and entry.stamp == stamp and (not state.bounds or entry.bounds ~= nil) and fileExists(file)
end

local function prepare(proc)
    if session or not valid(proc) then
        return
    end
    if gameInstanceHasIcons() then
        session = { done = true }
        return
    end
    local p = resolvePaths()
    if not p then
        session = { done = true }
        hint("cannot write to the cache in the mod folder, the game loads icons on its own", HINT_WARNING, proc, true)
        return
    end
    local settings = loadSettings()
    state.notify = settings.notify
    local cacheMods = settings.cacheMods and ensureFolder(p.mods)
    local tbl = find(PROPS_TABLE)
    local modRows = modTableRows()
    local gameIndex, left = readIndex(p.game, p.key)
    local modIndex = cacheMods and (readIndex(p.mods, p.key)) or {}
    local s = {
        address = try(function() return proc:GetAddress() end),
        paths = p,
        full = readArray(proc.propsNames),
        names = {},
        lowers = {},
        isGame = {},
        stamps = {},
        source = {},
        missing = {},
        cacheMods = cacheMods,
        gameIndex = gameIndex,
        modIndex = modIndex,
        gameHits = 0,
        modHits = 0,
        done = false,
    }
    for i, fname in ipairs(s.full) do
        local name = text(fname) or ""
        local lower = name:lower()
        s.names[i], s.lowers[i] = name, lower
        local mesh = rowMesh(tbl, name)
        local isGame = not modRows[lower] and not isModAsset(mesh)
        local stamp = fingerprint(mesh)
        s.isGame[lower], s.stamps[lower] = isGame, stamp
        local folder = isGame and p.game or (cacheMods and p.mods)
        local index = isGame and gameIndex or modIndex
        local file = folder and (folder .. "\\" .. lower .. ".vimg")
        if file and usable(index[lower], stamp, file) then
            s.source[lower] = file
            if isGame then
                s.gameHits = s.gameHits + 1
            else
                s.modHits = s.modHits + 1
            end
        else
            s.missing[#s.missing + 1] = fname
        end
    end
    for _, name in ipairs(s.names) do
        os.remove(p.items .. "\\" .. name .. ".vimg")
    end
    for _, name in ipairs(left) do
        os.remove(p.items .. "\\" .. name .. ".vimg")
    end
    session = s
    startHint(s, proc)
    writeArray(proc.propsNames, s.missing)
    proc.propsNames_len = #s.missing
    if #s.missing > 0 then
        local count = folderCount(p.items)
        if count == nil or count == #s.missing then
            s.pad = writeFile(p.items .. "\\" .. PAD_NAME, "")
        end
    end
end

local function restore(proc)
    local s = session
    s.done = true
    local p = s.paths
    if s.pad then
        os.remove(p.items .. "\\" .. PAD_NAME)
    end
    local renderedNames = {}
    for i, fname in ipairs(readArray(proc.names)) do
        renderedNames[i] = text(fname) or ""
    end
    local renderedTex = {}
    proc.toTex:ForEach(function(i, elem)
        local name = renderedNames[i]
        if name then
            renderedTex[name:lower()] = elem:get()
        end
    end)
    local renderedBounds = {}
    if state.bounds and #renderedNames > 0 then
        local lines = readLines(p.bounds)
        if #lines == #renderedNames then
            for i, name in ipairs(renderedNames) do
                renderedBounds[name:lower()] = lines[i]
            end
        end
    end
    local krl = find(KISMET_RENDERING)
    local c = { game = newCounts(), mods = newCounts(), failed = 0 }
    local textures, bounds = {}, {}
    local total = #s.full
    for i = 1, total do
        local name, lower = s.names[i], s.lowers[i]
        local isGame = s.isGame[lower]
        local index = isGame and s.gameIndex or s.modIndex
        local counts = isGame and c.game or c.mods
        local fresh = renderedTex[lower]
        local file = s.source[lower]
        local tex = fresh
        if tex == nil and file and krl then
            tex = try(function() return krl:ImportFileAsTexture2D(proc, file) end)
        end
        if not valid(tex) then
            tex = nil
            c.failed = c.failed + 1
            if file then
                index[lower] = nil
            end
        elseif fresh == nil then
            counts.loaded = counts.loaded + 1
        end
        textures[i] = tex
        local b = renderedBounds[lower] or (file and index[lower] and index[lower].bounds)
        bounds[i] = b or FALLBACK_BOUNDS
        if fresh ~= nil then
            counts.rendered = counts.rendered + 1
            local folder = isGame and p.game or (s.cacheMods and p.mods)
            local storable = folder and (not state.bounds or renderedBounds[lower] ~= nil)
            if storable and copyFile(p.items .. "\\" .. name .. ".vimg", folder .. "\\" .. lower .. ".vimg") then
                index[lower] = { stamp = s.stamps[lower], bounds = renderedBounds[lower] }
                counts.added = counts.added + 1
            end
        end
    end
    if state.bounds then
        writeFile(p.bounds, table.concat(bounds, "\r\n"))
    end
    writeArray(proc.propsNames, s.full)
    proc.propsNames_len = total
    writeArray(proc.names, s.full)
    writeArray(proc.toTex, textures, total)
    writeIndex(p.game, p.key, s.gameIndex, renderedNames)
    if s.cacheMods then
        writeIndex(p.mods, p.key, s.modIndex)
    end
    resultHints(c, proc)
end

local function putNamesBack(proc)
    try(function()
        writeArray(proc.propsNames, session.full)
        proc.propsNames_len = #session.full
    end)
end

local function onSetPropNames(selfParam)
    local proc = try(function() return selfParam:get() end)
    if pcall(prepare, proc) then
        return
    end
    if session and session.full and not session.done then
        session.done = true
        putNamesBack(proc)
    elseif not session then
        session = { done = true }
    end
    hint("something went wrong, the game renders all icons this time", HINT_WARNING, proc, true)
end

local function onFinishProps(selfParam)
    local proc = try(function() return selfParam:get() end)
    if not session or session.done or not valid(proc) then
        return
    end
    if session.address ~= try(function() return proc:GetAddress() end) then
        return
    end
    if pcall(restore, proc) then
        return
    end
    putNamesBack(proc)
    writeFile(session.paths.game .. "\\" .. INDEX_NAME, "")
    if session.cacheMods then
        writeFile(session.paths.mods .. "\\" .. INDEX_NAME, "")
    end
    hint("something went wrong, some icons may be missing; restart the game to rebuild the cache", HINT_WARNING, proc, true)
end

local function hasAll(members, names)
    for _, name in ipairs(names) do
        if not members[name:lower()] then
            return false
        end
    end
    return true
end

local function detectGameVersion(cls)
    local functions = memberNames(cls, "function")
    local properties = memberNames(cls, "property")
    for _, version in ipairs(GAME_VERSIONS) do
        if hasAll(functions, version.functions) and hasAll(properties, version.properties) then
            return version
        end
    end
    return nil
end

local function gameVersion(context)
    return try(function()
        local out = {}
        StaticFindObject(GAME_LIB):gameVersion("", "", context, out)
        for key, v in pairs(out) do
            if type(key) == "string" and key:lower() == "version" then
                return text(v)
            end
        end
        return nil
    end)
end

local function warnUnsupported(context)
    if state.warned then
        return
    end
    state.warned = true
    local version = gameVersion(context)
    local game = version and ("VotV " .. version) or "this VotV version"
    hint(game .. " is not supported yet. Mod is off.", HINT_WARNING, context, true)
end

local function warnLater(context)
    if not state.blocked or state.warned or state.warnOnIcons or state.warnScheduled then
        return
    end
    if not valid(try(FindFirstOf, "mainGamemode_C")) then
        return
    end
    state.warnScheduled = true
    local function show()
        local gm = try(FindFirstOf, "mainGamemode_C")
        warnUnsupported(valid(gm) and gm or context)
    end
    if ExecuteWithDelay and ExecuteInGameThread then
        try(ExecuteWithDelay, WARNING_DELAY_MS, function() try(ExecuteInGameThread, show) end)
    else
        show()
    end
end

local function tryHook(context)
    if state.hooked or state.blocked then
        return
    end
    local cls = find(PROCESSOR_CLASS)
    if not cls then
        return
    end
    local finishPath = functionPath(cls, FINISH_FN)
    local version = detectGameVersion(cls)
    if not version then
        state.blocked = true
        if finishPath then
            state.warnOnIcons = pcall(RegisterHook, finishPath, function(selfParam)
                warnUnsupported(try(function() return selfParam:get() end))
            end)
        end
        return
    end
    state.bounds = version.bounds
    local setPath = functionPath(cls, SET_NAMES_FN)
    if setPath and finishPath then
        state.hooked = pcall(RegisterHook, setPath, onSetPropNames) and pcall(RegisterHook, finishPath, onFinishProps)
    end
end

local function onMapEvent(param)
    local context = try(function() return param:get() end)
    tryHook(context)
    warnLater(context)
end

try(createConfigEarly)

if RegisterInitGameStatePostHook then
    try(RegisterInitGameStatePostHook, onMapEvent)
end
try(RegisterHook, "/Script/Engine.PlayerController:ClientRestart", onMapEvent)
