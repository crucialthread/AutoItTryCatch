; #INDEX# =======================================================================================================================
; Title .........: AutoIt TryCatch - TryCatch Lint tool SciTE self-register
; Version .......: 0.0.1
; AutoIt Version : 3.3.18.0
; Author ........: Crucial Thread
; Description ...: Self-registration logic for TryCatchLint.au3 as a SciTE Tools menu command.
;                  Intended to be #include'd by TryCatchLint.au3 (or any future installer for the broader
;                  TryCatch solution) - not meant to be run directly on its own.
;                  Detects whether "TryCatch Lint" is already registered in SciTEUser.properties:
;                    - If yes, offers (via MsgBox) to overwrite the existing entry at the same slot,
;                      using the calling script's current path - useful after the tool is moved/updated.
;                    - If no, scans au3.properties + SciTEUser.properties for the highest used command
;                      slot (minimum 40, per the documented SciTE convention) and offers to register at
;                      the next free slot.
; Usage .........: #include "TryCatchLintSciTE.au3"
;                  If __TCL_IsRunningFromSciTE() Then __TCL_SelfRegister()
; Note ..........: Every function uses the same TCL_ prefix as TryCatchLint.au3 for consistent namespacing.
; Note ..........: $__g_h_TCL_MsgBox holds the function reference used for all MsgBox calls. It defaults
;                  to the real MsgBox built-in, but can be replaced before calling __TCL_SelfRegister()
;                  to intercept dialog calls in tests without showing a real GUI.
; ===============================================================================================================================

#include-once

; ===============================================================================================================================
; Constants
; ===============================================================================================================================

; Function reference for all MsgBox calls - replace with a stub in tests to intercept dialogs
Global $__g_h_TCL_MsgBox = MsgBox

; ===============================================================================================================================
; Public API
; ===============================================================================================================================

; Returns True if a SciTE window is currently open - used as a simple signal that the calling
; script is likely being run from within SciTE, not standalone via double-click or a
; plain command line. Self-registration should only ever be offered in the SciTE context.
Func __TCL_IsRunningFromSciTE()
    Return WinExists("[CLASS:SciTEWindow]")
EndFunc

; Detects whether TryCatch Lint is already registered in SciTEUser.properties.
; If yes, offers to overwrite the existing entry (so a moved/updated path can be re-registered
; at the same slot). If no, finds the next free command slot and asks to confirm before
; appending a new registration block. All confirmation/feedback is via $__g_h_TCL_MsgBox.
Func __TCL_SelfRegister()
    Local $sUserPropsPath = @LocalAppDataDir & "\AutoIt v3\SciTE\SciTEUser.properties"
    Local $sUserProps     = FileExists($sUserPropsPath) ? FileRead($sUserPropsPath) : ""

    Local $sExistingSlot = __TCL_FindExistingRegistration($sUserProps)

    If $sExistingSlot <> "" Then
        Local $sMsg = "TryCatch Lint is already registered (slot " & $sExistingSlot & ")." & @CRLF & @CRLF & _
                      "Current path: " & @ScriptFullPath & @CRLF & @CRLF & _
                      "Overwrite the existing registration with this path?"
        Local $iAnswer = $__g_h_TCL_MsgBox(36, "TryCatch Lint - Already Registered", $sMsg)

        If $iAnswer <> 6 Then
            $__g_h_TCL_MsgBox(64, "TryCatch Lint", "No changes made.")
            Return
        EndIf

        __TCL_RemoveRegistration($sUserPropsPath, $sExistingSlot)
        __TCL_WriteRegistration($sUserPropsPath, $sExistingSlot)
        $__g_h_TCL_MsgBox(64, "TryCatch Lint", "Registration updated (slot " & $sExistingSlot & ")." & @CRLF & @CRLF & "Restart SciTE for the change to take effect.")
        Return
    EndIf

    Local $sAu3PropsPath = @ScriptDir & "\..\au3.properties"
    Local $sAu3Props     = FileExists($sAu3PropsPath) ? FileRead($sAu3PropsPath) : ""

    Local $iNextSlot = __TCL_NextFreeSlot($sAu3Props & @CRLF & $sUserProps)

    Local $sMsg = "TryCatch Lint is not yet registered in your SciTE Tools menu." & @CRLF & @CRLF & _
                  "Proposed command slot: " & $iNextSlot & @CRLF & _
                  "Script path: " & @ScriptFullPath & @CRLF & @CRLF & _
                  "Register it now?"
    Local $iAnswer = $__g_h_TCL_MsgBox(36, "TryCatch Lint - Register", $sMsg)

    If $iAnswer <> 6 Then
        $__g_h_TCL_MsgBox(64, "TryCatch Lint", "Registration cancelled.")
        Return
    EndIf

    __TCL_WriteRegistration($sUserPropsPath, $iNextSlot)
    $__g_h_TCL_MsgBox(64, "TryCatch Lint", "Registered successfully as Tools menu slot " & $iNextSlot & "." & @CRLF & @CRLF & "Restart SciTE for the change to take effect.")
EndFunc

; ===============================================================================================================================
; Internal helpers
; ===============================================================================================================================

; Returns the slot number if "TryCatch Lint" is already registered in $sProps, or "" if not found
; $sProps - raw properties file content to search
Func __TCL_FindExistingRegistration($sProps)
    Local $aMatch = StringRegExp($sProps, 'command\.name\.(\d+)\.\$\(au3\)=TryCatch Lint', 1)
    If @error Then Return ""
    Return $aMatch[0]
EndFunc

; Scans combined properties text for every command.N.* pattern and returns the next free
; slot, minimum 40 per the documented SciTE convention (numbers below that are reserved
; for built-in/future commands)
; $sCombinedProps - raw text of au3.properties + SciTEUser.properties concatenated
Func __TCL_NextFreeSlot($sCombinedProps)
    Local $aMatches = StringRegExp($sCombinedProps, 'command\.(?:name\.|shortcut\.|subsystem\.|save\.before\.)?(\d+)\.', 3)
    Local $iMax = 39
    If Not @error Then
        For $sNum In $aMatches
            If Number($sNum) > $iMax Then $iMax = Number($sNum)
        Next
    EndIf
    Return $iMax + 1
EndFunc

; Removes all command.*.SLOT.$(au3)=... lines (and the preceding "# SLOT TryCatch Lint" comment)
; for the given slot number from the file at $sPath
; $sPath - SciTEUser.properties path
; $iSlot - slot number whose lines should be removed
Func __TCL_RemoveRegistration($sPath, $iSlot)
    Local $sContent = FileRead($sPath)
    $sContent = StringRegExpReplace($sContent, '(?m)^#\s*' & $iSlot & '\s+TryCatch Lint\s*$\R?', "")
    $sContent = StringRegExpReplace($sContent, '(?m)^command\.\w*\.?' & $iSlot & '\.[^\r\n]*$\R?', "")
    Local $hFile = FileOpen($sPath, 2) ; overwrite mode
    FileWrite($hFile, $sContent)
    FileClose($hFile)
EndFunc

; Appends the registration block for $iSlot to the file at $sPath, using @ScriptFullPath
; as the registered TryCatchLint.au3 location
; $sPath - SciTEUser.properties path
; $iSlot - slot number to register at
Func __TCL_WriteRegistration($sPath, $iSlot)
    Local $sBlock = @CRLF & "# " & $iSlot & " TryCatch Lint" & @CRLF & _
        'command.' & $iSlot & '.$(au3)="$(SciteDefaultHome)\..\AutoIt3.exe" "$(SciteDefaultHome)\AutoIt3Wrapper\AutoIt3Wrapper.au3" /run /prod /ErrorStdOut /in "' & @ScriptFullPath & '" /UserParams "$(FilePath)" "$(SciteDefaultHome)\AutoIt3Wrapper\AutoIt3Wrapper.au3"' & @CRLF & _
        "command.name." & $iSlot & '.$(au3)=TryCatch Lint' & @CRLF & _
        "command.shortcut." & $iSlot & ".*.au3=Ctrl+Alt+L" & @CRLF & _
        "command.subsystem." & $iSlot & '.$(au3)=1' & @CRLF & _
        "command.save.before." & $iSlot & '.$(au3)=2' & @CRLF

    Local $hFile = FileOpen($sPath, 1) ; append mode (creates file if it doesn't exist)
    FileWrite($hFile, $sBlock)
    FileClose($hFile)
EndFunc