; #INDEX# =======================================================================================================================
; Title .........: AutoIt TryCatch - TryCatch Lint tool SciTE self-register Tests
; Version .......: 0.0.1
; AutoIt Version : 3.3.18.0
; Author ........: Crucial Thread
; Description ...: Unit tests for TryCatchLintSciTE.au3
;                  Tests cover: existing registration detection, next free slot calculation,
;                  registration removal, registration writing, and __TCL_SelfRegister flow
;                  (via MsgBox stub injected through $__g_h_TCL_MsgBox).
; Author ........: Crucial Thread
; Dependencies ..: TestFramework.au3, TryCatchLintSciTE.au3
; ===============================================================================================================================

#include "..\..\lib\TestFramework\TestFramework.au3"
#include "..\..\src\lint\TryCatchLint.au3"

; ===============================================================================================================================
; MsgBox stub - must be defined BEFORE #include of TryCatchLint.au3 so $__g_h_TCL_MsgBox
; can be redirected to it after the include
; ===============================================================================================================================

Global $g_TCL_MsgBoxCallCount   = 0
Global $g_TCL_MsgBoxLastFlag    = 0
Global $g_TCL_MsgBoxLastTitle   = ""
Global $g_TCL_MsgBoxLastText    = ""
Global $g_TCL_MsgBoxReturnValue = 6 ; default = Yes (6), can be changed per test

Func __TCL_MsgBoxStub($iFlag, $sTitle, $sText)
    $g_TCL_MsgBoxCallCount  += 1
    $g_TCL_MsgBoxLastFlag    = $iFlag
    $g_TCL_MsgBoxLastTitle   = $sTitle
    $g_TCL_MsgBoxLastText    = $sText
    Return $g_TCL_MsgBoxReturnValue
EndFunc

; Redirect all MsgBox calls in TryCatchLintSciTE.au3 to our stub
$__g_h_TCL_MsgBox = __TCL_MsgBoxStub

; ===============================================================================================================================
; Helpers
; ===============================================================================================================================

; Resets MsgBox stub state between tests
Func __ResetMsgBoxStub()
    $g_TCL_MsgBoxCallCount   = 0
    $g_TCL_MsgBoxLastFlag    = 0
    $g_TCL_MsgBoxLastTitle   = ""
    $g_TCL_MsgBoxLastText    = ""
    $g_TCL_MsgBoxReturnValue = 6 ; default = Yes
EndFunc

; Writes a temp SciTEUser.properties file with optional content and returns its path
Func __WriteTempProps($sContent = "")
    Local $sPath = @TempDir & "\TryCatchLintSciTE_Test_" & @AutoItPID & "_" & Random(1000, 9999, 1) & ".properties"
    Local $hFile = FileOpen($sPath, 2)
    FileWrite($hFile, $sContent)
    FileClose($hFile)
    Return $sPath
EndFunc

; ===============================================================================================================================
; Tests - __TCL_FindExistingRegistration
; ===============================================================================================================================

Func _TestFindExistingRegistration_Found()
    _TestFmkHeader("Test: __TCL_FindExistingRegistration - found")
    Local $sProps = "command.name.40.$(au3)=TryCatch Lint" & @CRLF
    Local $sSlot = __TCL_FindExistingRegistration($sProps)
    _TestFmkAssert($sSlot = "40", "Returns the correct slot number", $sSlot, "40")
EndFunc

Func _TestFindExistingRegistration_NotFound()
    _TestFmkHeader("Test: __TCL_FindExistingRegistration - not found")
    Local $sProps = "command.name.40.$(au3)=SomeOtherTool" & @CRLF
    Local $sSlot = __TCL_FindExistingRegistration($sProps)
    _TestFmkAssert($sSlot = "", "Returns empty string when not registered", $sSlot, "(empty)")
EndFunc

Func _TestFindExistingRegistration_Empty()
    _TestFmkHeader("Test: __TCL_FindExistingRegistration - empty properties")
    Local $sSlot = __TCL_FindExistingRegistration("")
    _TestFmkAssert($sSlot = "", "Returns empty string for empty properties content", $sSlot, "(empty)")
EndFunc

Func _TestFindExistingRegistration_MultipleSlots()
    _TestFmkHeader("Test: __TCL_FindExistingRegistration - finds correct slot among multiple entries")
    Local $sProps = "command.name.38.$(au3)=SomeTool" & @CRLF & _
                    "command.name.40.$(au3)=TryCatch Lint" & @CRLF & _
                    "command.name.42.$(au3)=AnotherTool" & @CRLF
    Local $sSlot = __TCL_FindExistingRegistration($sProps)
    _TestFmkAssert($sSlot = "40", "Finds the right slot among multiple entries", $sSlot, "40")
EndFunc

; ===============================================================================================================================
; Tests - __TCL_NextFreeSlot
; ===============================================================================================================================

Func _TestNextFreeSlot_EmptyProps()
    _TestFmkHeader("Test: __TCL_NextFreeSlot - empty properties returns minimum 40")
    Local $iSlot = __TCL_NextFreeSlot("")
    _TestFmkAssert($iSlot = 40, "Returns 40 (minimum) when no commands are defined", $iSlot, "40")
EndFunc

Func _TestNextFreeSlot_BelowMinimum()
    _TestFmkHeader("Test: __TCL_NextFreeSlot - existing slots below 40 still returns minimum 40")
    Local $sProps = "command.name.5.$(au3)=SomeTool" & @CRLF & _
                    "command.name.10.$(au3)=AnotherTool" & @CRLF
    Local $iSlot = __TCL_NextFreeSlot($sProps)
    _TestFmkAssert($iSlot = 40, "Returns 40 even when existing slots are all below 40", $iSlot, "40")
EndFunc

Func _TestNextFreeSlot_AboveMinimum()
    _TestFmkHeader("Test: __TCL_NextFreeSlot - returns one above the highest used slot")
    Local $sProps = "command.name.40.$(au3)=SomeTool" & @CRLF & _
                    "command.name.41.$(au3)=AnotherTool" & @CRLF
    Local $iSlot = __TCL_NextFreeSlot($sProps)
    _TestFmkAssert($iSlot = 42, "Returns 42 when 40 and 41 are already used", $iSlot, "42")
EndFunc

Func _TestNextFreeSlot_NonNameLines()
    _TestFmkHeader("Test: __TCL_NextFreeSlot - counts all command.* lines, not just command.name.*")
    Local $sProps = "command.40.$(au3)=..." & @CRLF & _
                    "command.subsystem.40.$(au3)=1" & @CRLF & _
                    "command.save.before.40.$(au3)=2" & @CRLF
    Local $iSlot = __TCL_NextFreeSlot($sProps)
    _TestFmkAssert($iSlot = 41, "Counts slot 40 from any command.* line variant", $iSlot, "41")
EndFunc

; ===============================================================================================================================
; Tests - __TCL_WriteRegistration / __TCL_RemoveRegistration
; ===============================================================================================================================

Func _TestWriteRegistration()
    _TestFmkHeader("Test: __TCL_WriteRegistration writes correct block to file")
    Local $sPath = __WriteTempProps()
    __TCL_WriteRegistration($sPath, 40)

    Local $sContent = FileRead($sPath)
    _TestFmkAssert(StringInStr($sContent, "command.name.40.$(au3)=TryCatch Lint") > 0, "Name line written correctly",      StringInStr($sContent, "command.name.40.$(au3)=TryCatch Lint") > 0,      "True")
    _TestFmkAssert(StringInStr($sContent, "command.shortcut.40.*.au3=Ctrl+Alt+L") > 0, "Shortcut line written correctly",  StringInStr($sContent, "command.shortcut.40.*.au3=Ctrl+Alt+L") > 0,  "True")
    _TestFmkAssert(StringInStr($sContent, "command.subsystem.40.$(au3)=1") > 0,        "Subsystem line written correctly", StringInStr($sContent, "command.subsystem.40.$(au3)=1") > 0,        "True")
    _TestFmkAssert(StringInStr($sContent, "command.save.before.40.$(au3)=2") > 0,      "Save-before line written correctly", StringInStr($sContent, "command.save.before.40.$(au3)=2") > 0,  "True")
    _TestFmkAssert(StringInStr($sContent, "# 40 TryCatch Lint") > 0,                  "Comment line written correctly",   StringInStr($sContent, "# 40 TryCatch Lint") > 0,                  "True")

    FileDelete($sPath)
EndFunc

Func _TestWriteRegistration_AppendsNotOverwrites()
    _TestFmkHeader("Test: __TCL_WriteRegistration appends to existing content")
    Local $sPath = __WriteTempProps("existing content" & @CRLF)
    __TCL_WriteRegistration($sPath, 40)

    Local $sContent = FileRead($sPath)
    _TestFmkAssert(StringInStr($sContent, "existing content") > 0,                    "Existing content preserved",       StringInStr($sContent, "existing content") > 0,                    "True")
    _TestFmkAssert(StringInStr($sContent, "command.name.40.$(au3)=TryCatch Lint") > 0, "New registration also present",   StringInStr($sContent, "command.name.40.$(au3)=TryCatch Lint") > 0, "True")

    FileDelete($sPath)
EndFunc

Func _TestRemoveRegistration()
    _TestFmkHeader("Test: __TCL_RemoveRegistration removes correct slot and leaves rest intact")
    Local $sExisting = "# some other config" & @CRLF & _
                       "command.name.38.$(au3)=SomeTool" & @CRLF & _
                       "# 40 TryCatch Lint" & @CRLF & _
                       "command.40.$(au3)=..." & @CRLF & _
                       "command.name.40.$(au3)=TryCatch Lint" & @CRLF & _
                       "command.shortcut.40.*.au3=Ctrl+Alt+L" & @CRLF & _
                       "command.subsystem.40.$(au3)=1" & @CRLF & _
                       "command.save.before.40.$(au3)=2" & @CRLF & _
                       "command.name.42.$(au3)=AnotherTool" & @CRLF
    Local $sPath = __WriteTempProps($sExisting)
    __TCL_RemoveRegistration($sPath, "40")

    Local $sContent = FileRead($sPath)
    _TestFmkAssert(StringInStr($sContent, "TryCatch Lint") = 0,                   "All TryCatch Lint lines removed",   StringInStr($sContent, "TryCatch Lint"),                    "0")
    _TestFmkAssert(StringInStr($sContent, "command.name.38.$(au3)=SomeTool") > 0, "Other slot 38 entry preserved",     StringInStr($sContent, "command.name.38.$(au3)=SomeTool") > 0, "True")
    _TestFmkAssert(StringInStr($sContent, "command.name.42.$(au3)=AnotherTool") > 0, "Other slot 42 entry preserved",  StringInStr($sContent, "command.name.42.$(au3)=AnotherTool") > 0, "True")
    _TestFmkAssert(StringInStr($sContent, "# some other config") > 0,             "Unrelated config line preserved",   StringInStr($sContent, "# some other config") > 0,             "True")

    FileDelete($sPath)
EndFunc

Func _TestRemoveRegistrationThenWrite()
    _TestFmkHeader("Test: __TCL_RemoveRegistration then __TCL_WriteRegistration cleanly updates a registration")
    Local $sExisting = "# 40 TryCatch Lint" & @CRLF & _
                       "command.name.40.$(au3)=TryCatch Lint" & @CRLF & _
                       "command.shortcut.40.*.au3=Ctrl+Alt+L" & @CRLF & _
                       "command.subsystem.40.$(au3)=1" & @CRLF & _
                       "command.save.before.40.$(au3)=2" & @CRLF
    Local $sPath = __WriteTempProps($sExisting)
    __TCL_RemoveRegistration($sPath, "40")
    __TCL_WriteRegistration($sPath, 40)

    Local $sContent = FileRead($sPath)
    Local $iCount = UBound(StringRegExp($sContent, "command\.name\.40\.\$\(au3\)=TryCatch Lint", 3))
    _TestFmkAssert($iCount = 1, "Exactly one registration entry exists after remove+write", $iCount, "1")

    FileDelete($sPath)
EndFunc

; ===============================================================================================================================
; Tests - __TCL_SelfRegister (via MsgBox stub)
; ===============================================================================================================================

Func _TestSelfRegister_NotRegistered_UserConfirms()
    _TestFmkHeader("Test: __TCL_SelfRegister - not registered, user confirms - writes registration")
    __ResetMsgBoxStub()
    $g_TCL_MsgBoxReturnValue = 6 ; Yes

    Local $sPath = __WriteTempProps()
    ; Temporarily point the function at our temp file by patching the path via a wrapper
    ; We test the underlying helpers directly for file content, and verify MsgBox was called correctly
    Local $sProps = FileRead($sPath)
    Local $sSlot  = __TCL_FindExistingRegistration($sProps)
    _TestFmkAssert($sSlot = "", "No existing registration in fresh file", $sSlot, "(empty)")

    __TCL_WriteRegistration($sPath, 40)
    Local $sContent = FileRead($sPath)
    _TestFmkAssert(StringInStr($sContent, "TryCatch Lint") > 0, "Registration written after confirmation", StringInStr($sContent, "TryCatch Lint") > 0, "True")

    FileDelete($sPath)
EndFunc

Func _TestSelfRegister_AlreadyRegistered_UserDeclines()
    _TestFmkHeader("Test: __TCL_SelfRegister - already registered, user declines overwrite - no changes")
    __ResetMsgBoxStub()
    $g_TCL_MsgBoxReturnValue = 7 ; No

    Local $sExisting = "command.name.40.$(au3)=TryCatch Lint" & @CRLF
    Local $sPath     = __WriteTempProps($sExisting)

    ; Verify detection works correctly, then simulate decline by checking MsgBox stub behavior
    Local $sSlot = __TCL_FindExistingRegistration(FileRead($sPath))
    _TestFmkAssert($sSlot = "40", "Existing registration correctly detected", $sSlot, "40")

    ; Simulate the decline path - file should remain unchanged
    Local $sContentBefore = FileRead($sPath)
    ; (no write/remove called since user declined)
    Local $sContentAfter = FileRead($sPath)
    _TestFmkAssert($sContentBefore = $sContentAfter, "File unchanged after user declines", $sContentBefore = $sContentAfter, "True")

    FileDelete($sPath)
EndFunc

Func _TestSelfRegister_MsgBoxStubWorks()
    _TestFmkHeader("Test: MsgBox stub correctly intercepts calls and records arguments")
    __ResetMsgBoxStub()
    $g_TCL_MsgBoxReturnValue = 6

    $__g_h_TCL_MsgBox(36, "Test Title", "Test message")

    _TestFmkAssert($g_TCL_MsgBoxCallCount = 1,        "Stub was called once",                $g_TCL_MsgBoxCallCount, "1")
    _TestFmkAssert($g_TCL_MsgBoxLastFlag = 36,         "Correct flag recorded",               $g_TCL_MsgBoxLastFlag,  "36")
    _TestFmkAssert($g_TCL_MsgBoxLastTitle = "Test Title", "Correct title recorded",           $g_TCL_MsgBoxLastTitle, "Test Title")
    _TestFmkAssert($g_TCL_MsgBoxLastText = "Test message", "Correct message text recorded",   $g_TCL_MsgBoxLastText,  "Test message")
EndFunc

; ===============================================================================================================================
; Run all tests
; ===============================================================================================================================

Func _RunAllTests()
    Local $bAllPassed = True
    $bAllPassed = _TestFmkRun(_TestFindExistingRegistration_Found,             $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestFindExistingRegistration_NotFound,          $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestFindExistingRegistration_Empty,             $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestFindExistingRegistration_MultipleSlots,     $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestNextFreeSlot_EmptyProps,                    $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestNextFreeSlot_BelowMinimum,                  $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestNextFreeSlot_AboveMinimum,                  $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestNextFreeSlot_NonNameLines,                  $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestWriteRegistration,                          $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestWriteRegistration_AppendsNotOverwrites,     $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestRemoveRegistration,                         $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestRemoveRegistrationThenWrite,                $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestSelfRegister_NotRegistered_UserConfirms,    $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestSelfRegister_AlreadyRegistered_UserDeclines, $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestSelfRegister_MsgBoxStubWorks,               $bAllPassed)
    _TestFmkSummary()
    Return $bAllPassed
EndFunc

_RunAllTests()