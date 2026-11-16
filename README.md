# Panorama V8 Table Repair

A fully open-source, narrowly scoped repair script for **32-bit CS:GO on Windows**. Source: [`fix_7115142.lua`](fix_7115142.lua). Licensed under the [MIT License](LICENSE).

> Load the fix Lua script first and click **Repair**. After a successful repair, try loading the Lua script that was crashing.
>
> This only addresses the specific V8 pointer-table issue described below. It does **not** fix every Lua crash, and does not support CS2 / 64-bit hosts.

## 中文教程

### 这是做什么的？

此脚本针对特定的 Panorama / V8 地址表错误：32 个 V8 函数指针全部比当前 `v8.dll` 导出地址偏移 `+0x190000`。它从已加载的 `v8.dll` 获取实际地址，检查当前进程内存，只有符合严格匹配条件时才尝试修复。

**修复 Lua 完全开源**，没有代码混淆。此源码未包含网络请求或数据上传逻辑，但会读取和修改当前游戏进程内存，并写入一份本地备份；请先阅读源码并自行评估使用风险。

### 使用条件

- Windows 上的 **32 位 CS:GO**，不是 CS2。
- 提供 LuaJIT `ffi`、全局 `bit`、`ui.create`、`print_raw`、`files.write` 和 `files.read` 的脚本宿主。
- 宿主允许使用 FFI / Windows 内存 API；游戏进程已经加载兼容的 `v8.dll`。
- `nl\scripts` 目录存在且允许宿主读写。源码使用该路径保存备份；它也暗示了预期的宿主目录布局，但不能据此保证所有宿主版本兼容。

这不是可以通过普通 `lua fix_7115142.lua` 独立运行的脚本。

### 操作步骤

1. 下载 [`fix_7115142.lua`](https://github.com/1537271403/panorama-v8-table-repair/raw/refs/heads/main/fix_7115142.lua)，保存为 `.lua` 文件，而不是网页或 `.txt`。
2. 将文件放入宿主使用的 Lua 脚本目录（预期布局为 `nl\scripts`）。
3. 暂时不要加载之前导致崩溃的 Lua；**先加载修复 Lua**。如果其他脚本会自动加载，先关闭这些脚本的自动加载，必要时重启游戏。
4. 在宿主界面找到 **Panorama Repair / Verified V8 table repair** 面板，点击 **Repair**。
5. 查看带有 `[PanoramaRepair]` 前缀的控制台消息：
   - `32 pointers corrected and verified. Panorama behavior not yet tested.`：32 个指针已写入并回读验证；**尚未验证实际 Panorama 行为**，此时可以尝试加载之前崩溃的 Lua。
   - `Table already correct; nothing written`：找到的地址表已经正确，本次未修改；可以尝试加载目标 Lua，若仍崩溃则需要排查其他原因。
   - 错误消息：停止，不要反复尝试加载崩溃脚本。按下方说明排查。
6. 修复仅作用于当前进程，不会持久修改游戏 DLL。游戏重启后若同一问题再次出现，需要重新执行；卸载修复 Lua 不会撤销已完成的修复。

### 错误处理与备份

- `PanoramaRepair requires 32-bit CS:GO`：运行架构不兼容。
- `v8.dll is not loaded`、`Missing V8 export` 或 `Unexpected V8 export mapping`：V8 未加载或版本 / 内存映射不符合要求。
- `Expected one table, found ...; no repair`：没有匹配项或存在多个匹配项，脚本拒绝猜测修复目标。
- `Cannot verify original table backup; no repair`：检查 `nl\scripts` 目录、宿主文件访问权限及 FFI 配置。
- `rollback=...; protection=...` 或提示 `Restart the game`：**立即重启游戏后再继续**。不能把失败的回滚或内存保护恢复当作成功。
- 其他错误或修复后仍崩溃：保留完整控制台消息，检查宿主 / 游戏版本与目标 Lua 的兼容性；不要删掉校验条件强行修复。

写入前，脚本把原始错误地址表保存为 `nl\scripts\PanoramaRepair-original.hex`，并回读核对。这是 128 字节地址表的 256 字符十六进制备份，**不是游戏文件备份，也不是自动还原工具**。地址与进程有关，不要把该备份手动写入后续游戏进程。写入或验证失败时脚本会尝试恢复原表与页面保护；成功修复后不会在卸载时回滚，以免破坏其他脚本正在使用的共享接口。

## English tutorial

### Requirements

- **32-bit CS:GO on Windows**, not CS2 or a 64-bit host.
- A LuaJIT script host exposing `ffi`, global `bit`, `ui.create`, `print_raw`, `files.write`, and `files.read`.
- Permission to use FFI / Windows memory APIs, with a compatible `v8.dll` already loaded in the game process.
- An existing, readable and writable `nl\scripts` directory for the backup. This path reflects the script's expected layout, not a guarantee of compatibility with every host version.

This script cannot run standalone under an ordinary Lua interpreter.

### How to use

1. Download [`fix_7115142.lua`](https://github.com/1537271403/panorama-v8-table-repair/raw/refs/heads/main/fix_7115142.lua) and save it as a `.lua` file, not HTML or `.txt`.
2. Place it in your host's Lua script directory (expected layout: `nl\scripts`).
3. **Load the fix Lua script first**, before the Lua that was crashing. Disable auto-loading of affected scripts and restart the game first if necessary.
4. Open **Panorama Repair / Verified V8 table repair** in the host UI and click **Repair**.
5. Check the console for `[PanoramaRepair]`:
   - `32 pointers corrected and verified. Panorama behavior not yet tested.` means the pointer write passed read-back verification. Actual Panorama behavior still needs checking; now try loading the Lua that was crashing.
   - `Table already correct; nothing written` means no change was needed. If the target Lua still crashes, investigate another cause.
   - Any error means you should stop and investigate, not repeatedly load the crashing script.
6. Changes affect only the current process, not game DLL files on disk. Repeat after a game restart if the same issue returns. Unloading the repair Lua does not undo a successful repair.

### Troubleshooting and safety

A missing `v8.dll`, missing export, unexpected mapping, incompatible architecture, zero/multiple matching tables, or failed backup verification prevents repair. Check the game/host version, required APIs, and backup directory permissions. Do not bypass the checks.

If the output includes `rollback=...; protection=...` or asks you to restart, **restart the game before continuing**. A failed rollback or protection restore is not a successful repair. For other errors or continued crashes, retain the full console message and investigate compatibility with the affected Lua.

Before writing, the script saves and verifies `nl\scripts\PanoramaRepair-original.hex`: a 256-character hexadecimal representation of the original 128-byte table. This is not a game-file backup or an automatic restore tool. Addresses are process-specific; do not apply this backup to another game session. On write/verification failure, the script attempts rollback and page-protection restoration. It intentionally does not roll back a successful repair on unload because other scripts may still use the shared interface.

## Technical scope / 技术范围

- Resolves 32 named exports from the loaded `v8.dll` and verifies that their addresses belong to executable image mappings in that module.
- Scans the address range `0x10000` to below `0x80000000`, inspecting committed, private, read-only memory regions; each inspected region must be at most 32 MiB.
- Requires one complete, four-byte-aligned table matching either the correct export addresses or all addresses offset by `+0x190000`, in the exact listed order. Partial matches are never patched.
- Requires executable memory in the candidate's allocation and a table wholly contained within one 4 KiB page.
- Rechecks the table, verifies the local backup, temporarily changes page protection, writes 128 bytes, verifies the result, and restores protection. These checks narrow the target; they do not guarantee safe behavior on every host or eliminate concurrent memory-change risks.
- Loading the script creates the button; inspection and repair run only when **Repair** is clicked. No automatic Panorama invocation is performed.

## Verification status / 验证状态

The source was reviewed for this publication. **No in-game execution or crash-resolution result has been verified for this release.** The success log verifies pointer bytes, not that a particular Lua will stop crashing.

本次发布进行了源码审阅，**未完成游戏内运行及崩溃修复实测**。成功日志只表示指针数据已验证，不保证某个 Lua 一定不再崩溃。

## License / 许可证

MIT — see [LICENSE](LICENSE). The fix Lua script is fully open source. / 修复 Lua 完全开源。
