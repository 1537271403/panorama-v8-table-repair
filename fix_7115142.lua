-- CS:GO x86 only. Load before other Lua scripts; click Repair to inspect and apply.
-- Repairs only the exact 32-export table observed with a +0x190000 error.
local ffi = require("ffi")
assert(ffi.abi("32bit"), "PanoramaRepair requires 32-bit CS:GO")
ffi.cdef[[
typedef struct {
    void *BaseAddress; void *AllocationBase; unsigned long AllocationProtect;
    size_t RegionSize; unsigned long State; unsigned long Protect; unsigned long Type;
} PR_MEMORY_INFO;
void * __stdcall PR_GetModuleHandleA(const char *) __asm__("GetModuleHandleA");
void * __stdcall PR_GetProcAddress(void *, const char *) __asm__("GetProcAddress");
void * __stdcall PR_GetCurrentProcess(void) __asm__("GetCurrentProcess");
size_t __stdcall PR_VirtualQuery(const void *, PR_MEMORY_INFO *, size_t) __asm__("VirtualQuery");
int __stdcall PR_ReadProcessMemory(void *, const void *, void *, size_t, size_t *) __asm__("ReadProcessMemory");
int __stdcall PR_WriteProcessMemory(void *, void *, const void *, size_t, size_t *) __asm__("WriteProcessMemory");
int __stdcall PR_VirtualProtect(void *, size_t, unsigned long, unsigned long *) __asm__("VirtualProtect");
]]
local k = ffi.load("kernel32")
local exports = {
    "??0HandleScope@v8@@QAE@PAVIsolate@1@@Z",
    "??0Utf8Value@String@v8@@QAE@V?$Local@VValue@v8@@@2@@Z",
    "??1HandleScope@v8@@QAE@XZ",
    "??1Utf8Value@String@v8@@QAE@XZ",
    "?BooleanValue@Value@v8@@QBE_NXZ",
    "?Compile@Script@v8@@SA?AV?$Local@VScript@v8@@@2@V?$Local@VString@v8@@@2@PAVScriptOrigin@2@@Z",
    "?CreateHandle@HandleScope@v8@@KAPAPAVObject@internal@2@PAVIsolate@42@PAV342@@Z",
    "?DisposeGlobal@V8@v8@@CAXPAPAVObject@internal@2@@Z",
    "?Enter@Context@v8@@QAEXXZ",
    "?Enter@Isolate@v8@@QAEXXZ",
    "?Exception@TryCatch@v8@@QBE?AV?$Local@VValue@v8@@@2@XZ",
    "?Exit@Context@v8@@QAEXXZ",
    "?Exit@Isolate@v8@@QAEXXZ",
    "?Get@Object@v8@@QAE?AV?$Local@VValue@v8@@@2@I@Z",
    "?Get@Object@v8@@QAE?AV?$Local@VValue@v8@@@2@V32@@Z",
    "?GetCurrentContext@Isolate@v8@@QAE?AV?$Local@VContext@v8@@@2@XZ",
    "?GetEnteredContext@Isolate@v8@@QAE?AV?$Local@VContext@v8@@@2@XZ",
    "?GetPropertyNames@Object@v8@@QAE?AV?$Local@VArray@v8@@@2@XZ",
    "?Global@Context@v8@@QAE?AV?$Local@VObject@v8@@@2@XZ",
    "?GlobalizeReference@V8@v8@@CAPAPAVObject@internal@2@PAVIsolate@42@PAPAV342@@Z",
    "?HasCaught@TryCatch@v8@@QBE_NXZ",
    "?IsBoolean@Value@v8@@QBE_NXZ",
    "?IsFunction@Value@v8@@QBE_NXZ",
    "?IsNumber@Value@v8@@QBE_NXZ",
    "?IsObject@Value@v8@@QBE_NXZ",
    "?Length@Array@v8@@QBEIXZ",
    "?New@Number@v8@@SA?AV?$Local@VNumber@v8@@@2@PAVIsolate@2@N@Z",
    "?New@Object@v8@@SA?AV?$Local@VObject@v8@@@2@PAVIsolate@2@@Z",
    "?NewFromUtf8@String@v8@@SA?AV?$Local@VString@v8@@@2@PAVIsolate@2@PBDW4NewStringType@12@H@Z",
    "?NumberValue@Value@v8@@QBENXZ",
    "?Set@Object@v8@@QAE?AV?$Maybe@_N@2@V?$Local@VContext@v8@@@2@V?$Local@VValue@v8@@@2@1@Z",
    "?ToObject@Value@v8@@QBE?AV?$Local@VObject@v8@@@2@XZ"
}
local function address(p) return tonumber(ffi.cast("uintptr_t", p)) end
local process = k.PR_GetCurrentProcess()
local count = ffi.new("size_t[1]")
local info = ffi.new("PR_MEMORY_INFO[1]")
local function query(a)
    if k.PR_VirtualQuery(ffi.cast("void *", a), info, ffi.sizeof(info[0])) == 0 then return nil end
    local m = info[0]
    return {base=address(m.BaseAddress), allocation=address(m.AllocationBase),
        size=tonumber(m.RegionSize), state=tonumber(m.State),
        protect=tonumber(m.Protect), kind=tonumber(m.Type)}
end
local function read_bytes(a, n)
    local b = ffi.new("uint8_t[?]", n)
    count[0] = 0
    assert(k.PR_ReadProcessMemory(process, ffi.cast("void *", a), b, n, count) ~= 0
        and tonumber(count[0]) == n, "Cannot read candidate memory; no repair")
    return ffi.string(b, n)
end
local function patterns()
    local module = k.PR_GetModuleHandleA("v8.dll")
    assert(module ~= nil, "v8.dll is not loaded")
    local base = address(module)
    local good, bad = ffi.new("uint32_t[32]"), ffi.new("uint32_t[32]")
    for i, name in ipairs(exports) do
        local p = k.PR_GetProcAddress(module, name)
        assert(p ~= nil, "Missing V8 export: " .. name)
        local a = address(p)
        local m = query(a)
        assert(m and m.allocation == base and m.kind == 0x1000000
            and bit.band(m.protect, 0xF0) ~= 0, "Unexpected V8 export mapping")
        good[i-1], bad[i-1] = a, a + 0x190000
    end
    return ffi.string(good, 128), ffi.string(bad, 128)
end
-- Pure matching: all exports, exact order, aligned table; never patch a partial match.
local function find_tables(bytes, base, good, bad)
    local found = {}
    for _, entry in ipairs({{good, "correct"}, {bad, "broken"}}) do
        local start = 1
        while true do
            local at = bytes:find(entry[1], start, true)
            if not at then break end
            if (base + at - 1) % 4 == 0 then
                found[#found+1] = {address=base+at-1, state=entry[2]}
            end
            start = at + 1
        end
    end
    return found
end
local function inspect()
    local good, bad = patterns()
    local candidates, executable = {}, {}
    local a = 0x10000
    while a < 0x80000000 do
        local m = query(a)
        assert(m and m.size > 0 and m.base + m.size > a, "Incomplete address scan; no repair")
        if m.state == 0x1000 and m.kind == 0x20000 then
            if bit.band(m.protect, 0xF0) ~= 0 then executable[m.allocation] = true end
            if m.protect == 2 then
                assert(m.size <= 32*1024*1024, "Unexpected read-only region size; no repair")
                local bytes = read_bytes(m.base, m.size)
                for _, hit in ipairs(find_tables(bytes, m.base, good, bad)) do
                    hit.allocation = m.allocation
                    candidates[#candidates+1] = hit
                end
            end
        end
        a = m.base + m.size
    end
    assert(#candidates == 1, "Expected one table, found " .. #candidates .. "; no repair")
    local hit = candidates[1]
    assert(executable[hit.allocation], "Candidate allocation has no executable code")
    assert(math.floor(hit.address / 4096) == math.floor((hit.address + 127) / 4096),
        "Candidate crosses a page; no repair")
    return hit, good, bad
end
local panel = ui.create("Panorama Repair", "Verified V8 table repair")
local function report(message)
    print_raw("[PanoramaRepair] " .. message)
end
local function apply()
    local hit, good, bad = inspect()
    if hit.state == "correct" then return report("Table already correct; nothing written") end
    assert(read_bytes(hit.address, 128) == bad, "Table changed after inspection; no repair")
    local original_path = "nl\\scripts\\PanoramaRepair-original.hex"
    local encoded = bad:gsub(".", function(byte) return string.format("%02X", byte:byte()) end)
    assert(#encoded == 256, "Invalid table backup length; no repair")
    files.write(original_path, encoded)
    assert(files.read(original_path) == encoded, "Cannot verify original table backup; no repair")
    local previous = ffi.new("unsigned long[1]")
    local unused = ffi.new("unsigned long[1]")
    local p = ffi.cast("void *", hit.address)
    assert(k.PR_VirtualProtect(p, 128, 4, previous) ~= 0, "Cannot make table writable")
    local attempted = false
    local ok, err = pcall(function()
        assert(previous[0] == 2, "Protection changed; no repair")
        assert(read_bytes(hit.address, 128) == bad, "Table changed before write; no repair")
        count[0] = 0
        attempted = true
        assert(k.PR_WriteProcessMemory(process, p, good, 128, count) ~= 0
            and tonumber(count[0]) == 128, "Incomplete table write")
        assert(read_bytes(hit.address, 128) == good, "Table verification failed")
    end)
    if not ok then
        local restored = not attempted
        if attempted then
            count[0] = 0
            restored = k.PR_WriteProcessMemory(process, p, bad, 128, count) ~= 0
                and tonumber(count[0]) == 128
            local readable, bytes = pcall(read_bytes, hit.address, 128)
            restored = restored and readable and bytes == bad
        end
        local protection = k.PR_VirtualProtect(p, 128, previous[0], unused) ~= 0
        error(tostring(err) .. "; rollback=" .. tostring(restored) .. "; protection=" .. tostring(protection)
            .. ". Restart the game before continuing.")
    end
    assert(k.PR_VirtualProtect(p, 128, previous[0], unused) ~= 0,
        "Table corrected but protection restore failed. Restart the game.")
    report("32 pointers corrected and verified. Panorama behavior not yet tested.")
end
local function guarded(fn)
    return function()
        local ok, err = pcall(fn)
        if not ok then report(tostring(err)) end
    end
end
panel:button("Repair", guarded(apply))
-- Intentionally no automatic write, Panorama invocation, or shutdown rollback.
-- A shutdown rollback could invalidate other scripts still using the shared API.
