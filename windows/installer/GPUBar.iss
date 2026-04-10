#define AppName "GPUBar"
#ifndef AppVersion
  #define AppVersion "1.1.0"
#endif
#ifndef SourceDir
  #error SourceDir must be provided to Inno Setup.
#endif

[Setup]
AppId={{7A2E93F7-AC8C-4F58-8B5D-3A4B972B2794}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Kyle Kim
DefaultDirName={localappdata}\Programs\GPUBar
DefaultGroupName=GPUBar
DisableProgramGroupPage=yes
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputBaseFilename=GPUBar-Setup-{#AppVersion}
SetupIconFile={#SourceDir}\GPUBar.Windows.exe
UninstallDisplayIcon={app}\GPUBar.Windows.exe
WizardStyle=modern
PrivilegesRequired=lowest
ChangesAssociations=yes

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\GPUBar"; Filename: "{app}\GPUBar.Windows.exe"
Name: "{autodesktop}\GPUBar"; Filename: "{app}\GPUBar.Windows.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Registry]
Root: HKCU; Subkey: "Software\Classes\gpubar"; ValueType: string; ValueName: ""; ValueData: "URL:GPUBar Protocol"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\gpubar"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\gpubar\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\GPUBar.Windows.exe,0"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\gpubar\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\GPUBar.Windows.exe"" ""%1"""; Flags: uninsdeletekey

[Run]
Filename: "{app}\GPUBar.Windows.exe"; Description: "Launch GPUBar"; Flags: nowait postinstall skipifsilent
