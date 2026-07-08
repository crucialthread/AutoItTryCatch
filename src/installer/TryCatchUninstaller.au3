; #INDEX# =======================================================================================================================
; Title .........: AutoIt TryCatch - Uninstaller
; Version .......: 0.0.1
; AutoIt Version : 3.3.18.0
; Author ........: Crucial Thread
; Description ...: Uninstaller for the AutoIt TryCatch solution.
;                  Reads installation paths from the registry written by TryCatchInstaller.au3,
;                  removes all installed files, cleans up registry entries, removes the TryCatch
;                  Lint block from SciTEUser.properties, and removes the Add/Remove Programs entry.
;                  Removes the Vendor folder only if empty after uninstall.
;                  Removes our path from the AutoIt Include registry value without affecting
;                  other vendor paths that may be registered there.
; Note ..........: Requires administrator rights to delete from Program Files.
; Note ..........: Source files are embedded into the compiled .exe via FileInstall at
;                  compile time, then copied to the lint install folder so Add/Remove Programs can find it.
; ===============================================================================================================================

#RequireAdmin
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ButtonConstants.au3>
#include <StaticConstants.au3>
#include <ProgressConstants.au3>
#include <MsgBoxConstants.au3>
#include <File.au3>

; ===============================================================================================================================
; Constants
; ===============================================================================================================================

Global Const $UNINSTALLER_TITLE  = "AutoIt TryCatch Solution Uninstall"
Global Const $WIN_WIDTH          = 500
Global Const $WIN_HEIGHT         = 400
Global Const $REG_INSTALL_KEY    = "HKEY_LOCAL_MACHINE\SOFTWARE\AutoIt TryCatch"
Global Const $REG_UNINSTALL_KEY  = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AutoItTryCatch"
Global Const $REG_AUTOIT_INCLUDE = "HKEY_CURRENT_USER\Software\AutoIt v3\AutoIt"
Global Const $REG_SCITE_HOME_KEY = "HKEY_CURRENT_USER\Environment"

; ===============================================================================================================================
; Global state
; ===============================================================================================================================

Global $g_sInstallType    = ""
Global $g_sIncludePath    = ""
Global $g_sLintPath       = ""
Global $g_sSciTEUserProps = ""

; ===============================================================================================================================
; Entry point
; ===============================================================================================================================

_Main()

Func _Main()
    If Not __ReadInstallRecord() Then
        MsgBox($MB_OK + $MB_ICONERROR, $UNINSTALLER_TITLE, _
            "AutoIt TryCatch Solution installation record was not found." & @CRLF & @CRLF & _
            "It may have already been uninstalled.")
        Exit
    EndIf
    __RunWizard()
EndFunc

; ===============================================================================================================================
; Read install record
; ===============================================================================================================================

Func __ReadInstallRecord()
    $g_sInstallType = RegRead($REG_INSTALL_KEY, "InstallType")
    If @error Then Return False

    $g_sLintPath = RegRead($REG_INSTALL_KEY, "LintPath")
    If @error Then Return False

    If $g_sInstallType = "Full" Then
        $g_sIncludePath = RegRead($REG_INSTALL_KEY, "IncludePath")
        If @error Then Return False
    EndIf

    ; SciTE user home for SciTEUser.properties
    Local $sSciTEUserHome = RegRead($REG_SCITE_HOME_KEY, "SCITE_USERHOME")
    If @error Or Not FileExists($sSciTEUserHome) Then
        $sSciTEUserHome = @LocalAppDataDir & "\AutoIt v3\SciTE"
    EndIf
    $g_sSciTEUserProps = $sSciTEUserHome & "\SciTEUser.properties"

    Return True
EndFunc

; ===============================================================================================================================
; Wizard
; ===============================================================================================================================

Func __RunWizard()
    Local $hWin = GUICreate($UNINSTALLER_TITLE, $WIN_WIDTH, $WIN_HEIGHT, -1, -1, _
        BitOR($WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX))

    ; --- Header bar ---
    Local $idHeader = GUICtrlCreateLabel("", 0, 0, $WIN_WIDTH, 70)
    GUICtrlSetBkColor($idHeader, 0xFFFFFF)
    Local $idHeaderTitle = GUICtrlCreateLabel("AutoIt TryCatch Solution", 15, 12, 400, 20)
    GUICtrlSetFont($idHeaderTitle, 11, 800)
    GUICtrlSetBkColor($idHeaderTitle, 0xFFFFFF)
    Local $idHeaderSub = GUICtrlCreateLabel("", 15, 36, 460, 30)
    GUICtrlSetBkColor($idHeaderSub, 0xFFFFFF)
    Local $idSeparator = GUICtrlCreateLabel("", 0, 70, $WIN_WIDTH, 2)
    GUICtrlSetBkColor($idSeparator, 0xCCCCCC)

    ; --- Footer buttons ---
    Local $idBtnNext   = GUICtrlCreateButton("Next >",  390, 360, 85, 25)
    Local $idBtnBack   = GUICtrlCreateButton("< Back",  300, 360, 85, 25)
    Local $idBtnCancel = GUICtrlCreateButton("Cancel",  205, 360, 85, 25)
    Local $idFooterSep = GUICtrlCreateLabel("", 0, 350, $WIN_WIDTH, 2)
    GUICtrlSetBkColor($idFooterSep, 0xCCCCCC)

    ; ===================================================================
    ; Page 1 - Welcome
    ; ===================================================================
    Local $aPage1[2]
    Local $sInstallSummary = "Installation type: " & $g_sInstallType & @CRLF
    If $g_sInstallType = "Full" Then
        $sInstallSummary &= "Core library path: " & $g_sIncludePath & @CRLF
    EndIf
    $sInstallSummary &= "Lint tool path:    " & $g_sLintPath

    $aPage1[0] = GUICtrlCreateLabel( _
        "This wizard will remove the AutoIt TryCatch Solution from your computer." & @CRLF & @CRLF & _
        "It is recommended that you close SciTE before continuing." & @CRLF & @CRLF & _
        "Current installation:" & @CRLF & $sInstallSummary & @CRLF & @CRLF & _
        "Click Next to continue or Cancel to exit.", _
        15, 90, 465, 230)
    $aPage1[1] = GUICtrlCreateLabel("", 0, 0, 0, 0) ; placeholder to keep array size consistent

    ; ===================================================================
    ; Page 2 - Ready to Uninstall
    ; ===================================================================
    Local $aPage2[1]
    Local $sReadyText = "The following actions will be performed:" & @CRLF & @CRLF
    If $g_sInstallType = "Full" Then
        $sReadyText &= "  - Delete TryCatch.au3 from:   " & $g_sIncludePath & @CRLF
        $sReadyText &= "  - Delete Exception.au3 from:  " & $g_sIncludePath & @CRLF
        $sReadyText &= "  - Remove include path from AutoIt registry entry" & @CRLF
        $sReadyText &= "  - Remove Vendor folder if empty" & @CRLF
    EndIf
    $sReadyText &= "  - Delete TryCatchLint.au3 from:      " & $g_sLintPath & @CRLF
    $sReadyText &= "  - Delete TryCatchLintSciTE.au3 from: " & $g_sLintPath & @CRLF
    $sReadyText &= "  - Delete TryCatch.chm from:          " & $g_sLintPath & @CRLF
    $sReadyText &= "  - Remove TryCatch Lint from SciTEUser.properties" & @CRLF
    $sReadyText &= "  - Remove lint folder if empty" & @CRLF
    $sReadyText &= "  - Remove from Add/Remove Programs"
    $aPage2[0] = GUICtrlCreateLabel($sReadyText, 15, 90, 465, 230)

    ; ===================================================================
    ; Page 3 - Progress
    ; ===================================================================
    Local $aPage3[2]
    $aPage3[0] = GUICtrlCreateLabel("", 15, 90, 465, 20)
    $aPage3[1] = GUICtrlCreateProgress(15, 120, 465, 22)

    ; ===================================================================
    ; Page 4 - Finish
    ; ===================================================================
    Local $aPage4[1]
    $aPage4[0] = GUICtrlCreateLabel( _
        "AutoIt TryCatch Solution has been successfully uninstalled." & @CRLF & @CRLF & _
        "Please restart SciTE to remove the TryCatch Lint entry from the Tools menu.", _
        15, 90, 465, 180)

    ; --- Hide all pages initially ---
    __HidePage($aPage1)
    __HidePage($aPage2)
    __HidePage($aPage3)
    __HidePage($aPage4)

    GUISetState(@SW_SHOW, $hWin)

    Local $iPage = 1
    __ShowPage($iPage, $aPage1, $aPage2, $aPage3, $aPage4, $idHeaderSub, $idBtnNext, $idBtnBack, $idBtnCancel)

    ; ===================================================================
    ; Event loop
    ; ===================================================================
    While True
        Local $iMsg = GUIGetMsg()
        Switch $iMsg
            Case $GUI_EVENT_CLOSE, $idBtnCancel
                If $iPage < 3 Then
                    If MsgBox($MB_YESNO + $MB_ICONQUESTION, $UNINSTALLER_TITLE, _
                        "Are you sure you want to cancel the uninstallation?") = $IDYES Then
                        GUIDelete($hWin)
                        Exit
                    EndIf
                EndIf

            Case $idBtnNext
                Switch $iPage
                    Case 1
                        $iPage = 2

                    Case 2
                        $iPage = 3
                        GUICtrlSetState($idBtnNext,   $GUI_DISABLE)
                        GUICtrlSetState($idBtnBack,   $GUI_DISABLE)
                        GUICtrlSetState($idBtnCancel, $GUI_DISABLE)
                        __ShowPage($iPage, $aPage1, $aPage2, $aPage3, $aPage4, $idHeaderSub, $idBtnNext, $idBtnBack, $idBtnCancel)
                        __RunUninstall($aPage3[0], $aPage3[1])
                        $iPage = 4
                        GUICtrlSetData($idBtnNext, "Finish")
                        GUICtrlSetState($idBtnNext, $GUI_ENABLE)

                    Case 4
                        GUIDelete($hWin)
                        Exit
                EndSwitch
                __ShowPage($iPage, $aPage1, $aPage2, $aPage3, $aPage4, $idHeaderSub, $idBtnNext, $idBtnBack, $idBtnCancel)

            Case $idBtnBack
                Switch $iPage
                    Case 2
                        $iPage = 1
                EndSwitch
                __ShowPage($iPage, $aPage1, $aPage2, $aPage3, $aPage4, $idHeaderSub, $idBtnNext, $idBtnBack, $idBtnCancel)
        EndSwitch
    WEnd
EndFunc

; ===============================================================================================================================
; Page helpers
; ===============================================================================================================================

Func __ShowPage($iPage, ByRef $aPage1, ByRef $aPage2, ByRef $aPage3, ByRef $aPage4, _
    $idHeaderSub, $idBtnNext, $idBtnBack, $idBtnCancel)

    __HidePage($aPage1)
    __HidePage($aPage2)
    __HidePage($aPage3)
    __HidePage($aPage4)

    Switch $iPage
        Case 1
            GUICtrlSetData($idHeaderSub, "Welcome to the AutoIt TryCatch Solution Uninstaller")
            GUICtrlSetState($idBtnBack,   $GUI_DISABLE)
            GUICtrlSetState($idBtnNext,   $GUI_ENABLE)
            GUICtrlSetState($idBtnCancel, $GUI_ENABLE)
            GUICtrlSetData($idBtnNext, "Next >")
            __ShowPageControls($aPage1)

        Case 2
            GUICtrlSetData($idHeaderSub, "Ready to uninstall")
            GUICtrlSetState($idBtnBack,   $GUI_ENABLE)
            GUICtrlSetState($idBtnNext,   $GUI_ENABLE)
            GUICtrlSetState($idBtnCancel, $GUI_ENABLE)
            GUICtrlSetData($idBtnNext, "Uninstall")
            __ShowPageControls($aPage2)

        Case 3
            GUICtrlSetData($idHeaderSub, "Uninstalling, please wait...")
            GUICtrlSetState($idBtnBack,   $GUI_DISABLE)
            GUICtrlSetState($idBtnNext,   $GUI_DISABLE)
            GUICtrlSetState($idBtnCancel, $GUI_DISABLE)
            __ShowPageControls($aPage3)

        Case 4
            GUICtrlSetData($idHeaderSub, "Uninstallation complete")
            GUICtrlSetState($idBtnBack,   $GUI_DISABLE)
            GUICtrlSetState($idBtnNext,   $GUI_ENABLE)
            GUICtrlSetState($idBtnCancel, $GUI_DISABLE)
            GUICtrlSetData($idBtnNext, "Finish")
            __ShowPageControls($aPage4)
    EndSwitch
EndFunc

Func __HidePage(ByRef $aPage)
    For $i = 0 To UBound($aPage) - 1
        GUICtrlSetState($aPage[$i], $GUI_HIDE)
    Next
EndFunc

Func __ShowPageControls(ByRef $aPage)
    For $i = 0 To UBound($aPage) - 1
        GUICtrlSetState($aPage[$i], $GUI_SHOW)
    Next
EndFunc

; ===============================================================================================================================
; Uninstall logic
; ===============================================================================================================================

Func __RunUninstall($idStatusLabel, $idProgress)
    Local $iStep  = 0
    Local $iSteps = ($g_sInstallType = "Full") ? 8 : 5

    ; --- Remove core library files (full install only) ---
    If $g_sInstallType = "Full" Then
        __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing TryCatch.au3...")
        FileDelete($g_sIncludePath & "\TryCatch.au3")
        $iStep += 1

        __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing Exception.au3...")
        FileDelete($g_sIncludePath & "\Exception.au3")
        $iStep += 1

        __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Updating AutoIt include registry entry...")
        __RemoveIncludeRegistry()
        $iStep += 1

        __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing Vendor folder if empty...")
        __RemoveFolderIfEmpty($g_sIncludePath)
        $iStep += 1
    EndIf

    ; --- Remove lint files ---
    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing TryCatchLint.au3...")
    FileDelete($g_sLintPath & "\TryCatchLint.au3")
    $iStep += 1

    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing TryCatchLintSciTE.au3...")
    FileDelete($g_sLintPath & "\TryCatchLintSciTE.au3")
    $iStep += 1

    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing TryCatch.chm...")
    FileDelete($g_sLintPath & "\TryCatch.chm")
    $iStep += 1

    ; --- Remove SciTE registration ---
    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing TryCatch Lint from SciTEUser.properties...")
    __RemoveSciTERegistration()
    $iStep += 1

    ; --- Remove lint folder if empty ---
    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing lint folder if empty...")
    __RemoveFolderIfEmpty($g_sLintPath)
    $iStep += 1

    ; --- Remove registry entries ---
    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing registry entries...")
    RegDelete($REG_INSTALL_KEY)
    RegDelete($REG_UNINSTALL_KEY)

    GUICtrlSetData($idProgress, 100)
EndFunc

Func __ProgressStep($idLabel, $idProgress, $iStep, $iSteps, $sStatus)
    GUICtrlSetData($idLabel, $sStatus)
    GUICtrlSetData($idProgress, Int(($iStep / $iSteps) * 100))
EndFunc

; ===============================================================================================================================
; Helpers
; ===============================================================================================================================

; Removes our include path from the semicolon-delimited AutoIt Include registry value.
; Removes the registry value entirely only if it becomes empty after removing our path.
; Leaves any other vendor paths in the value untouched.
Func __RemoveIncludeRegistry()
    Local $sExisting = RegRead($REG_AUTOIT_INCLUDE, "Include")
    If @error Then Return

    ; Split on semicolon, remove our path, rejoin remaining entries
    Local $aPaths = StringSplit($sExisting, ";", 1)
    Local $sNew = ""
    For $i = 1 To $aPaths[0]
        Local $sPath = StringStripWS($aPaths[$i], 3)
        If $sPath <> "" And StringLower($sPath) <> StringLower($g_sIncludePath) Then
            $sNew &= ($sNew = "") ? $sPath : ";" & $sPath
        EndIf
    Next

    If $sNew = "" Then
        RegDelete($REG_AUTOIT_INCLUDE, "Include")
    Else
        RegWrite($REG_AUTOIT_INCLUDE, "Include", "REG_SZ", $sNew)
    EndIf
EndFunc

; Removes the TryCatch Lint block from SciTEUser.properties
Func __RemoveSciTERegistration()
    If Not FileExists($g_sSciTEUserProps) Then Return

    Local $sContent = FileRead($g_sSciTEUserProps)

    ; Find the registered slot number
    Local $aMatch = StringRegExp($sContent, 'command\.name\.(\d+)\.\$\(au3\)=TryCatch Lint', 1)
    If @error Then Return

    Local $iSlot = $aMatch[0]
    $sContent = StringRegExpReplace($sContent, '(?m)^#\s*' & $iSlot & '\s+TryCatch Lint\s*$\R?', "")
	$sContent = StringRegExpReplace($sContent, '(?m)^command\.[\w.]*' & $iSlot & '\.[^\r\n]*$\R?', "")

    Local $hFile = FileOpen($g_sSciTEUserProps, 2)
    FileWrite($hFile, $sContent)
    FileClose($hFile)
EndFunc

; Deletes $sFolder if it contains no files or subfolders
Func __RemoveFolderIfEmpty($sFolder)
    If Not FileExists($sFolder) Then Return
    Local $aFiles = _FileListToArray($sFolder)
    If @error Or $aFiles[0] = 0 Then DirRemove($sFolder)
EndFunc