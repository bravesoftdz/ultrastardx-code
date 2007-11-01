unit UDataBase;

interface

{$I switches.inc}

uses USongs,
     SQLiteTable3;

//--------------------
//DataBaseSystem - Class including all DB Methods
//--------------------
type
  TStatResult = record
    Case Typ: Byte of
      0: (Singer:     ShortString;
          Score:      Word;
          Difficulty: Byte;
          SongArtist: ShortString;
          SongTitle:  ShortString);

      1: (Player:     ShortString;
          AverageScore: Word);

      2: (Artist: ShortString;
          Title:  ShortString;
          TimesSung:  Word);

      3: (ArtistName:   ShortString;
          TimesSungtot: Word);
  end;
  AStatResult = Array of TStatResult;
  
  TDataBaseSystem = class
    private
      ScoreDB: TSqliteDatabase;
      sFilename: string;
      
    public


    property Filename: String read sFilename;
    
    Destructor Free;

    Procedure Init(const Filename: string);
    procedure ReadScore(var Song: TSong);
    procedure AddScore(var Song: TSong; Level: integer; Name: string; Score: integer);
    procedure WriteScore(var Song: TSong);

    Function  GetStats(var Stats: AStatResult; const Typ, Count: Byte; const Page: Cardinal; const Reversed: Boolean): Boolean;
    Function  GetTotalEntrys(const Typ: Byte): Cardinal;
  end;

var
  DataBase: TDataBaseSystem;

implementation

uses IniFiles, SysUtils;

const
  cUS_Scores = 'us_scores';
  cUS_Songs  = 'us_songs';

//--------------------
//Create - Opens Database and Create Tables if not Exist
//--------------------

Procedure TDataBaseSystem.Init(const Filename: string);
begin
  writeln( 'TDataBaseSystem.Init' );
  
  //Open Database
  ScoreDB   := TSqliteDatabase.Create( Filename );
  sFilename := Filename;

  try
    //Look for Tables => When not exist Create them
    if not ScoreDB.TableExists( cUS_Scores ) then
    begin
      ScoreDB.execsql('CREATE TABLE `'+cUS_Scores+'` (`SongID` INT( 11 ) NOT NULL , `Difficulty` INT( 1 ) NOT NULL , `Player` VARCHAR( 150 ) NOT NULL , `Score` INT( 5 ) NOT NULL );');
      writeln( 'TDataBaseSystem.Init - CREATED US_Scores' );
    end;

    if not ScoreDB.TableExists( cUS_Songs ) then
    begin
      ScoreDB.execsql('CREATE TABLE `'+cUS_Songs+'` (`ID` INTEGER PRIMARY KEY, `Artist` VARCHAR( 255 ) NOT NULL , `Title` VARCHAR( 255 ) NOT NULL , `TimesPlayed` int(5) NOT NULL );');
      writeln( 'TDataBaseSystem.Init - CREATED US_Songs' );
    end;
    
     //Not possible because of String Limitation to 255 Chars //Need to rewrite Wrapper
    {if not ScoreDB.TableExists('US_SongCache') then
      ScoreDB.ExecSQL('CREATE TABLE `US_SongCache` (`Path` VARCHAR( 255 ) NOT NULL , `Filename` VARCHAR( 255 ) NOT NULL , `Title` VARCHAR( 255 ) NOT NULL , `Artist` VARCHAR( 255 ) NOT NULL , `Folder` VARCHAR( 255 ) NOT NULL , `Genre` VARCHAR( 255 ) NOT NULL , `Edition` VARCHAR( 255 ) NOT NULL , `Language` VARCHAR( 255 ) NOT NULL , `Creator` VARCHAR( 255 ) NOT NULL , `Cover` VARCHAR( 255 ) NOT NULL , `Background` VARCHAR( 255 ) NOT NULL , `Video` VARCHAR( 255 ) NOT NULL , `VideoGap` FLOAT NOT NULL , `Gap` FLOAT NOT NULL , `Start` FLOAT NOT NULL , `Finish` INT( 11 ) NOT NULL , `BPM` INT( 5 ) NOT NULL , `Relative` BOOLEAN NOT NULL , `NotesGap` INT( 11 ) NOT NULL);');}


  finally
    writeln( cUS_Songs +' Exist : ' + inttostr( integer(ScoreDB.TableExists( cUS_Songs )) ) );
    writeln( cUS_Scores +' Exist : ' + inttostr( integer(ScoreDB.TableExists( cUS_Scores )) ) );
  //ScoreDB.Free;
  end;

end;

//--------------------
//Free - Frees Database
//--------------------
Destructor TDataBaseSystem.Free;
begin
  writeln( 'TDataBaseSystem.Free' );

  freeandnil( ScoreDB );
end;

//--------------------
//ReadScore - Read Scores into SongArray
//--------------------
procedure TDataBaseSystem.ReadScore(var Song: TSong);
var
  TableData: TSqliteTable;
  Dif: Byte;
begin
  if not assigned( ScoreDB ) then
    exit;


  //ScoreDB := TSqliteDatabase.Create(sFilename);
  try
    try
    //Search Song in DB
    TableData := ScoreDB.GetTable('SELECT `Difficulty`, `Player`, `Score` FROM `'+cUS_Scores+'` WHERE `SongID` = (SELECT `ID` FROM `us_songs` WHERE `Artist` = "' + Song.Artist + '" AND `Title` = "' + Song.Title + '" LIMIT 1) ORDER BY `Score` DESC  LIMIT 15');

    //Empty Old Scores
    SetLength (Song.Score[0], 0);
    SetLength (Song.Score[1], 0);
    SetLength (Song.Score[2], 0);

    while not TableData.Eof do//Go through all Entrys
    begin//Add one Entry to Array
      Dif := StrtoInt(TableData.FieldAsString(TableData.FieldIndex['Difficulty']));
      if (Dif>=0) AND (Dif<=2) then
      begin
        SetLength(Song.Score[Dif], Length(Song.Score[Dif]) + 1);

        Song.Score[Dif, high(Song.Score[Dif])].Name  := TableData.FieldAsString(TableData.FieldIndex['Player']);
        Song.Score[Dif, high(Song.Score[Dif])].Score := StrtoInt(TableData.FieldAsString(TableData.FieldIndex['Score']));
      end;
      TableData.Next;
      
    end; // While not TableData.EOF

    except //Im Fehlerfall
      for Dif := 0 to 2 do
      begin
      SetLength(Song.Score[Dif], 1);
      Song.Score[Dif, 1].Name := 'Error Reading ScoreDB';
      end;
    end;
    
  finally // Try Finally
  //ScoreDb.Free;
  end;
end;

//--------------------
//AddScore - Add one new Score to DB
//--------------------
procedure TDataBaseSystem.AddScore(var Song: TSong; Level: integer; Name: string; Score: integer);
var
ID: Integer;
TableData: TSqliteTable;
begin
  if not assigned( ScoreDB ) then
    exit;

  //ScoreDB := TSqliteDatabase.Create(sFilename);
  try
  //Prevent 0 Scores from being added
  if (Score > 0) then
  begin

    ID := ScoreDB.GetTableValue('SELECT `ID` FROM `'+cUS_Songs+'` WHERE `Artist` = "' + Song.Artist + '" AND `Title` = "' + Song.Title + '"');
    if ID = 0 then //Song doesn't exist -> Create
    begin
      ScoreDB.ExecSQL ('INSERT INTO `'+cUS_Songs+'` ( `ID` , `Artist` , `Title` , `TimesPlayed` ) VALUES (NULL , "' + Song.Artist + '", "' + Song.Title + '", "0");');
      ID := ScoreDB.GetTableValue('SELECT `ID` FROM `US_Songs` WHERE `Artist` = "' + Song.Artist + '" AND `Title` = "' + Song.Title + '"');
      if ID = 0 then //Could not Create Table
        exit;
    end;
    //Create new Entry
    ScoreDB.ExecSQL('INSERT INTO `'+cUS_Scores+'` ( `SongID` , `Difficulty` , `Player` , `Score` ) VALUES ("' + InttoStr(ID) + '", "' + InttoStr(Level) + '", "' + Name + '", "' + InttoStr(Score) + '");');

    //Delete Last Position when there are more than 5 Entrys
    if ScoreDB.GetTableValue('SELECT COUNT(`SongID`) FROM `'+cUS_Scores+'` WHERE `SongID` = "' + InttoStr(ID) + '" AND `Difficulty` = "' + InttoStr(Level) +'"') > 5 then
    begin
      TableData := ScoreDB.GetTable('SELECT `Player`, `Score` FROM `'+cUS_Scores+'` WHERE SongID = "' + InttoStr(ID) + '" AND `Difficulty` = "' + InttoStr(Level) +'" ORDER BY `Score` ASC LIMIT 1');
      ScoreDB.ExecSQL('DELETE FROM `US_Scores` WHERE SongID = "' + InttoStr(ID) + '" AND `Difficulty` = "' + InttoStr(Level) +'" AND `Player` = "' + TableData.FieldAsString(TableData.FieldIndex['Player']) + '" AND `Score` = "' + TableData.FieldAsString(TableData.FieldIndex['Score']) + '"');
    end;

  end;
  finally
  //ScoreDB.Free;
  end;
end;

//--------------------
//WriteScore - Not needed with new System; But used for Increment Played Count
//--------------------
procedure TDataBaseSystem.WriteScore(var Song: TSong);
begin
  if not assigned( ScoreDB ) then
    exit;
    
  try
    //Increase TimesPlayed
    ScoreDB.ExecSQL ('UPDATE `'+cUS_Songs+'` SET `TimesPlayed` = `TimesPlayed` + "1" WHERE `Title` = "' + Song.Title + '" AND `Artist` = "' + Song.Artist + '";');
  except

  end;
end;

//--------------------
//GetStats - Write some Stats to Array, Returns True if Chossen Page has Entrys
//Case Typ of
//0 - Best Scores
//1 - Best Singers
//2 - Most sung Songs
//3 - Most popular Band
//--------------------
Function TDataBaseSystem.GetStats(var Stats: AStatResult; const Typ, Count: Byte; const Page: Cardinal; const Reversed: Boolean): Boolean;
var
  Query: String;
  TableData: TSqliteTable;
begin
  Result := False;

  if not assigned( ScoreDB ) then
    exit;

  if (Length(Stats) < Count) then
    Exit;

  {Todo:  Add Prevention that only Players with more than 5 Scores are Selected at Typ 2}

  //Create Query
  Case Typ of
    0: Query := 'SELECT `Player` , `Difficulty` , `Score` , `Artist` , `Title` FROM `'+cUS_Scores+'` INNER JOIN `US_Songs` ON (`SongID` = `ID`) ORDER BY `Score`';
    1: Query := 'SELECT `Player` , ROUND (Sum(`Score`) / COUNT(`Score`)) FROM `'+cUS_Scores+'` GROUP BY `Player` ORDER BY (Sum(`Score`) / COUNT(`Score`))';
    2: Query := 'SELECT `Artist` , `Title` , `TimesPlayed` FROM `'+cUS_Scores+'` ORDER BY `TimesPlayed`';
    3: Query := 'SELECT `Artist` , Sum(`TimesPlayed`) FROM `'+cUS_Scores+'` GROUP BY `Artist` ORDER BY Sum(`TimesPlayed`)';
  end;

  //Add Order Direction
  If Reversed then
    Query := Query + ' ASC'
  else
    Query := Query + ' DESC';

  //Add Limit
  Query := Query + ' LIMIT ' + InttoStr(Count * Page) + ', ' + InttoStr(Count) + ';';

  //Execute Query
  //try
    TableData := ScoreDB.GetTable(Query);
  {except
    exit;
  end;}

  //if Result empty -> Exit
  if (TableData.RowCount < 1) then
    exit;

  //Copy Result to Stats Array
  while not TableData.Eof do
  begin
    Stats[TableData.Row].Typ := Typ;

    Case Typ of
      0:begin
          Stats[TableData.Row].Singer := TableData.Fields[0];

          Stats[TableData.Row].Difficulty := StrtoIntDef(TableData.Fields[1], 0);

          Stats[TableData.Row].Score := StrtoIntDef(TableData.Fields[2], 0){TableData.FieldAsInteger(2)};
          Stats[TableData.Row].SongArtist := TableData.Fields[3];
          Stats[TableData.Row].SongTitle := TableData.Fields[4];
        end;

        1:begin
          Stats[TableData.Row].Player := TableData.Fields[0];
          Stats[TableData.Row].AverageScore := StrtoIntDef(TableData.Fields[1], 0);
        end;

        2:begin
          Stats[TableData.Row].Artist := TableData.Fields[0];
          Stats[TableData.Row].Title  := TableData.Fields[1];
          Stats[TableData.Row].TimesSung  := StrtoIntDef(TableData.Fields[2], 0);
        end;

        3:begin
          Stats[TableData.Row].ArtistName := TableData.Fields[0];
          Stats[TableData.Row].TimesSungtot := StrtoIntDef(TableData.Fields[1], 0);
        end;

    end;

    TableData.Next;
  end;

  Result := True;
end;

//--------------------
//GetTotalEntrys - Get Total Num of entrys for a Stats Query
//--------------------
Function  TDataBaseSystem.GetTotalEntrys(const Typ: Byte): Cardinal;
var Query: String;
begin
  if not assigned( ScoreDB ) then
    exit;
  try
    //Create Query
    Case Typ of
      0: begin
           Query := 'SELECT COUNT(`SongID`) FROM `'+cUS_Scores+'`;';
           if not ScoreDB.TableExists( cUS_Scores ) then
             exit;
         end;
      1: begin
           Query := 'SELECT COUNT(DISTINCT `Player`) FROM `'+cUS_Scores+'`;';
           if not ScoreDB.TableExists( cUS_Scores ) then
             exit;
         end;
      2: begin
           Query := 'SELECT COUNT(`ID`) FROM `'+cUS_Scores+'`;';
           if not ScoreDB.TableExists( cUS_Songs ) then
             exit;
         end;
      3: begin
           Query := 'SELECT COUNT(DISTINCT `Artist`) FROM `'+cUS_Songs+'`;';
           if not ScoreDB.TableExists( cUS_Songs ) then
             exit;
         end;
    end;
  
    Result := ScoreDB.GetTableValue(Query);
  except
    // TODO : JB_Linux - Why do we get these exceptions on linux !!
    on E:ESQLiteException DO  // used to handle : Could not retrieve data "SELECT COUNT(`ID`) FROM `US_Songs`;" : SQL logic error or missing database
                              // however, we should pre-empt this error... and make sure the database DOES exist.
    begin
      result := 0;
    end;
  end;

end;

end.
