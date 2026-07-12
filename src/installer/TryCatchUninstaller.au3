; #INDEX# =======================================================================================================================
; Title .........: TryCatchUninstaller.au3
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
; Note ..........: This script is compiled to TryCatchUninstaller.exe and embedded in the
;                  installer via FileInstall, then copied to the lint install folder so
;                  Add/Remove Programs can find it.
; ===============================================================================================================================

#RequireAdmin
#include <FontConstants.au3>
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

Global Const $WIN_WIDTH          = 540
Global Const $WIN_HEIGHT         = 380
Global Const $FONT_FACE          = "Segoe UI"
Global Const $FONT_SIZE          = 11
Global Const $BTN_W              = 130
Global Const $BTN_H              = 34
Global Const $BTN_GAP            = 10
Global Const $BTN_Y              = $WIN_HEIGHT - 48
Global Const $FOOTER_SEP_Y       = $WIN_HEIGHT - 58
Global Const $HEADER_H           = 70
Global Const $CONTENT_TOP        = $HEADER_H + 10
Global Const $CONTENT_W          = $WIN_WIDTH - 40

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
Global $g_sChmPath        = ""
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

    ; If running from the install folder, copy to temp and relaunch from there
    ; so we can delete the install folder at the end of uninstallation
    If StringInStr(StringLower(@ScriptFullPath), StringLower($g_sChmPath)) Then
        Local $sTempExe = @TempDir & "\TryCatchUninstaller.exe"
        FileCopy(@ScriptFullPath, $sTempExe, $FC_OVERWRITE)
        ShellExecute($sTempExe)
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

    $g_sChmPath = RegRead($REG_INSTALL_KEY, "ChmPath")
    If @error Then Return False

    If $g_sInstallType = "Full" Then
        $g_sIncludePath = RegRead($REG_INSTALL_KEY, "IncludePath")
        If @error Then Return False
    EndIf

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
    GUISetBkColor(0xF0F0F0)

    ; --- Header bar ---
    Local $idHeader = GUICtrlCreateLabel("", 0, 0, $WIN_WIDTH, $HEADER_H)
    GUICtrlSetBkColor($idHeader, 0xFFFFFF)
    Local $idHeaderTitle = GUICtrlCreateLabel("AutoIt TryCatch Solution", 15, 12, $WIN_WIDTH - 30, 26)
    GUICtrlSetFont($idHeaderTitle, 14, $FW_BOLD, $GUI_FONTNORMAL, $FONT_FACE)
    GUICtrlSetBkColor($idHeaderTitle, 0xFFFFFF)
    Local $idHeaderSub = GUICtrlCreateLabel("", 15, 38, $WIN_WIDTH - 30, 22)
    GUICtrlSetFont($idHeaderSub, $FONT_SIZE, $FW_NORMAL, $GUI_FONTNORMAL, $FONT_FACE)
    GUICtrlSetColor($idHeaderSub, 0x444444)
    GUICtrlSetBkColor($idHeaderSub, 0xFFFFFF)
    Local $idHeaderSep = GUICtrlCreateLabel("", 0, $HEADER_H, $WIN_WIDTH, 1)
    GUICtrlSetBkColor($idHeaderSep, 0xCCCCCC)

    ; --- Footer separator ---
    Local $idFooterSep = GUICtrlCreateLabel("", 0, $FOOTER_SEP_Y, $WIN_WIDTH, 1)
    GUICtrlSetBkColor($idFooterSep, 0xD0D0D0)

    ; --- Footer buttons (centered: Cancel | Back | Next) ---
    Local $iTotalBtnW  = (3 * $BTN_W) + (2 * $BTN_GAP)
    Local $iBtnStartX  = ($WIN_WIDTH - $iTotalBtnW) / 2
    Local $idBtnCancel = GUICtrlCreateButton("Cancel",  $iBtnStartX,                           $BTN_Y, $BTN_W, $BTN_H)
    Local $idBtnBack   = GUICtrlCreateButton("< Back",  $iBtnStartX + $BTN_W + $BTN_GAP,       $BTN_Y, $BTN_W, $BTN_H)
    Local $idBtnNext   = GUICtrlCreateButton("Next >",  $iBtnStartX + 2 * ($BTN_W + $BTN_GAP), $BTN_Y, $BTN_W, $BTN_H)
    GUICtrlSetFont($idBtnCancel, $FONT_SIZE, $FW_NORMAL, $GUI_FONTNORMAL, $FONT_FACE)
    GUICtrlSetFont($idBtnBack,   $FONT_SIZE, $FW_NORMAL, $GUI_FONTNORMAL, $FONT_FACE)
    GUICtrlSetFont($idBtnNext,   $FONT_SIZE, $FW_NORMAL, $GUI_FONTNORMAL, $FONT_FACE)

    ; ===================================================================
    ; Page 1 - Welcome / Confirm
    ; ===================================================================
    Local $aPage1[2]
    Local $sInstallSummary = "Installation type: " & $g_sInstallType & @CRLF
    If $g_sInstallType = "Full" Then
        $sInstallSummary &= "Core library path:  " & $g_sIncludePath & @CRLF
    EndIf
    $sInstallSummary &= "Lint tool path:     " & $g_sLintPath & @CRLF
    $sInstallSummary &= "Documentation path: " & $g_sChmPath
    $aPage1[0] = GUICtrlCreateLabel( _
        "This wizard will remove the AutoIt TryCatch Solution from your computer." & @CRLF & @CRLF & _
        "It is recommended that you close SciTE before continuing." & @CRLF & @CRLF & _
        "Current installation:" & @CRLF & $sInstallSummary & @CRLF & @CRLF & _
        "Click Next to continue or Cancel to exit.", _
        15, $CONTENT_TOP, $CONTENT_W, $FOOTER_SEP_Y - $CONTENT_TOP - 10)
    GUICtrlSetFont($aPage1[0], $FONT_SIZE, $FW_NORMAL, $GUI_FONTNORMAL, $FONT_FACE)
    GUICtrlSetBkColor($aPage1[0], $GUI_BKCOLOR_TRANSPARENT)
    $aPage1[1] = GUICtrlCreateLabel("", 0, 0, 0, 0) ; placeholder

    ; ===================================================================
    ; Page 2 - Ready to Uninstall
    ; ===================================================================
    Local $aPage2[2]
    $aPage2[0] = GUICtrlCreateLabel("The following actions will be performed:", 10, $CONTENT_TOP, $WIN_WIDTH - 20, 22)
    GUICtrlSetFont($aPage2[0], $FONT_SIZE, $FW_NORMAL, $GUI_FONTNORMAL, $FONT_FACE)
    GUICtrlSetBkColor($aPage2[0], $GUI_BKCOLOR_TRANSPARENT)
    Local $sReadyText = ""
    If $g_sInstallType = "Full" Then
        $sReadyText &= "  - Delete TryCatch.au3 from:          " & $g_sIncludePath & @CRLF
        $sReadyText &= "  - Delete Exception.au3 from:         " & $g_sIncludePath & @CRLF
        $sReadyText &= "  - Remove include path from AutoIt registry entry" & @CRLF
        $sReadyText &= "  - Remove Vendor folder if empty" & @CRLF
    EndIf
    $sReadyText &= "  - Delete TryCatchLint.au3 from:       " & $g_sLintPath & @CRLF
    $sReadyText &= "  - Delete TryCatchLintSciTE.au3 from:  " & $g_sLintPath & @CRLF
    $sReadyText &= "  - Delete TryCatch.chm from:           " & $g_sChmPath & @CRLF
    $sReadyText &= "  - Remove TryCatch Lint from SciTEUser.properties" & @CRLF
    $sReadyText &= "  - Remove lint folder if empty" & @CRLF
    $sReadyText &= "  - Remove documentation folder if empty" & @CRLF
    $sReadyText &= "  - Remove from Add/Remove Programs"
    $aPage2[1] = GUICtrlCreateLabel($sReadyText, 10, $CONTENT_TOP + 28, $WIN_WIDTH - 20, $FOOTER_SEP_Y - $CONTENT_TOP - 38)
    GUICtrlSetFont($aPage2[1], 10, $FW_NORMAL, $GUI_FONTNORMAL, $FONT_FACE)
    GUICtrlSetBkColor($aPage2[1], $GUI_BKCOLOR_TRANSPARENT)

    ; ===================================================================
    ; Page 3 - Progress
    ; ===================================================================
    Local $aPage3[2]
    $aPage3[0] = GUICtrlCreateLabel("", 15, $CONTENT_TOP, $CONTENT_W, 24)
    GUICtrlSetFont($aPage3[0], $FONT_SIZE, $FW_NORMAL, $GUI_FONTNORMAL, $FONT_FACE)
    GUICtrlSetBkColor($aPage3[0], $GUI_BKCOLOR_TRANSPARENT)
    $aPage3[1] = GUICtrlCreateProgress(15, $CONTENT_TOP + 32, $CONTENT_W, 24)

    ; ===================================================================
    ; Page 4 - Finish
    ; ===================================================================
    Local $aPage4[1]
    $aPage4[0] = GUICtrlCreateLabel( _
        "AutoIt TryCatch Solution has been successfully uninstalled." & @CRLF & @CRLF & _
        "Please restart SciTE to remove the TryCatch Lint entry from the Tools menu.", _
        15, $CONTENT_TOP, $CONTENT_W, $FOOTER_SEP_Y - $CONTENT_TOP - 10)
    GUICtrlSetFont($aPage4[0], $FONT_SIZE, $FW_NORMAL, $GUI_FONTNORMAL, $FONT_FACE)
    GUICtrlSetBkColor($aPage4[0], $GUI_BKCOLOR_TRANSPARENT)

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
    Local $iSteps = ($g_sInstallType = "Full") ? 9 : 6

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

    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing TryCatchLint.au3...")
    FileDelete($g_sLintPath & "\TryCatchLint.au3")
    $iStep += 1

    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing TryCatchLintSciTE.au3...")
    FileDelete($g_sLintPath & "\TryCatchLintSciTE.au3")
    $iStep += 1

    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing TryCatch Lint from SciTEUser.properties...")
    __RemoveSciTERegistration()
    $iStep += 1

    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing lint folder if empty...")
    __RemoveFolderIfEmpty($g_sLintPath)
    $iStep += 1

    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Removing documentation folder...")
    FileDelete($g_sChmPath & "\TryCatch.chm")
    FileDelete($g_sChmPath & "\TryCatchUninstaller.exe")
    __RemoveFolderIfEmpty($g_sChmPath)
    $iStep += 1

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

Func __RemoveIncludeRegistry()
    Local $sExisting = RegRead($REG_AUTOIT_INCLUDE, "Include")
    If @error Then Return

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

Func __RemoveSciTERegistration()
    If Not FileExists($g_sSciTEUserProps) Then Return

    Local $sContent = FileRead($g_sSciTEUserProps)

    Local $aMatch = StringRegExp($sContent, 'command\.name\.(\d+)\.\$\(au3\)=TryCatch Lint', 1)
    If @error Then Return

    Local $iSlot = $aMatch[0]
    $sContent = StringRegExpReplace($sContent, '(?m)^#\s*' & $iSlot & '\s+TryCatch Lint\s*$\R?', "")
    $sContent = StringRegExpReplace($sContent, '(?m)^command\.[\w.]*' & $iSlot & '\.[^\r\n]*$\R?', "")

    Local $hFile = FileOpen($g_sSciTEUserProps, 2)
    FileWrite($hFile, $sContent)
    FileClose($hFile)
EndFunc

Func __RemoveFolderIfEmpty($sFolder)
    If Not FileExists($sFolder) Then Return
    Local $aFiles = _FileListToArray($sFolder)
    If @error Or $aFiles[0] = 0 Then DirRemove($sFolder)
EndFunc
