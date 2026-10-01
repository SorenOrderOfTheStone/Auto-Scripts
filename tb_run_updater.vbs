Set WShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")

' Get script directory and launch Updater.bat completely hidden (WindowStyle 0)
scriptDir = FSO.GetParentFolderName(WScript.ScriptFullName)
WShell.Run "cmd.exe /c """ & scriptDir & "\tb_Updater.bat""", 0, False

Set FSO = Nothing
Set WShell = Nothing