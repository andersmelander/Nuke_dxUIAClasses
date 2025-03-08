unit DevExNuker;

interface

implementation

uses
  DesignEditors,
  DesignIntf,
  ToolsAPI,
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  System.Win.Registry,
  WinApi.Windows,
  Vcl.Dialogs;

{$R 'DevExNuker.dcr'}

type
  TNukeSelectionEditor = class(TSelectionEditor)
  private
    FProc: TGetStrProc;
    procedure GetStrProc(const S: string);
  protected
    procedure DoGetUnits(SelectionEditorClass: TSelectionEditorClass; AProc: TGetStrProc);
  end;

procedure TNukeSelectionEditor.DoGetUnits(SelectionEditorClass: TSelectionEditorClass; AProc: TGetStrProc);
begin
  FProc := AProc;
  try

    var SelectionEditor := TSelectionEditor(SelectionEditorClass.Create(Designer));
    try
      SelectionEditor.RequiresUnits(GetStrProc);
    finally
      SelectionEditor.Free;
    end;

  finally
    FProc := nil;
  end;
end;

procedure TNukeSelectionEditor.GetStrProc(const S: string);
begin
  if not SameText(S, 'dxUIAClasses') then
    FProc(S);
end;

type
  TNuke_cxControlSelectionEditor = class(TNukeSelectionEditor)
  private
    class var FSelectionEditorClass: TSelectionEditorClass;
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

  TNuke_cxButtonSelectionEditor = class(TNukeSelectionEditor)
  private
    class var FSelectionEditorClass: TSelectionEditorClass;
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

procedure TNuke_cxControlSelectionEditor.RequiresUnits(Proc: TGetStrProc);
begin
  DoGetUnits(FSelectionEditorClass, Proc);
end;

procedure TNuke_cxButtonSelectionEditor.RequiresUnits(Proc: TGetStrProc);
begin
  DoGetUnits(FSelectionEditorClass, Proc);
end;

var
  OldRegisterSelectionEditorProc: TRegisterSelectionEditorProc;

procedure NukeSelectionEditorProc(AClass: TClass; AEditor: TSelectionEditorClass);
begin
  if (AEditor.ClassName = 'TcxControlSelectionEditor') then
  begin
    TNuke_cxControlSelectionEditor.FSelectionEditorClass := AEditor;
    AEditor := TNuke_cxControlSelectionEditor;
//    ShowMessage('TcxControlSelectionEditor redirected');
  end else
  if (AEditor.ClassName = 'TcxButtonSelectionEditor') then
  begin
    TNuke_cxButtonSelectionEditor.FSelectionEditorClass := AEditor;
    AEditor := TNuke_cxButtonSelectionEditor;
//    ShowMessage('TcxButtonSelectionEditor redirected');
  end;

  if (Assigned(OldRegisterSelectionEditorProc)) then
    OldRegisterSelectionEditorProc(AClass, AEditor);
end;

procedure FixRegistry(Notify: boolean);
begin
  var Fixed := False;

  var PackageName := TPath.GetFileNameWithoutExtension(GetModuleName(HInstance));

  var Registry := TRegistry.Create;
  try
    var Names := TStringList.Create;
    try
      var BaseKey := '\SOFTWARE\Embarcadero\BDS\23.0';
      var IOTAServices: IOTAServices50;
      if Supports(BorlandIDEServices, IOTAServices50, IOTAServices) then
        BaseKey := IOTAServices.GetBaseRegistryKey
      else
        ShowMessage('IOTAServices50.GetBaseRegistryKey not available. Registry path is defaulting to ' + BaseKey);

      Registry.OpenKey(BaseKey + '\Known Packages', True);
      Registry.GetValueNames(Names);

      // Reorder the package registry entries so all the DevExpress packages are loaded after this package
      for var Name in Names do
      begin

        // We don't care about any stuff that is loaded after ourselves
        if Name.Contains(PackageName) then
          break;

        var Value := Registry.ReadString(Name);
        if Value.EndsWith('by Developer Express Inc.', True) then
        begin
          // Delete entry and create it again
          Registry.DeleteValue(Name);
          Registry.WriteString(Name, Value);

          Fixed := True;
        end;

      end;

    finally
      Names.Free;
    end;
  finally
    Registry.Free;
  end;

  if Fixed and Notify then
    ShowMessageFmt('%s has changed the package load order.'#13'Delphi must be restarted.', [PackageName]);
end;


initialization
  // Add Splash Screen
  var SplashBitmap: HBITMAP := LoadBitmap(hInstance, 'DevExNuker24');
  (SplashScreenServices as IOTasplashScreenServices).AddPluginBitmap('Nuke dxUIAClasses', SplashBitmap, False, 'Open Source', '1.0');

  OldRegisterSelectionEditorProc := RegisterSelectionEditorProc;
  RegisterSelectionEditorProc := NukeSelectionEditorProc;

  FixRegistry(True);

finalization
  if (@RegisterSelectionEditorProc = @NukeSelectionEditorProc) then
    RegisterSelectionEditorProc := OldRegisterSelectionEditorProc;

  FixRegistry(False);

end.
