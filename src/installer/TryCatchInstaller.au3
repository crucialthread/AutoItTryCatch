; #INDEX# =======================================================================================================================
; Title .........: AutoIt TryCatch - Installer
; Version .......: 0.0.1
; AutoIt Version : 3.3.18.0
; Author ........: Crucial Thread
; Description ...: Installation wizard for the AutoIt TryCatch solution.
;                  Supports two installation modes:
;                    - Full: installs TryCatch.au3, Exception.au3 (core libraries) and the
;                      TryCatchLint tool, registers the core libraries with AutoIt via the
;                      registry, and registers the lint tool in SciTEUser.properties.
;                    - Lint Only: installs only the TryCatchLint tool and registers it in
;                      SciTEUser.properties. Recommended for developers using the core
;                      libraries as a git submodule.
;                  Registers itself in Add/Remove Programs for uninstall support.
;                  Detects existing installations and offers to upgrade.
;                  Detects AutoIt and SciTE installation paths from the registry.
; Note ..........: Requires administrator rights to write to Program Files.
; Note ..........: Source files are embedded into the compiled .exe via FileInstall at
;                  compile time - paths are relative to this .au3 source file location.
;                  The compiled .exe is fully self-contained and can be run from any location.
; ===============================================================================================================================

#RequireAdmin
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <ProgressConstants.au3>
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>

; ===============================================================================================================================
; Constants
; ===============================================================================================================================

Global Const $INSTALLER_TITLE   = "AutoIt TryCatch Solution Setup"
Global Const $INSTALLER_VERSION = "0.0.1"
Global Const $WIN_WIDTH         = 500
Global Const $WIN_HEIGHT        = 400
Global Const $INSTALL_TYPE_FULL = 1
Global Const $INSTALL_TYPE_LINT = 2

Global Const $REG_UNINSTALL_KEY  = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AutoItTryCatch"
Global Const $REG_INSTALL_KEY    = "HKEY_LOCAL_MACHINE\SOFTWARE\AutoIt TryCatch"
Global Const $REG_AUTOIT_KEY_WOW = "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\AutoIt v3\AutoIt"
Global Const $REG_AUTOIT_KEY     = "HKEY_LOCAL_MACHINE\SOFTWARE\AutoIt v3\AutoIt"
Global Const $REG_SCITE_EXE_KEY  = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\SciTE.exe"
Global Const $REG_SCITE_HOME_KEY = "HKEY_CURRENT_USER\Environment"
Global Const $REG_AUTOIT_INCLUDE = "HKEY_CURRENT_USER\Software\AutoIt v3\AutoIt"

; ===============================================================================================================================
; Global state
; ===============================================================================================================================

Global $g_iInstallType    = $INSTALL_TYPE_FULL
Global $g_sAutoItDir      = ""
Global $g_sSciTEUserHome  = ""
Global $g_sSciTEUserProps = ""
Global $g_bSciTEFound     = False
Global $g_sIncludePath    = ""
Global $g_sLintPath       = ""
Global $g_bIsUpgrade      = False

; ===============================================================================================================================
; Entry point
; ===============================================================================================================================

_Main()

Func _Main()
    __DetectPaths()
    __CheckExistingInstall()
    __RunWizard()
EndFunc

; ===============================================================================================================================
; Detection
; ===============================================================================================================================

Func __DetectPaths()
    ; AutoIt install dir
    $g_sAutoItDir = RegRead($REG_AUTOIT_KEY_WOW, "InstallDir")
    If @error Then $g_sAutoItDir = RegRead($REG_AUTOIT_KEY, "InstallDir")
    If @error Then $g_sAutoItDir = "C:\Program Files (x86)\AutoIt3"

    ; SciTE
    Local $sSciTEExe = RegRead($REG_SCITE_EXE_KEY, "")
    $g_bSciTEFound = Not @error And FileExists($sSciTEExe)

    ; SciTE user home for SciTEUser.properties
    $g_sSciTEUserHome = RegRead($REG_SCITE_HOME_KEY, "SCITE_USERHOME")
    If @error Or Not FileExists($g_sSciTEUserHome) Then
        $g_sSciTEUserHome = @LocalAppDataDir & "\AutoIt v3\SciTE"
    EndIf
    $g_sSciTEUserProps = $g_sSciTEUserHome & "\SciTEUser.properties"

    ; Default install paths
    $g_sIncludePath = $g_sAutoItDir & "\Include\Vendor"
    $g_sLintPath    = $g_sAutoItDir & "\SciTE\TryCatchLint"
EndFunc

Func __CheckExistingInstall()
    Local $sExistingVersion = RegRead($REG_INSTALL_KEY, "Version")
    $g_bIsUpgrade = Not @error And $sExistingVersion <> ""

    If $g_bIsUpgrade Then
        Local $sExistingInclude = RegRead($REG_INSTALL_KEY, "IncludePath")
        Local $sExistingLint    = RegRead($REG_INSTALL_KEY, "LintPath")
        If Not @error And FileExists($sExistingInclude) Then $g_sIncludePath = $sExistingInclude
        If Not @error And FileExists($sExistingLint)    Then $g_sLintPath    = $sExistingLint
    EndIf
EndFunc

; ===============================================================================================================================
; Wizard
; ===============================================================================================================================

Func __RunWizard()
    Local $hWin = GUICreate($INSTALLER_TITLE, $WIN_WIDTH, $WIN_HEIGHT, -1, -1, _
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
    $aPage1[0] = GUICtrlCreateLabel( _
        "Welcome to the AutoIt TryCatch Solution Setup Wizard." & @CRLF & @CRLF & _
        "This wizard will guide you through the installation of the" & @CRLF & _
        "AutoIt TryCatch solution on your computer." & @CRLF & @CRLF & _
        "It is recommended that you close SciTE before continuing." & @CRLF & @CRLF & _
        "Click Next to continue or Cancel to exit.", _
        15, 90, 465, 220)
    $aPage1[1] = GUICtrlCreateLabel("Version " & $INSTALLER_VERSION, 15, 320, 200, 20)
    GUICtrlSetColor($aPage1[1], 0x888888)

    ; ===================================================================
    ; Page 2 - Installation Type
    ; ===================================================================
    Local $aPage2[4]
    $aPage2[0] = GUICtrlCreateRadio("Full Installation", 15, 100, 460, 20)
    GUICtrlSetState($aPage2[0], $GUI_CHECKED)
    $aPage2[1] = GUICtrlCreateLabel( _
        "    Installs TryCatch.au3, Exception.au3, and the TryCatchLint tool." & @CRLF & _
        "    Recommended for new users.", _
        15, 122, 460, 35)
    GUICtrlSetColor($aPage2[1], 0x444444)
    $aPage2[2] = GUICtrlCreateRadio("Lint Tool Only", 15, 175, 460, 20)
    $aPage2[3] = GUICtrlCreateLabel( _
        "    Installs only the TryCatchLint tool for SciTE integration." & @CRLF & _
        "    Recommended for developers already using TryCatch as a git submodule.", _
        15, 197, 460, 35)
    GUICtrlSetColor($aPage2[3], 0x444444)

    ; ===================================================================
    ; Page 3 - Core Library Path (full install only)
    ; ===================================================================
    Local $aPage3[4]
    $aPage3[0] = GUICtrlCreateLabel( _
        "TryCatch.au3 and Exception.au3 will be copied to the folder below." & @CRLF & @CRLF & _
        "A registry entry will be created so AutoIt finds them automatically" & @CRLF & _
        "using #include <TryCatch.au3> from any project.", _
        15, 90, 465, 80)
    $aPage3[1] = GUICtrlCreateLabel("Core library install folder:", 15, 180, 200, 20)
    $aPage3[2] = GUICtrlCreateInput($g_sIncludePath, 15, 200, 380, 22)
    $aPage3[3] = GUICtrlCreateButton("Browse...", 400, 199, 80, 24)

    ; ===================================================================
    ; Page 4 - Lint Path (both modes)
    ; ===================================================================
    Local $aPage4[4]
    $aPage4[0] = GUICtrlCreateLabel( _
        "TryCatchLint.au3 and TryCatchLintSciTE.au3 will be copied to the" & @CRLF & _
        "folder below and registered as a SciTE Tools menu command.", _
        15, 90, 465, 60)
    Local $idSciTEWarning = GUICtrlCreateLabel( _
        "Warning: SciTE was not detected on this machine. The lint tool will" & @CRLF & _
        "be installed but SciTE registration will be skipped.", _
        15, 155, 465, 35)
    GUICtrlSetColor($idSciTEWarning, 0xCC0000)
    If $g_bSciTEFound Then GUICtrlSetState($idSciTEWarning, $GUI_HIDE)
    $aPage4[1] = GUICtrlCreateLabel("Lint tool install folder:", 15, 200, 200, 20)
    $aPage4[2] = GUICtrlCreateInput($g_sLintPath, 15, 220, 380, 22)
    $aPage4[3] = GUICtrlCreateButton("Browse...", 400, 219, 80, 24)

    ; ===================================================================
    ; Page 5 - Ready to Install
    ; ===================================================================
    Local $aPage5[1]
    $aPage5[0] = GUICtrlCreateLabel("", 15, 90, 465, 230)

    ; ===================================================================
    ; Page 6 - Progress
    ; ===================================================================
    Local $aPage6[2]
    $aPage6[0] = GUICtrlCreateLabel("", 15, 90, 465, 20)
    $aPage6[1] = GUICtrlCreateProgress(15, 120, 465, 22)

    ; ===================================================================
    ; Page 7 - Finish
    ; ===================================================================
    Local $aPage7[2]
    $aPage7[0] = GUICtrlCreateLabel("", 15, 90, 465, 180)
    $aPage7[1] = GUICtrlCreateCheckbox("Open documentation", 15, 290, 200, 20)

    ; --- Hide all pages initially ---
    __HidePage($aPage1)
    __HidePage($aPage2)
    __HidePage($aPage3)
    __HidePage($aPage4)
    __HidePage($aPage5)
    __HidePage($aPage6)
    __HidePage($aPage7)

    GUISetState(@SW_SHOW, $hWin)

    ; --- Start on page 1 ---
    Local $iPage = 1
    __ShowPage($iPage, $aPage1, $aPage2, $aPage3, $aPage4, $aPage5, $aPage6, $aPage7, _
        $idHeaderSub, $idBtnNext, $idBtnBack, $idBtnCancel, $g_bIsUpgrade)

    ; ===================================================================
    ; Event loop
    ; ===================================================================
    While True
        Local $iMsg = GUIGetMsg()
        Switch $iMsg
            Case $GUI_EVENT_CLOSE, $idBtnCancel
                If $iPage < 6 Then
                    If MsgBox($MB_YESNO + $MB_ICONQUESTION, $INSTALLER_TITLE, _
                        "Are you sure you want to cancel the installation?") = $IDYES Then
                        GUIDelete($hWin)
                        Exit
                    EndIf
                EndIf

            Case $idBtnNext
                Switch $iPage
                    Case 1
                        $iPage = 2

                    Case 2
                        $g_iInstallType = (GUICtrlRead($aPage2[0]) = $GUI_CHECKED) ? $INSTALL_TYPE_FULL : $INSTALL_TYPE_LINT
                        $iPage = ($g_iInstallType = $INSTALL_TYPE_FULL) ? 3 : 4

                    Case 3
                        $g_sIncludePath = GUICtrlRead($aPage3[2])
                        $iPage = 4

                    Case 4
                        $g_sLintPath = GUICtrlRead($aPage4[2])
                        __UpdateReadyPage($aPage5[0])
                        $iPage = 5

                    Case 5
                        $iPage = 6
                        GUICtrlSetState($idBtnNext,   $GUI_DISABLE)
                        GUICtrlSetState($idBtnBack,   $GUI_DISABLE)
                        GUICtrlSetState($idBtnCancel, $GUI_DISABLE)
                        __ShowPage($iPage, $aPage1, $aPage2, $aPage3, $aPage4, $aPage5, $aPage6, $aPage7, _
                            $idHeaderSub, $idBtnNext, $idBtnBack, $idBtnCancel, $g_bIsUpgrade)
                        __RunInstall($aPage6[0], $aPage6[1])
                        __UpdateFinishPage($aPage7[0])
                        $iPage = 7
                        GUICtrlSetData($idBtnNext, "Finish")
                        GUICtrlSetState($idBtnNext, $GUI_ENABLE)

                    Case 7
                        If GUICtrlRead($aPage7[1]) = $GUI_CHECKED Then
                            ShellExecute($g_sLintPath & "\TryCatch.chm")
                        EndIf
                        GUIDelete($hWin)
                        Exit
                EndSwitch
                __ShowPage($iPage, $aPage1, $aPage2, $aPage3, $aPage4, $aPage5, $aPage6, $aPage7, _
                    $idHeaderSub, $idBtnNext, $idBtnBack, $idBtnCancel, $g_bIsUpgrade)

            Case $idBtnBack
                Switch $iPage
                    Case 2
                        $iPage = 1
                    Case 3
                        $iPage = 2
                    Case 4
                        $iPage = ($g_iInstallType = $INSTALL_TYPE_FULL) ? 3 : 2
                    Case 5
                        $iPage = 4
                EndSwitch
                __ShowPage($iPage, $aPage1, $aPage2, $aPage3, $aPage4, $aPage5, $aPage6, $aPage7, _
                    $idHeaderSub, $idBtnNext, $idBtnBack, $idBtnCancel, $g_bIsUpgrade)

            Case $aPage3[3]
                Local $sFolder3 = FileSelectFolder("Select core library install folder", $g_sIncludePath)
                If Not @error Then GUICtrlSetData($aPage3[2], $sFolder3)

            Case $aPage4[3]
                Local $sFolder4 = FileSelectFolder("Select lint tool install folder", $g_sLintPath)
                If Not @error Then GUICtrlSetData($aPage4[2], $sFolder4)
        EndSwitch
    WEnd
EndFunc

; ===============================================================================================================================
; Page helpers
; ===============================================================================================================================

Func __ShowPage($iPage, ByRef $aPage1, ByRef $aPage2, ByRef $aPage3, ByRef $aPage4, _
    ByRef $aPage5, ByRef $aPage6, ByRef $aPage7, $idHeaderSub, $idBtnNext, $idBtnBack, _
    $idBtnCancel, $bIsUpgrade)

    __HidePage($aPage1)
    __HidePage($aPage2)
    __HidePage($aPage3)
    __HidePage($aPage4)
    __HidePage($aPage5)
    __HidePage($aPage6)
    __HidePage($aPage7)

    Local $sWelcome = $bIsUpgrade ? "Upgrading AutoIt TryCatch Solution" : "Welcome to AutoIt TryCatch Solution Setup"

    Switch $iPage
        Case 1
            GUICtrlSetData($idHeaderSub, $sWelcome)
            GUICtrlSetState($idBtnBack,   $GUI_DISABLE)
            GUICtrlSetState($idBtnNext,   $GUI_ENABLE)
            GUICtrlSetState($idBtnCancel, $GUI_ENABLE)
            GUICtrlSetData($idBtnNext, "Next >")
            __ShowPageControls($aPage1)

        Case 2
            GUICtrlSetData($idHeaderSub, "Select installation type")
            GUICtrlSetState($idBtnBack,   $GUI_ENABLE)
            GUICtrlSetState($idBtnNext,   $GUI_ENABLE)
            GUICtrlSetState($idBtnCancel, $GUI_ENABLE)
            GUICtrlSetData($idBtnNext, "Next >")
            __ShowPageControls($aPage2)

        Case 3
            GUICtrlSetData($idHeaderSub, "Core library installation path")
            GUICtrlSetState($idBtnBack,   $GUI_ENABLE)
            GUICtrlSetState($idBtnNext,   $GUI_ENABLE)
            GUICtrlSetState($idBtnCancel, $GUI_ENABLE)
            GUICtrlSetData($idBtnNext, "Next >")
            __ShowPageControls($aPage3)

        Case 4
            GUICtrlSetData($idHeaderSub, "Lint tool installation path")
            GUICtrlSetState($idBtnBack,   $GUI_ENABLE)
            GUICtrlSetState($idBtnNext,   $GUI_ENABLE)
            GUICtrlSetState($idBtnCancel, $GUI_ENABLE)
            GUICtrlSetData($idBtnNext, "Next >")
            __ShowPageControls($aPage4)

        Case 5
            GUICtrlSetData($idHeaderSub, "Ready to install")
            GUICtrlSetState($idBtnBack,   $GUI_ENABLE)
            GUICtrlSetState($idBtnNext,   $GUI_ENABLE)
            GUICtrlSetState($idBtnCancel, $GUI_ENABLE)
            GUICtrlSetData($idBtnNext, "Install")
            __ShowPageControls($aPage5)

        Case 6
            GUICtrlSetData($idHeaderSub, "Installing, please wait...")
            GUICtrlSetState($idBtnBack,   $GUI_DISABLE)
            GUICtrlSetState($idBtnNext,   $GUI_DISABLE)
            GUICtrlSetState($idBtnCancel, $GUI_DISABLE)
            __ShowPageControls($aPage6)

        Case 7
            GUICtrlSetData($idHeaderSub, "Installation complete")
            GUICtrlSetState($idBtnBack,   $GUI_DISABLE)
            GUICtrlSetState($idBtnNext,   $GUI_ENABLE)
            GUICtrlSetState($idBtnCancel, $GUI_DISABLE)
            GUICtrlSetData($idBtnNext, "Finish")
            __ShowPageControls($aPage7)
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

Func __UpdateReadyPage($idLabel)
    Local $sText = "The following actions will be performed:" & @CRLF & @CRLF
    If $g_iInstallType = $INSTALL_TYPE_FULL Then
        $sText &= "  - Copy TryCatch.au3 to:   " & $g_sIncludePath & @CRLF
        $sText &= "  - Copy Exception.au3 to:  " & $g_sIncludePath & @CRLF
        $sText &= "  - Create AutoIt registry entry for include path" & @CRLF
    EndIf
    $sText &= "  - Copy TryCatchLint.au3 to:       " & $g_sLintPath & @CRLF
    $sText &= "  - Copy TryCatchLintSciTE.au3 to:  " & $g_sLintPath & @CRLF
    $sText &= "  - Copy TryCatch.chm to:                " & $g_sLintPath & @CRLF
    $sText &= "  - Copy TryCatchUninstaller.exe to:     " & $g_sLintPath & @CRLF
    If $g_bSciTEFound Then
        $sText &= "  - Register TryCatch Lint in SciTEUser.properties" & @CRLF
    Else
        $sText &= "  - SciTE not detected - registration will be skipped" & @CRLF
    EndIf
    GUICtrlSetData($idLabel, $sText)
EndFunc

Func __UpdateFinishPage($idLabel)
    Local $sText = "AutoIt TryCatch Solution has been successfully installed." & @CRLF & @CRLF
    If $g_bSciTEFound Then
        $sText &= "Please restart SciTE for the TryCatchLint tool to appear" & @CRLF & _
                  "in the Tools menu (Ctrl+Alt+L)." & @CRLF & @CRLF
    EndIf
    $sText &= "Thank you for installing AutoIt TryCatch Solution."
    GUICtrlSetData($idLabel, $sText)
EndFunc

; ===============================================================================================================================
; Installation logic
; ===============================================================================================================================

Func __RunInstall($idStatusLabel, $idProgress)
    Local $iStep  = 0
    Local $iSteps = ($g_iInstallType = $INSTALL_TYPE_FULL) ? 9 : 6

    ; --- Create directories ---
    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Creating directories...")
    If $g_iInstallType = $INSTALL_TYPE_FULL Then DirCreate($g_sIncludePath)
    DirCreate($g_sLintPath)
    $iStep += 1

    ; --- Copy core library files (full install only) ---
    If $g_iInstallType = $INSTALL_TYPE_FULL Then
        __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Copying TryCatch.au3...")
        FileInstall("..\core\TryCatch.au3", $g_sIncludePath & "\TryCatch.au3", $FC_OVERWRITE)
        $iStep += 1

        __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Copying Exception.au3...")
        FileInstall("..\core\Exception.au3", $g_sIncludePath & "\Exception.au3", $FC_OVERWRITE)
        $iStep += 1

        __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Writing AutoIt include registry entry...")
        __WriteIncludeRegistry()
        $iStep += 1
    EndIf

    ; --- Copy lint files ---
    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Copying TryCatchLint.au3...")
    FileInstall("..\lint\TryCatchLint.au3", $g_sLintPath & "\TryCatchLint.au3", $FC_OVERWRITE)
    $iStep += 1

    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Copying TryCatchLintSciTE.au3...")
    FileInstall("..\lint\TryCatchLintSciTE.au3", $g_sLintPath & "\TryCatchLintSciTE.au3", $FC_OVERWRITE)
    $iStep += 1

    ; --- Copy CHM documentation ---
    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Copying TryCatch.chm...")
    FileInstall("..\..\chm\TryCatch.chm", $g_sLintPath & "\TryCatch.chm", $FC_OVERWRITE)
    $iStep += 1

    ; --- Copy uninstaller ---
    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Copying TryCatchUninstaller.exe...")
    FileInstall("TryCatchUninstaller.exe", $g_sLintPath & "\TryCatchUninstaller.exe", $FC_OVERWRITE)
    $iStep += 1

    ; --- SciTE registration ---
    If $g_bSciTEFound Then
        __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Registering TryCatch Lint in SciTEUser.properties...")
        __WriteSciTERegistration()
    EndIf
    $iStep += 1

    ; --- Write install record and Add/Remove Programs entry ---
    __ProgressStep($idStatusLabel, $idProgress, $iStep, $iSteps, "Finalizing installation...")
    __WriteInstallRegistry()
    __WriteUninstallRegistry()

    GUICtrlSetData($idProgress, 100)
EndFunc

Func __ProgressStep($idLabel, $idProgress, $iStep, $iSteps, $sStatus)
    GUICtrlSetData($idLabel, $sStatus)
    GUICtrlSetData($idProgress, Int(($iStep / $iSteps) * 100))
EndFunc

; ===============================================================================================================================
; Registry / properties writers
; ===============================================================================================================================

Func __WriteIncludeRegistry()
    Local $sExisting = RegRead($REG_AUTOIT_INCLUDE, "Include")
    If @error Then $sExisting = ""
    If Not StringInStr($sExisting, $g_sIncludePath) Then
        Local $sNew = ($sExisting = "") ? $g_sIncludePath : $sExisting & ";" & $g_sIncludePath
        RegWrite($REG_AUTOIT_INCLUDE, "Include", "REG_SZ", $sNew)
    EndIf
EndFunc

Func __WriteSciTERegistration()
    Local $sLintScriptPath   = $g_sLintPath & "\TryCatchLint.au3"
    Local $sUserPropsContent = FileExists($g_sSciTEUserProps) ? FileRead($g_sSciTEUserProps) : ""

    ; Find next free slot
    Local $sAu3PropsPath = $g_sAutoItDir & "\SciTE\au3.properties"
    Local $sAu3Props     = FileExists($sAu3PropsPath) ? FileRead($sAu3PropsPath) : ""
    Local $iSlot         = __NextFreeSlot($sAu3Props & @CRLF & $sUserPropsContent)

    ; Remove existing registration if upgrading
    Local $aMatch = StringRegExp($sUserPropsContent, 'command\.name\.(\d+)\.\$\(au3\)=TryCatch Lint', 1)
    If Not @error Then
        $iSlot = $aMatch[0]
        $sUserPropsContent = StringRegExpReplace($sUserPropsContent, '(?m)^#\s*' & $iSlot & '\s+TryCatch Lint\s*$\R?', "")
        $sUserPropsContent = StringRegExpReplace($sUserPropsContent, '(?m)^command\.\w*\.?' & $iSlot & '\.[^\r\n]*$\R?', "")
        Local $hFile = FileOpen($g_sSciTEUserProps, 2)
        FileWrite($hFile, $sUserPropsContent)
        FileClose($hFile)
    EndIf

    ; Write new registration block
    Local $sBlock = @CRLF & "# " & $iSlot & " TryCatch Lint" & @CRLF & _
        'command.' & $iSlot & '.$(au3)="$(SciteDefaultHome)\..\AutoIt3.exe" "$(SciteDefaultHome)\AutoIt3Wrapper\AutoIt3Wrapper.au3" /run /prod /ErrorStdOut /in "' & $sLintScriptPath & '" /UserParams "$(FilePath)" "$(SciteDefaultHome)\AutoIt3Wrapper\AutoIt3Wrapper.au3"' & @CRLF & _
        "command.name." & $iSlot & '.$(au3)=TryCatch Lint' & @CRLF & _
        "command.shortcut." & $iSlot & ".*.au3=Ctrl+Alt+L" & @CRLF & _
        "command.subsystem." & $iSlot & '.$(au3)=1' & @CRLF & _
        "command.save.before." & $iSlot & '.$(au3)=2' & @CRLF

    Local $hFile = FileOpen($g_sSciTEUserProps, 1)
    FileWrite($hFile, $sBlock)
    FileClose($hFile)
EndFunc

Func __NextFreeSlot($sCombinedProps)
    Local $aMatches = StringRegExp($sCombinedProps, 'command\.(?:name\.|shortcut\.|subsystem\.|save\.before\.)?(\d+)\.', 3)
    Local $iMax = 39
    If Not @error Then
        For $sNum In $aMatches
            If Number($sNum) > $iMax Then $iMax = Number($sNum)
        Next
    EndIf
    Return $iMax + 1
EndFunc

Func __WriteInstallRegistry()
    RegWrite($REG_INSTALL_KEY, "Version",     "REG_SZ", $INSTALLER_VERSION)
    RegWrite($REG_INSTALL_KEY, "InstallType", "REG_SZ", ($g_iInstallType = $INSTALL_TYPE_FULL) ? "Full" : "LintOnly")
    RegWrite($REG_INSTALL_KEY, "LintPath",    "REG_SZ", $g_sLintPath)
    If $g_iInstallType = $INSTALL_TYPE_FULL Then
        RegWrite($REG_INSTALL_KEY, "IncludePath", "REG_SZ", $g_sIncludePath)
    EndIf
EndFunc

Func __WriteUninstallRegistry()
    Local $sUninstallerPath = $g_sLintPath & "\TryCatchUninstaller.exe"
    RegWrite($REG_UNINSTALL_KEY, "DisplayName",     "REG_SZ",   "AutoIt TryCatch Solution")
    RegWrite($REG_UNINSTALL_KEY, "DisplayVersion",  "REG_SZ",   $INSTALLER_VERSION)
    RegWrite($REG_UNINSTALL_KEY, "Publisher",       "REG_SZ",   "crucialthread")
    RegWrite($REG_UNINSTALL_KEY, "UninstallString", "REG_SZ",   '"' & $sUninstallerPath & '"')
    RegWrite($REG_UNINSTALL_KEY, "NoModify",        "REG_DWORD", 1)
EndFunc