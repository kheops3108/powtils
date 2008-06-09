{ Simple web based command line utility to control a web server that doesn't 
  have shell/ssh/telnet access available

  Notes:
    -tested on linux, some testing on MS Windows

  Author: 
    Lars (L505
    http://z505.com
}
program webcmd1;
{$mode objfpc} {$H+}

uses  
  {$ifdef unix}unix, baseunix, compactsysutils,{$endif} 
  {$ifdef windows}sysutils,{$endif}
  pwinit, pwmain, pwenvvar, pwsubstr, pwfileutil, pwtypes, htmout;

procedure err(const s: astr);
begin
  out('<br><b>Error:</b> ' + s);
end;

{$ifdef windows}
 { find program command (before first space) }
 function GetCmdPath(const cmd: astr): astr;
 var i: integer;
 begin
   result:= '';
   if cmd = '' then exit;
   for i:= 1 to length(cmd) do begin
     if cmd[i] = ' ' then exit;
     result:= result + cmd[i];
   end;
 end;
 
 { find program arguments (after space) }
 function GetCmdArgs(const cmd: astr): astr;
 var i, spacefound: integer;
 begin
   result:= ''; spacefound:= 0;
   if cmd = '' then exit;
   for i:= 1 to length(cmd) do begin
     if spacefound > 1 then result:= result + cmd[i];
     if cmd[i] = ' ' then inc(spacefound);
   end;
 end;
{$endif}

function ExecCmd(const cmd: astr): int32;
begin
 {$ifdef unix}   result:= fpSystem(cmd);{$endif} 
 {$ifdef windows}result:= executeprocess(GetCmdPath(cmd), GetCmdArgs(cmd));{$endif}
end;

procedure RunAndShowCmd(const cmd: astr);
var err: int32;
begin
  out('<hr style="border-style: solid; border-width: 1px;">');
  out('Output of command: <b>'+ cmd + '</b>');
  outln('<textarea style="width:100%; font-size:0.9em;" ROWS=40>');
  // execute command such as // ls/mv/cp/tar etc.
  err:= ExecCmd(cmd);
  outln(  '-------------------------------------------------------------------------');
  outln(  'WEBCMD NOTE: command exited with status: ' + inttostr(err));
  outln('</textarea>');
end;

function FormPosted: boo;
begin
  result:= false;
  if isPostVar('form1posted') then result:= true;
end;

type THtmForm = record cmd: astr; end;
var HtmForm: THtmForm;

{ get incoming cmd and params }
procedure GetPostedVars;
begin
  HtmForm.cmd:= GetCgiVar_S('ed1', 0);
end;

{ process command, notify it was attempted }
procedure ProcessCommand;
begin
  RunAndShowCmd(HtmForm.cmd);
  Notify;
end;

procedure Setup;
  { server document root full path is useful as a special macro }
  procedure ExpandDocRootMacro(var s: astr);
  begin
    s:= SubstrReplace(s, '{$DOCROOT}', SERV.DocRoot() );
    s:= SubstrReplace(s, '$DOCROOT', SERV.DocRoot() );
  end;
begin
  GetPostedVars;
  ExpandDocRootMacro(HtmForm.cmd);
  // setup $remembercmd macro var for later use with OutF or TemplateOut
  SetVar('remembercmd', HtmForm.cmd);
end;

begin
  StartPage;
  Setup;
  JotForm;
  if FormPosted then ProcessCommand;
  EndPage;
end.
