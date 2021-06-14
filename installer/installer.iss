[Setup]
AppName=MAXLancer
AppVersion=0.8
Uninstallable=no
WizardStyle=modern
DefaultDirName={code:get3DsMaxDir}
DirExistsWarning=no
OutputDir=.
OutputBaseFilename=maxlancer-setup
SetupIconFile=maxlancer.ico
DisableWelcomePage=no
WizardImageFile=side_large.bmp
WizardSmallImageFile=header_small.bmp
InfoBeforeFile=intro.rtf

[Files]
Source: "..\scripts\*"; DestDir:"{app}\scripts\MAXLancer"
Source: "..\startup\*"; DestDir:"{app}\scripts\Startup"
Source: "..\macroscripts\*"; DestDir:"{app}\MacroScripts"
Source: "..\shaders\*"; DestDir:"{app}\maps\fx\MAXLancer"
Source: "..\icons\*"; DestDir:"{app}\UI_ln\Icons\Dark\MAXLancer"
Source: "..\icons\*"; DestDir:"{app}\UI_ln\Icons\Light\MAXLancer"

[Code]
function get3DsMaxDir(Dir: String): String; // Last 3Ds Max 32-bit version was 2013 therefore supported versions are only 64-bit
begin
  if not(RegQueryStringValue(HKLM64, 'SOFTWARE\Autodesk\3dsMax\23.0', 'Installdir', result)) then // 2021
  if not(RegQueryStringValue(HKLM64, 'SOFTWARE\Autodesk\3dsMax\22.0', 'Installdir', result)) then // 2020
  if not(RegQueryStringValue(HKLM64, 'SOFTWARE\Autodesk\3dsMax\21.0', 'Installdir', result)) then // 2019
  if not(RegQueryStringValue(HKLM64, 'SOFTWARE\Autodesk\3dsMax\20.0', 'Installdir', result)) then // 2018
  if not(RegQueryStringValue(HKLM64, 'SOFTWARE\Autodesk\3dsMax\19.0', 'Installdir', result)) then
  begin
    MsgBox('Cannot find 3ds Max installation. Please specify path manually.', mbError, MB_OK);
    result := 'C:\MAXLancer';
  end;
end;