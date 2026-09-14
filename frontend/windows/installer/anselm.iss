; Inno Setup script for the Anselm Windows installer (tool/package.sh / release.yml run ISCC with
; the defines below). Per-user install under %LocalAppData%\Programs like VS Code's user setup, so
; no UAC prompt; the app and its Go sidecar sit side by side, which is where BackendController
; resolves the sidecar. Upgrades close a running Anselm first and reuse the same AppId.
;
; Anselm Windows 安装器脚本(打包脚本/发行工作流以下列 define 调用 ISCC)。按用户安装到
; %LocalAppData%\Programs(同 VS Code 的 user setup),不弹 UAC;app 与 Go sidecar 并排,正是
; BackendController 解析 sidecar 的位置。升级时先关掉运行中的 Anselm,并复用同一 AppId。
;
;   ISCC /DAppVersion=0.1.0 /DSourceDir=..\..\build\windows\x64\runner\Release /DOutputDir=..\..\dist anselm.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

[Setup]
AppId={{6D2C4B1E-7A3F-4C58-9E21-ANSELM000001}
AppName=Anselm
AppVersion={#AppVersion}
AppVerName=Anselm {#AppVersion}
AppPublisher=Anselm
AppPublisherURL=https://anselm.website
AppSupportURL=https://github.com/Cookiezisg/Anselm/issues
AppUpdatesURL=https://anselm.website/download/
VersionInfoVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\Anselm
DefaultGroupName=Anselm
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=Anselm-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\anselm.exe
UninstallDisplayName=Anselm
WizardStyle=modern
Compression=lzma2/ultra64
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
LicenseFile=..\..\..\LICENSE

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Anselm"; Filename: "{app}\anselm.exe"
Name: "{group}\Uninstall Anselm"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Anselm"; Filename: "{app}\anselm.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\anselm.exe"; Description: "{cm:LaunchProgram,Anselm}"; Flags: nowait postinstall skipifsilent
