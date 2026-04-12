; Inno Setup 安装脚本 - 万物一心
; 下载 Inno Setup: https://jrsoftware.org/isdl.php

#define MyAppName "万物一心"
#define MyAppVersion "1.2.0"
#define MyAppPublisher "灵匠科技-万物一心团队-内部工具-ai比赛版"
#define MyAppExeName "wwyx_chat.exe"

[Setup]
AppId={{FLOATING-CHAT-2024-INTERNAL}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=installer
OutputBaseFilename=万物一心_v{#MyAppVersion}_安装程序
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
SetupIconFile=assets\images\deepthink.ico


[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"; Flags: unchecked
Name: "autostart"; Description: "开机自动启动"; GroupDescription: "附加任务:"; Flags: unchecked

[Files]
; 主程序
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; DLL 文件
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; 数据文件
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; 资源文件
Source: "assets\images\redboy.png"; DestDir: "{app}\assets\images"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "立即运行 {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"
Type: filesandordirs; Name: "{app}\assets"
