; #INDEX# =======================================================================================================================
; Title .........: AutoIt TryCatch - TryCatch Lint tool
; Version .......: 0.0.1
; AutoIt Version : 3.3.18.0
; Author ........: Crucial Thread
; Description ...: Static analysis tool for TryCatch.au3 usage.
;                  Run against a single .au3 file. Scans the file's own text only - does not follow #include.
;                  Checks performed:
;                    1) _Try()/_EndTry() call count balance, scoped per function and per top-level region.
;                       Accounts for the documented "Return _EndTry()" early-return pattern - a correctly
;                       closed early return is NOT flagged, while a Return missing its _EndTry() IS flagged.
;                    2) Literal exception names passed to _ThrowException()/_Catch() that don't match any
;                       name registered via _RegisterException() in the same file - likely a typo. Matches
;                       a quoted string anywhere within the call's parentheses, so _Catch($e, "TypeName")
;                       is correctly handled even though the name is the 2nd argument, not the first.
; Usage .........: As a SciTE Tools menu command (the primary use case):
;                  Wire via SciTEUser.properties - or run this script directly via F5/Go inside SciTE with
;                  no arguments to trigger the self-registration flow (see TryCatchLintSciTE.au3).
;                  Once registered, the lint runs against whatever .au3 file is currently open in SciTE,
;                  outputs findings in the console, and auto-jumps to the first finding.
;                  Standalone from any command line:
;                  AutoIt3.exe TryCatchLint.au3 "path\to\script.au3" ["path\to\AutoIt3Wrapper.au3"]
;                  Exit code 0 = clean, 2 = errors found. The auto-jump is a graceful no-op without SciTE.
; Dependencies ..: TryCatchLintSciTE.au3 (self-registration), File.au3, Array.au3
; Note ..........: Before any pattern matching, the file is cleaned in this order:
;                    1) #cs/#ce block comments stripped at the whole-file level, replaced with an equal
;                       number of blank lines so all subsequent line numbers stay accurate.
;                    2) Double-quoted string literal contents emptied per line (for Check 1 only) - so
;                       text like _TestFmkHeader("...mentions _EndTry()...") is never a false positive.
;                    3) ";" line comments stripped per line.
;                  Check 2 deliberately skips step 2 - the exception name IS the string content.
; Note ..........: Line endings are normalized (CRLF to LF) before splitting, so files saved with either
;                  convention are handled correctly and line numbers stay accurate.
; Note ..........: TEXT-BASED SCANNER - not a real AutoIt parser. Will miss or misreport on unusual
;                  formatting (calls split across line continuations, dynamically built strings, etc.).
;                  Treat findings as strong hints, not guarantees.
; Note ..........: #include-once safe. Guards its own entry point via @ScriptName, so TryCatchLintTests.au3
;                  can #include this file directly to test its internals without triggering _TCL_Init().
; Note ..........: All functions and constants use a TCL_ prefix to avoid collisions with TryCatch.au3
;                  and Exception.au3 internals.
; ===============================================================================================================================

#include-once
#include <File.au3>
#include <Array.au3>
#include "TryCatchLintSciTE.au3"

; ===============================================================================================================================
; Constants
; ===============================================================================================================================

Global Const $TCLINT_EXIT_OK    = 0
Global Const $TCLINT_EXIT_ERROR = 2 ; matches Au3Check's own exit code on error, so Go-style chains stop here

Global Const $TCLINT_ERR_NOFILE   = 1 ; no target file argument provided
Global Const $TCLINT_ERR_NOTFOUND = 2 ; target file does not exist on disk

; ===============================================================================================================================
; Entry points
; ===============================================================================================================================

; Routes to self-registration (when run directly inside SciTE with no arguments) or to the
; linter (when invoked with a target file, either from SciTE's Tools menu or the command line)
Func _TCL_Init()
    If $CmdLine[0] < 1 Then
        If __TCL_IsRunningFromSciTE() Then
            __TCL_SelfRegister()
        Else
            ConsoleWrite(__TCL_ErrMsg($TCLINT_ERR_NOFILE) & @CRLF)
        EndIf
        Exit $TCLINT_EXIT_OK
    EndIf

    _TCL_Main()
EndFunc

; Runs both lint checks against the target file and reports findings to the console in the
; exact Au3Check format so SciTE can inline-highlight them. Exits with $TCLINT_EXIT_ERROR if
; any errors were found, $TCLINT_EXIT_OK otherwise.
Func _TCL_Main()
    If Not __TCL_IsPromptValid() Then Exit $TCLINT_EXIT_ERROR

    Local $sWrapperPath = __TCL_AutoItWrapperPath()
    Local $sPath        = $CmdLine[1]
    Local $aLines       = __TCL_NormalizeContent(__TCL_LoadContent($sPath))

    Local $iErrors   = 0
    Local $iWarnings = 0

    ; --- Check 1: _Try()/_EndTry() balance, scoped per function/region, with Return accounting ---
    Local $aCleanLines[0]
    For $sLine In $aLines
        _ArrayAdd($aCleanLines, __TCL_CleanLine($sLine))
    Next

    Local $aRanges = __TCL_SplitIntoFunctionRanges($aCleanLines)

    For $iRange = 0 To UBound($aRanges) - 1
        Local $iRangeStart = $aRanges[$iRange][0]
        Local $iRangeEnd   = $aRanges[$iRange][1]
        Local $aRangeLines = __TCL_SliceLines($aCleanLines, $iRangeStart, $iRangeEnd)

        Local $aTryLines[0]
        Local $aEndTryLines[0]
        For $i = 0 To UBound($aRangeLines) - 1
            If StringRegExp($aRangeLines[$i], "_Try\s*\(\s*\)") Then _ArrayAdd($aTryLines, $iRangeStart + $i)
            If StringRegExp($aRangeLines[$i], "_EndTry\s*\(") Then _ArrayAdd($aEndTryLines, $iRangeStart + $i)
        Next

        Local $iReturnsInside = __TCL_CountReturnsInsideTryRegions($aRangeLines)
        Local $iTryEquivalent = UBound($aTryLines) + $iReturnsInside

        If $iTryEquivalent <> UBound($aEndTryLines) Then
            $iErrors += 1
            Local $iWorstLine = $iRangeStart
            If UBound($aTryLines) > 0 And $iTryEquivalent > UBound($aEndTryLines) Then
                $iWorstLine = $aTryLines[UBound($aTryLines) - 1]
            ElseIf UBound($aEndTryLines) > 0 Then
                $iWorstLine = $aEndTryLines[UBound($aEndTryLines) - 1]
            EndIf
            __TCL_EmitFinding($sPath, $iWorstLine, "1", "error", _
                "Unbalanced _Try()/_EndTry() in this function/region: found " & UBound($aTryLines) & " _Try() call(s) (+ " & _
                $iReturnsInside & " Return(s) inside try regions expecting their own _EndTry()) but " & _
                UBound($aEndTryLines) & " _EndTry() call(s)")
        EndIf
    Next

    ; --- Check 2: exception name typos, reporting the line of each unmatched reference ---
    Local $aRegistered = __TCL_ExtractLiteralArgNames($aLines, "_RegisterException")

    Local $aFindings = __TCL_ExtractLiteralArgOccurrences($aLines, "_ThrowException")
    __TCL_ArrayMergeOccurrences($aFindings, __TCL_ExtractLiteralArgOccurrences($aLines, "_Catch"))

    For $i = 0 To UBound($aFindings) - 1
        Local $sName = $aFindings[$i][0]
        Local $iLine = $aFindings[$i][1]
        If Not __TCL_ArrayContainsCI($aRegistered, $sName) Then
            $iWarnings += 1
            __TCL_EmitFinding($sPath, $iLine, "1", "warning", _
                "'" & $sName & "' is not registered via _RegisterException() in this file. " & _
                "Possible typo, or it relies on auto-registration / is registered in another file")
        EndIf
    Next

    If $iErrors = 0 And $iWarnings = 0 Then
        ConsoleWrite("+ [TryCatchLint] No issues found in " & $sPath & @CRLF)
    EndIf

    ConsoleWrite(@CRLF & $sPath & " - " & $iErrors & " error(s), " & $iWarnings & " warning(s)" & @CRLF)

    ; Launch AutoIt3Wrapper.au3 in /Jump2FirstError mode so SciTE auto-jumps to the first finding.
    ; Sends IDM_NEXTMSG (306) via the Director Interface - same mechanism as Go/Build/Test Run.
    ; Gracefully does nothing if no SciTE instance is running.
    If $iErrors > 0 Or $iWarnings > 0 Then
        If FileExists($sWrapperPath) Then
            Run('"' & @AutoItExe & '" "' & $sWrapperPath & '" /Jump2FirstError ' & @AutoItPID)
        EndIf
    EndIf

    If $iErrors > 0 Then Exit $TCLINT_EXIT_ERROR
    Exit $TCLINT_EXIT_OK
EndFunc

; ===============================================================================================================================
; Helpers - pre-flight
; ===============================================================================================================================

; Returns a human-readable error message for a given error code
; $iError - one of the $TCLINT_ERR_* constants
Func __TCL_ErrMsg($iError)
    Switch $iError
        Case $TCLINT_ERR_NOFILE
            Return "! [LINT ERROR] No file specified. Usage: TryCatchLint.au3 <path-to-au3-file> [path-to-AutoIt3Wrapper.au3]"
        Case $TCLINT_ERR_NOTFOUND
            Return "! [LINT ERROR] File not found: " & $CmdLine[1]
        Case Else
            Return "! [LINT ERROR] Unknown error"
    EndSwitch
EndFunc

; Validates that a target file was provided on the command line and that it exists on disk.
; Prints the corresponding error message to the console on the first failing check.
; Returns: True if valid, False with @error set to the failing $TCLINT_ERR_* code otherwise
Func __TCL_IsPromptValid()
    If $CmdLine[0] < 1 Then
        ConsoleWrite(__TCL_ErrMsg($TCLINT_ERR_NOFILE) & @CRLF)
        Return SetError($TCLINT_ERR_NOFILE, 0, False)
    EndIf

    Local $sPath = $CmdLine[1]
    If Not FileExists($sPath) Then
        ConsoleWrite(__TCL_ErrMsg($TCLINT_ERR_NOTFOUND) & @CRLF)
        Return SetError($TCLINT_ERR_NOTFOUND, 0, False)
    EndIf

    Return True
EndFunc

; Returns the path to AutoIt3Wrapper.au3 - from $CmdLine[2] if provided by SciTEUser.properties,
; otherwise falls back to a best-effort guess relative to this script's own install location
Func __TCL_AutoItWrapperPath()
    Return ($CmdLine[0] >= 2) ? $CmdLine[2] : @ScriptDir & "\..\AutoIt3Wrapper\AutoIt3Wrapper.au3"
EndFunc

; Reads and returns the full raw content of $sPath.
; Exits with $TCLINT_EXIT_ERROR immediately if the file cannot be read.
; $sPath - path to the file to read
Func __TCL_LoadContent($sPath)
    Local $sRawContent = FileRead($sPath)
    If @error Then
        ConsoleWrite("! [LINT ERROR] Could not read file: " & $sPath & @CRLF)
        Exit $TCLINT_EXIT_ERROR
    EndIf
    Return $sRawContent
EndFunc

; ===============================================================================================================================
; Helpers - content normalization
; ===============================================================================================================================

; Full file-level normalization pipeline: strips #cs/#ce block comments first (preserving line
; numbers), then normalizes line endings and splits into a 0-based array of lines.
; This is the single entry point for preparing raw file content before any scanning begins.
; $sRawContent - raw file content as read from disk
Func __TCL_NormalizeContent($sRawContent)
    Return __TCL_NormalizeLines(__TCL_StripBlockComments($sRawContent))
EndFunc

; Normalizes line endings (CRLF to LF) then splits $sRawContent into a clean 0-based array of lines.
; Handles files saved with either \r\n or \n line endings without shifting line numbers.
; $sRawContent - raw file content (block comments should already be stripped before calling this)
Func __TCL_NormalizeLines($sRawContent)
    $sRawContent = StringReplace($sRawContent, @CRLF, @LF)
    Local $aRawSplit = StringSplit($sRawContent, @LF, $STR_ENTIRESPLIT)
    Local $aLines[$aRawSplit[0]]
    For $i = 1 To $aRawSplit[0]
        $aLines[$i - 1] = $aRawSplit[$i]
    Next
    Return $aLines
EndFunc

; ===============================================================================================================================
; Helpers - text cleaning (block comments, string literals, line comments)
; ===============================================================================================================================

; Removes #cs...#ce block comments from $sContent, replacing each removed block with an equal
; number of blank lines so every line after the block retains its original line number.
; Must be called at the whole-file level (before splitting into lines) since blocks span lines.
; $sContent - raw file content
Func __TCL_StripBlockComments($sContent)
    Local $aBlocks = StringRegExp($sContent, "(?is)#cs.*?#ce", $STR_REGEXPARRAYGLOBALMATCH)
    If @error Then Return $sContent

    For $sBlock In $aBlocks
        Local $iNewlineCount = __TCL_CountNewlines($sBlock)
        Local $sReplacement = ""
        For $i = 1 To $iNewlineCount
            $sReplacement &= @CRLF
        Next
        $sContent = __TCL_ReplaceFirst($sContent, $sBlock, $sReplacement)
    Next

    Return $sContent
EndFunc

; Returns the number of newline sequences (CRLF or LF) found in $sText
Func __TCL_CountNewlines($sText)
    Local $aMatches = StringRegExp($sText, "\r\n|\n", $STR_REGEXPARRAYGLOBALMATCH)
    If @error Then Return 0
    Return UBound($aMatches)
EndFunc

; Replaces only the FIRST occurrence of $sBlock in $sContent with $sReplacement.
; Used by __TCL_StripBlockComments to replace one block at a time without accidentally
; removing a second identical block in the same file.
Func __TCL_ReplaceFirst($sContent, $sBlock, $sReplacement)
    Local $iPos = StringInStr($sContent, $sBlock)
    If $iPos = 0 Then Return $sContent
    Return StringLeft($sContent, $iPos - 1) & $sReplacement & StringMid($sContent, $iPos + StringLen($sBlock))
EndFunc

; Empties the contents of every double-quoted string literal on $sLine, replacing each with "".
; Respects AutoIt's "" escape convention (a doubled "" inside a string is NOT the closing quote).
; Used for Check 1 only - so try/catch-looking text that only ever appears inside a string
; literal (e.g. in a test header) is never mistaken for a real function call.
; $sLine - a single line of source text
Func __TCL_StripStringLiterals($sLine)
    Return StringRegExpReplace($sLine, '"(?:[^"]|"")*"', '""')
EndFunc

; Removes a ";" line comment (and everything after it) from $sLine.
; Must be called AFTER __TCL_StripStringLiterals, so a ";" that only appeared inside a
; (now emptied) string literal cannot be mistaken for the start of a real comment.
; $sLine - a single line of source text
Func __TCL_StripComment($sLine)
    Return StringRegExpReplace($sLine, ";.*$", "")
EndFunc

; Applies the full per-line cleaning pipeline: empty string literal contents, then strip line comments.
; Block comments must already have been removed at the whole-file level before this is called.
; $sLine - a single raw line of source text
Func __TCL_CleanLine($sLine)
    Return __TCL_StripComment(__TCL_StripStringLiterals($sLine))
EndFunc

; ===============================================================================================================================
; Helpers - _Try()/_EndTry() balance
; ===============================================================================================================================

; Splits $aLines into per-function line ranges, returning a 2D array of [startLine, endLine]
; (1-based, inclusive). Lines outside any Func...EndFunc are returned as their own range(s)
; so top-level try/catch usage is also checked.
; $aLines - array of cleaned source lines
Func __TCL_SplitIntoFunctionRanges($aLines)
    Local $aRanges[0][2]
    Local $iStart  = 1
    Local $bInFunc = False

    For $i = 0 To UBound($aLines) - 1
        Local $sLine = $aLines[$i]
        If Not $bInFunc And StringRegExp($sLine, "(?i)^\s*Func\s+\w") Then
            If $i + 1 > $iStart Then __TCL_AddRange($aRanges, $iStart, $i)
            $iStart = $i + 1
            $bInFunc = True
        ElseIf $bInFunc And StringRegExp($sLine, "(?i)^\s*EndFunc\b") Then
            __TCL_AddRange($aRanges, $iStart, $i + 1)
            $iStart = $i + 2
            $bInFunc = False
        EndIf
    Next

    If $iStart <= UBound($aLines) Then __TCL_AddRange($aRanges, $iStart, UBound($aLines))
    Return $aRanges
EndFunc

; Appends a [iStart, iEnd] row onto $aRanges (ByRef)
Func __TCL_AddRange(ByRef $aRanges, $iStart, $iEnd)
    ReDim $aRanges[UBound($aRanges) + 1][2]
    $aRanges[UBound($aRanges) - 1][0] = $iStart
    $aRanges[UBound($aRanges) - 1][1] = $iEnd
EndFunc

; Returns a 1-based-inclusive slice of $aLines from $iStart to $iEnd as a new 0-based array
Func __TCL_SliceLines($aLines, $iStart, $iEnd)
    Local $aSlice[$iEnd - $iStart + 1]
    For $i = $iStart To $iEnd
        $aSlice[$i - $iStart] = $aLines[$i - 1]
    Next
    Return $aSlice
EndFunc

; Returns the number of Return statements found strictly inside an open _Try()/_EndTry() region,
; at any nesting depth. Each such Return implies an extra _EndTry() is required (either on the
; same line as "Return _EndTry()" or on the preceding line), so it counts as an extra _Try()
; equivalent in the balance check. Depth is sampled at the START of each line, so a line like
; "Return _EndTry()" correctly counts as "inside" even though _EndTry() closes the region on
; that same line.
; $aLines - array of cleaned source lines (typically one function's range)
Func __TCL_CountReturnsInsideTryRegions($aLines)
    Local $iDepth       = 0
    Local $iReturnCount = 0

    For $sLine In $aLines
        Local $iDepthAtLineStart = $iDepth

        If StringRegExp($sLine, "_Try\s*\(\s*\)") Then $iDepth += 1
        If StringRegExp($sLine, "_EndTry\s*\(") Then $iDepth -= 1

        If $iDepthAtLineStart > 0 And StringRegExp($sLine, "(?i)\bReturn\b") Then $iReturnCount += 1
    Next

    Return $iReturnCount
EndFunc

; ===============================================================================================================================
; Helpers - exception name extraction
; ===============================================================================================================================

; Writes a finding to the console in the exact Au3Check format that SciTE recognizes for
; inline error/warning highlighting and F4 (Next Message) navigation.
; $sPath  - full path of the file being linted
; $iLine  - 1-based line number of the finding
; $sCol   - column number (always "1" - we don't track real columns, but SciTE still jumps to the line)
; $sLevel - "error" or "warning"
; $sMsg   - finding description (a period is appended automatically)
Func __TCL_EmitFinding($sPath, $iLine, $sCol, $sLevel, $sMsg)
    ConsoleWrite('"' & $sPath & '"(' & $iLine & ',' & $sCol & ') : ' & $sLevel & ': ' & $sMsg & "." & @CRLF)
EndFunc

; Returns a deduplicated array of literal string arguments found anywhere within $sFuncName(...)
; calls across $aLines (case preserved, no line number tracking).
; Used to build the set of registered exception names from _RegisterException() calls.
; Note: does NOT strip string literal contents - the names themselves ARE the string content.
;       Only line comments are stripped to avoid matching commented-out calls.
; $aLines    - raw (block-comment-stripped) source lines
; $sFuncName - function name to scan for (e.g. "_RegisterException")
Func __TCL_ExtractLiteralArgNames($aLines, $sFuncName)
    Local $aResult[0]
    For $sRawLine In $aLines
        Local $sLine    = __TCL_StripComment($sRawLine)
        Local $aMatches = StringRegExp($sLine, $sFuncName & '\s*\([^)]*?"([^"]*)"', $STR_REGEXPARRAYGLOBALMATCH)
        If Not @error Then
            For $sMatch In $aMatches
                If Not __TCL_ArrayContainsCI($aResult, $sMatch) Then _ArrayAdd($aResult, $sMatch)
            Next
        EndIf
    Next
    Return $aResult
EndFunc

; Returns a 2D array of [name, lineNumber] for every literal string argument found anywhere
; within $sFuncName(...) calls across $aLines. Keeps duplicate occurrences (each with its own
; line number) so every individual use site can be reported separately.
; Matches a quoted string anywhere in the parentheses - not just the first argument - so
; _Catch($e, "TypeName") is correctly captured even though the name is the 2nd argument.
; Note: does NOT strip string literal contents (same reasoning as __TCL_ExtractLiteralArgNames).
; $aLines    - raw (block-comment-stripped) source lines
; $sFuncName - function name to scan for (e.g. "_ThrowException", "_Catch")
Func __TCL_ExtractLiteralArgOccurrences($aLines, $sFuncName)
    Local $aResult[0][2]
    For $i = 0 To UBound($aLines) - 1
        Local $sLine    = __TCL_StripComment($aLines[$i])
        Local $aMatches = StringRegExp($sLine, $sFuncName & '\s*\([^)]*?"([^"]*)"', $STR_REGEXPARRAYGLOBALMATCH)
        If Not @error Then
            For $sMatch In $aMatches
                ReDim $aResult[UBound($aResult) + 1][2]
                $aResult[UBound($aResult) - 1][0] = $sMatch
                $aResult[UBound($aResult) - 1][1] = $i + 1
            Next
        EndIf
    Next
    Return $aResult
EndFunc

; Appends every row of $aSource onto $aTarget (both ByRef/2D [name, lineNumber] arrays)
Func __TCL_ArrayMergeOccurrences(ByRef $aTarget, $aSource)
    For $i = 0 To UBound($aSource) - 1
        ReDim $aTarget[UBound($aTarget) + 1][2]
        $aTarget[UBound($aTarget) - 1][0] = $aSource[$i][0]
        $aTarget[UBound($aTarget) - 1][1] = $aSource[$i][1]
    Next
EndFunc

; Returns True if $sValue exists anywhere in 1D array $aArray (case-insensitive)
Func __TCL_ArrayContainsCI($aArray, $sValue)
    If UBound($aArray) = 0 Then Return False
    Return _ArraySearch($aArray, $sValue, 0, 0, 0, 0, 1) <> -1
EndFunc

; ===============================================================================================================================
; Auto-run guard - only executes when this script is run directly, not when #include'd
; ===============================================================================================================================

If @ScriptName = "TryCatchLint.au3" Then _TCL_Init()