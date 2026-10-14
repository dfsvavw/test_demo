# VS Code Portable 固定目录迁移与升级手册

> 适用环境：Windows、VS Code ZIP 发行版、PowerShell。  
> 本次实际升级：1.105.1 → 1.137.0（x64）。  
> 原始目录：`E:\VSCode-win32-x64-1.109.5`（早期目录名称）；最终固定目录：`E:\VSCode`。

## 一、目标目录

```text
E:\VSCode\
├── Code.exe
├── bin\
├── resources\
└── data\
    ├── user-data\
    └── extensions\
```

- VS Code 程序：`E:\VSCode`
- Portable 用户数据：`E:\VSCode\data\user-data`
- Portable 扩展：`E:\VSCode\data\extensions`
- PATH：`E:\VSCode\bin`

升级时始终保留 `data`，并继续使用固定程序目录，不需要每次更改 PATH。

## 二、首次迁移到 Portable（只需一次）

### 1. 完全关闭 VS Code

```powershell
Get-Process Code -ErrorAction SilentlyContinue
Get-Process Code -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process Code -ErrorAction SilentlyContinue
```

最后一条无输出表示 VS Code 进程已结束。强制结束进程前先保存所有编辑内容。

### 2. 固定安装目录

如果尚未重命名：

```powershell
Rename-Item "E:\VSCode-win32-x64-1.109.5" "E:\VSCode"
```

### 3. 建立 Portable 目录

```powershell
New-Item -ItemType Directory -Force "E:\VSCode\data\user-data"
New-Item -ItemType Directory -Force "E:\VSCode\data\extensions"
```

### 4. 复制原用户数据和扩展

```powershell
Copy-Item "$env:APPDATA\Code\*" "E:\VSCode\data\user-data" -Recurse -Force
Copy-Item "$env:USERPROFILE\.vscode\extensions\*" "E:\VSCode\data\extensions" -Recurse -Force
```

对应来源通常为：

```text
C:\Users\kale\AppData\Roaming\Code  ->  E:\VSCode\data\user-data
C:\Users\kale\.vscode\extensions      ->  E:\VSCode\data\extensions
```

先复制，不要删除源目录。

### 5. 通过改名验证迁移

关闭 VS Code 后：

```powershell
Rename-Item "$env:APPDATA\Code" "Code.backup"
Rename-Item "$env:USERPROFILE\.vscode\extensions" "extensions.backup"
& "E:\VSCode\Code.exe"
```

确认设置、主题、扩展、OpenAI/Codex 功能正常，再考虑删除备份。注意：Portable 模式只管理 VS Code 本身的用户数据和扩展目录，某些第三方扩展或 CLI 仍可能写入用户目录。

## 三、清理旧 Cursor PATH 干扰（仅在有此问题时）

本次曾发现 `code` 命令指向已卸载 Cursor 的 `code.cmd`，甚至指向不再使用的 `C:\Users\guodg`。

查看持久 PATH：

```powershell
[Environment]::GetEnvironmentVariable("Path","User")
[Environment]::GetEnvironmentVariable("Path","Machine")
```

查看当前会话中的残留：

```powershell
$env:PATH -split ';' | Select-String -Pattern 'cursor|guodg'
```

仅在确定不再使用 Cursor 时，到 Windows **系统属性 → 高级 → 环境变量** 中从用户和系统 PATH 删除所有 `...\cursor\resources\app\bin` 项。勿删除其他软件的 PATH。修改后重开 PowerShell。

## 四、固定 code 命令到 E 盘

检查启动脚本：

```powershell
Test-Path "E:\VSCode\bin\code.cmd"
```

应返回 `True`。

如 PATH 尚未包含此目录，再执行（避免重复添加）：

```powershell
$userPath = [Environment]::GetEnvironmentVariable("Path","User")
if (($userPath -split ';') -notcontains 'E:\VSCode\bin') {
    [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(';') + ';E:\VSCode\bin'), "User")
}
```

重新打开 PowerShell，验证：

```powershell
Get-Command code | Format-List Source
code --version
code --list-extensions
```

`Source` 应为 `E:\VSCode\bin\code.cmd`。`openai.chatgpt` 即当前安装的 OpenAI 官方扩展标识，不需要另找 `openai.codex` 目录。

## 五、后续每次升级的标准流程

示例新版本 ZIP 已解压到：

```text
E:\tools\VSCode-win32-x64-1.137.0
```

### 1. 检查新解压目录

```powershell
Test-Path "E:\tools\VSCode-win32-x64-1.137.0\Code.exe"
Test-Path "E:\tools\VSCode-win32-x64-1.137.0\data"
```

第一项应为 `True`，第二项通常应为 `False`；若新目录已有 `data`，先查清来源，避免覆盖现有 Portable 数据。

### 2. 保存工作并关闭 VS Code

```powershell
Get-Process Code -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process Code -ErrorAction SilentlyContinue
```

### 3. 备份旧目录

确认不存在同名备份后执行：

```powershell
Test-Path "E:\VSCode_backup"
Rename-Item "E:\VSCode" "E:\VSCode_backup"
```

若检测到备份目录已存在，不要覆盖，先处理旧备份。

### 4. 将新版放到固定目录

```powershell
Copy-Item "E:\tools\VSCode-win32-x64-1.137.0" -Destination "E:\VSCode" -Recurse
```

确保复制成功且 `E:\VSCode\Code.exe` 存在后，再恢复数据。

### 5. 恢复 Portable 数据

```powershell
Move-Item "E:\VSCode_backup\data" "E:\VSCode\data"
```

这样程序版本更新，用户设置和扩展继续存放在固定的 `data` 目录中。本次采用的是“重命名旧目录 + 复制新版 + 搬回 data”，并非原目录原位覆盖。

### 6. 验证升级

```powershell
code --version
code --list-extensions
Get-Command code | Format-List Source
& "E:\VSCode\Code.exe"
```

本次成功验证的版本输出：

```text
1.137.0
645f29cc3176500b4b5762ba887cf2a7f0ffdf2c
x64
```

还要在 VS Code 中检查原有设置、OpenAI/Codex、Python、Java、Git 等扩展是否正常。部分扩展版本与登录状态可能受升级兼容性和第三方服务影响，因此必须验证，不应假定完全不变。

### 7. 清理旧程序备份和临时目录

**仅在新版及 Portable 扩展验证完成后**：

```powershell
Remove-Item "E:\VSCode_backup" -Recurse -Force
Remove-Item "E:\tools\VSCode-win32-x64-1.137.0" -Recurse -Force
```

如需回滚，在删备份前关闭 VS Code，把当前 `E:\VSCode\data` 安全保存，再恢复备份程序；注意新旧版本间用户数据可能存在兼容差异。

## 六、首次迁移完成后清理 C 盘旧目录

确认 Portable 已稳定运行、原文件确实已经备份并迁移后：

```powershell
Remove-Item "C:\Users\kale\AppData\Roaming\Code.backup" -Recurse -Force
Remove-Item "C:\Users\kale\.vscode\extensions.backup" -Recurse -Force
```

如果原目录未改名，则先检查其内容、确认不再被使用后再删除，**不能将原目录与备份目录命令混用**。

若最初旧安装目录仍存在，且不是正在使用的 `E:\VSCode`：

```powershell
Remove-Item "E:\VSCode-win32-x64-1.109.5" -Recurse -Force
```

**始终不要删除 `E:\VSCode\data`。**

## 七、以后升级简表

```powershell
# 先确认新 ZIP 解压路径、保存编辑内容、关闭 VS Code
Get-Process Code -ErrorAction SilentlyContinue | Stop-Process -Force

# 确保 E:\VSCode_backup 不存在
Rename-Item "E:\VSCode" "E:\VSCode_backup"

# 换成实际新版解压目录
Copy-Item "E:\tools\VSCode-win32-x64-1.137.0" -Destination "E:\VSCode" -Recurse

# 必须确认复制成功后再执行
Move-Item "E:\VSCode_backup\data" "E:\VSCode\data"

# 验证
code --version
code --list-extensions
Get-Command code | Format-List Source

# 启动 GUI 再检查扩展和设置
& "E:\VSCode\Code.exe"

# 确认完全正常后才清理
Remove-Item "E:\VSCode_backup" -Recurse -Force
```

**核心规则：固定 `E:\VSCode`、固定 `E:\VSCode\bin` PATH、升级时完整保留 `data`。**
