{
  Export information in a CSV
  Useful to know what needs to be tested or explored when using a given set of mods.
}
unit Modsvaskr_DumpInfo;

var
  slCsv: TStringList;

// Called before processing
// You can remove it if script doesn't require initialization code
function Initialize: integer;
begin
  AddMessage('Export useful info in CSV file...');
  slCsv := TStringList.Create;
  Result := 0;
end;

// called for every record selected in xEdit
function Process(e: IInterface): integer;
var
  worldElement : IwbContainer;
  modFile : IwbFile;
  idxMaster : integer;
  masters : string;
begin
  // AddMessage('Processing: ' + FullPath(e));
  if Signature(e) = 'CELL' then begin
    if GetNativeValue(ElementByPath(e, 'DATA')) and 1 = 0 then begin
      // AddMessage('Exterior cell');
      if GetNativeValue(ElementByPath(e, 'Record Header\Record Flags')) and 1024 = 0 then begin
        // AddMessage('Not persistent');
        worldElement := ChildrenOf(GetContainer(GetContainer(GetContainer(e))));
        slCsv.Add(
          '"' + GetFileName(GetFile(e)) + '",' +
          Signature(e) + ',' +
          IntToHex(FixedFormID(e), 8) + ',' +
          'cow,' +
          GetElementEditValues(worldElement, 'EDID') + ',' +
          GetElementEditValues(e, 'XCLC\X') + ',' +
          GetElementEditValues(e, 'XCLC\Y')
        );
      end;
    end else begin
      // AddMessage('Interior cell');
      slCsv.Add(
        '"' + GetFileName(GetFile(e)) + '",' +
        Signature(e) + ',' +
        IntToHex(FixedFormID(e), 8) + ',' +
        'coc,' +
        GetElementEditValues(e, 'EDID')
      );
    end;
  end else if (Signature(e) = 'NPC_') and (ElementExists(e, 'FULL')) then begin
    slCsv.Add(
      '"' + GetFileName(GetFile(e)) + '",' +
      Signature(e) + ',' +
      IntToHex(FixedFormID(e), 8) + ',' +
      GetElementEditValues(e, 'FULL')
    );
  end else if (Signature(e) = 'TES4') then begin
    modFile := GetFile(e);
    masters := '';
    for idxMaster := 0 to MasterCount(modFile) - 1 do
      masters := masters + ',' + GetFileName(MasterByIndex(modFile, idxMaster));
    slCsv.Add(
      '"' + GetFileName(GetFile(e)) + '",' +
      Signature(e) + ',' +
      masters
    );
  end;
  Result := 0;
end;

// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
  slCsv.SaveToFile(ProgramPath + 'Edit Scripts\Modsvaskr_ExportedDumpInfo.csv');
  slCsv.Free;
  AddMessage('Export done in ' + ProgramPath + 'Edit Scripts\Modsvaskr_ExportedDumpInfo.csv');
  // Application.Terminate;
  // ExitProcess(0);
  Result := 0;
end;

end.
