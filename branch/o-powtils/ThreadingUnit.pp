unit ThreadingUnit;

{$mode objfpc}{$H+}
//{$Define DebugMode}

interface

uses
  Classes, SysUtils, {CollectionUnit, }RequestsQueue, BaseUnix;
  
type
  { TDispactherThread }

  TDispactherThread= class (TThread)
  private
    FOutputPipeHandle: cint;
    FOutputPipeName: String;
    FRequestQueue: TRequestBlockingQueue;

    procedure SetOutputPipeName (const AValue: String);

   protected
     {
       Name and location of the pipe in which the output should be written.
     }
     property OutputPipeName: String read FOutputPipeName write SetOutputPipeName;

     procedure Execute; override;

   public
     property OutputPipeHandle: cint read FOutputPipeHandle;

    constructor Create (ReqQueue: TRequestBlockingQueue); overload;
    destructor Destroy; override;

  end;

  { TThreadCollection }

  TThreadCollection= class (TList)
  private
    function GetThread (Index: Integer): TDispactherThread;

  public
    property Thread [Index: Integer]: TDispactherThread
         read GetThread;

    constructor Create;
    destructor Destroy; override;
    
  end;

  { TThreadPool }

  TThreadPool= class (TObject)
  private
    FThreadCollection: TThreadCollection;

  public
    constructor Create (RequestPool: TRequestBlockingQueue;
                       n: Integer);
    destructor Destroy; override;

    procedure Execute;

    {This procedure can be implemented in a better way -- using message passing}
    procedure WaitUntilEndOfAllActiveThreads;
    
  end;
  
implementation

uses
  ResidentApplicationUnit, MyTypes, AbstractHandlerUnit;


{ TDispactherThread }

procedure TDispactherThread.SetOutputPipeName (const AValue: String);
begin
  FOutputPipeName:= AValue;

  FOutputPipeHandle:= FpOpen (FOutputPipeName, O_WRONLY);

end;

procedure TDispactherThread.Execute;
var
  NewRequest: TRequest;
  PageInstance: TAbstractHandler;
  
begin

  while True do
  begin

    NewRequest:= FRequestQueue.Delete;

(*$IFDEF DebugMode*)
    WriteLn ('TDispactherThread.Execute: Request to be Served is (', NewRequest.ToString, ')');
(*$ENDIF*)

    PageInstance:= Resident.GetPageHandler (NewRequest.PageName);
    OutputPipeName:= NewRequest.OutputPipe;

    try
(*$IFDEF DebugMode*)
      WriteLn ('TDispactherThread.Execute: Before Dispatch');
(*$ENDIF*)

      PageInstance.Dispatch (NewRequest, Self);

(*$IFDEF DebugMode*)
      WriteLn ('TDispactherThread.Execute: After Dispatch');
(*$ENDIF*)

    except
      on e: Exception do
        WriteLn (e.Message);

    end;

    if PageInstance.ShouldBeFreedManually then
      PageInstance.Free;

  end;

(*$IFDEF DebugMode*)
    WriteLn ('TDispactherThread.Execute: Terminating...');
(*$ENDIF*)

end;

constructor TDispactherThread.Create (ReqQueue: TRequestBlockingQueue);
begin
  inherited Create (True);

  FreeOnTerminate:= False;
  FRequestQueue:= ReqQueue;

end;

destructor TDispactherThread.Destroy;
begin
  FRequestQueue:= nil;

  inherited;

end;

{ TThreadPool }

constructor TThreadPool.Create (RequestPool: TRequestBlockingQueue;
            n: Integer);
var
  i: Integer;
  Ptr: PObject;

begin
  inherited Create;

  FThreadCollection:= TThreadCollection.Create;
  FThreadCollection.Count:= n;
  Ptr:= FThreadCollection.First;
  
  for i:= 0 to n- 1 do
  begin
    Ptr^:= TDispactherThread.Create (RequestPool);
    Inc (Ptr);
    
  end;

end;

procedure TThreadPool.Execute;
var
  i: Integer;

begin
  for i:= 0 to FThreadCollection.Count- 1 do
    FThreadCollection.Thread [i].Resume;

end;

destructor TThreadPool.Destroy;
begin
  FThreadCollection.Free;

  inherited;

end;

procedure TThreadPool.WaitUntilEndOfAllActiveThreads;
var
  i: Integer;
  Ptr: PObject;
  
begin
  i:= 0;
  Ptr:= FThreadCollection.First;
  
  while i< FThreadCollection.Count do
  begin
    if (Ptr^ as TThread).Suspended then
    begin
      Inc (Ptr);
      Inc (i);
      
    end
    else
      Sleep (100);
      
  end;

end;

{ TThreadCollection }

function TThreadCollection.GetThread (Index: Integer): TDispactherThread;
begin
{TODO:}
//  Result:= Items [Index] as TDispactherThread;
  
end;

constructor TThreadCollection.Create;
begin
  inherited;
  
end;

destructor TThreadCollection.Destroy;
var
  i: Integer;
  
begin
{$IFDEF DebugMode}
  WriteLn ('In TThreadCollection.Destroy');
{$ENDIF}

  for i:= 0 to Count- 1 do
  begin
    if Thread [i].Suspended then
      Thread [i].Resume;

{$IFDEF DebugMode}
  WriteLn ('Waiting for Thread ', i, ' to terminate');
{$ENDIF}

    WaitForThreadTerminate (Thread [i].ThreadID, 0);

{$IFDEF DebugMode}
  WriteLn ('Thread ', i, ' is terminated');
{$ENDIF}

    Thread [i].Free;

{$IFDEF DebugMode}
  WriteLn ('Thread ', i, ' has been freed');
{$ENDIF}

  end;

  Clear;
  inherited;
  
end;

end.

