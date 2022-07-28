[Setup]
AppName=MAXLancer
AppVersion=0.97
Uninstallable=no
WizardStyle=modern
DefaultDirName={autopf}\Autodesk\3ds Max
DirExistsWarning=no
OutputDir=.
OutputBaseFilename=maxlancer-setup
SetupIconFile=maxlancer.ico
DisableWelcomePage=no
WizardImageFile=side_large_color.bmp
WizardSmallImageFile=header_small.bmp

[Files]
Source: "..\scripts\*"; DestDir:"{app}\scripts\MAXLancer"
Source: "..\startup\*"; DestDir:"{app}\scripts\Startup"
Source: "..\macroscripts\*"; Excludes: "*_.mcr"; DestDir:"{app}\MacroScripts"
Source: "..\shaders\*"; DestDir:"{app}\maps\fx\MAXLancer"
Source: "..\tools\*"; DestDir:"{app}\scripts\MAXLancer\tools"
Source: "..\icons\*"; DestDir:"{app}\UI_ln\Icons\Dark\MAXLancer"
Source: "..\icons\*"; DestDir:"{app}\UI_ln\Icons\Light\MAXLancer"

[Code]
var
  SelectPage: TWizardPage;
  SelectLabel: TLabel;
  SelectComboBox: TNewComboBox;
  ProductNames: TStringList;
  Installdirs: TStringList;

procedure SelectComboBoxChange(Sender: TObject);
begin
  if SelectComboBox.ItemIndex < InstallDirs.Count then WizardForm.DirEdit.Text := InstallDirs[SelectComboBox.ItemIndex];
end;

// Let user select 3ds max version to install into.
procedure DisplayVersionSelect;
var
  I: Integer;
begin
  SelectPage := CreateCustomPage(wpInfoBefore, 'Product version', 'Which Autodesk 3ds Max version to install into?');

  SelectLabel := TLabel.Create(WizardForm);
  SelectLabel.Parent := SelectPage.Surface;
  SelectLabel.Left := 0;
  SelectLabel.Top := 0;
  SelectLabel.Caption := 'Installed versions found:';

  SelectComboBox := TNewComboBox.Create(WizardForm);
  SelectComboBox.Parent := SelectPage.Surface;
  SelectComboBox.Left := 0;
  SelectComboBox.Top := SelectLabel.Top + SelectLabel.Height + 20;
  SelectComboBox.Width := SelectPage.Surface.Width;
  SelectComboBox.Anchors := [akLeft, akRight, akTop];
  SelectComboBox.Style := csDropDownList;
  SelectComboBox.OnChange := @SelectComboBoxChange;

  // Populate dropdown list.
  for I := 0 to ProductNames.Count - 1 do
    SelectComboBox.Items.Add(ProductNames[I]);

  // Auto-select first entry in list.
  if SelectComboBox.Items.Count > 0 then
  begin
    SelectComboBox.ItemIndex := 0;
    SelectComboBoxChange(WizardForm);
  end;
end;
  
procedure InitializeWizard;
var
  Subkeys: TArrayOfString;
  ProductName: String;
  Installdir: String;
  I: Integer;
begin

  // Get all subkeys (versions) from registry.
  if RegGetSubkeyNames(HKLM64, 'SOFTWARE\Autodesk\3dsMax', Subkeys) then
  begin
    ProductNames := TStringList.Create;
    Installdirs := TStringList.Create;

    // Loop through subkeys and collect ProductName and Installdir. Both must be present in subkey and installdir path must exist.
    for I := 0 to GetArrayLength(Subkeys) - 1 do
      if RegQueryStringValue(HKLM64, 'SOFTWARE\Autodesk\3dsMax\' + SubKeys[I], 'ProductName', ProductName) and
        RegQueryStringValue(HKLM64, 'SOFTWARE\Autodesk\3dsMax\' + Subkeys[I], 'Installdir', Installdir) and 
        DirExists(Installdir) then
      begin
        ProductNames.Add(ProductName);
        InstallDirs.Add(Installdir);
      end;

    if ProductNames.Count > 0 then DisplayVersionSelect();
  end;
end;