; #INDEX# =======================================================================================================================
; Title .........: AutoIt TryCatch - TryCatch Lint Tests
; Version .......: 0.0.1
; AutoIt Version : 3.3.18.0
; Author ........: Crucial Thread
; Description ...: Unit tests for TryCatchLint.au3
;                  Tests cover: block comment stripping (line numbers preserved), string literal stripping,
;                  function range splitting, Return-inside-try-region counting (including the documented
;                  early-return pattern), literal argument extraction/merging, and full end-to-end detection
;                  of both unbalanced try regions and unregistered exception name references - including
;                  _Catch()-specific typos, multiple/duplicate typos, case-insensitive matching, and files
;                  with no exception-related calls at all.
; Dependencies ..: TestFramework.au3, TryCatchLint.au3
; ===============================================================================================================================

#include "..\..\lib\TestFramework\TestFramework.au3"
#include "..\..\src\lint\TryCatchLint.au3"

; ===============================================================================================================================
; Tests - text cleaning
; ===============================================================================================================================

Func _TestStripBlockComments_PreservesLineNumbers()
    _TestFmkHeader("Test: __TCL_StripBlockComments preserves line numbers")
    Local $sContent = "Line1" & @CRLF & "#cs" & @CRLF & "_Try()" & @CRLF & "_EndTry()" & @CRLF & "#ce" & @CRLF & "Line6"
    Local $sResult = __TCL_StripBlockComments($sContent)
    Local $aSplit = StringSplit($sResult, @CRLF, 1)
    _TestFmkAssert($aSplit[0] = 6,        "Still has 6 lines after stripping",      $aSplit[0], "6")
    _TestFmkAssert($aSplit[6] = "Line6",  "Line 6 content is preserved correctly", $aSplit[6], "Line6")
    _TestFmkAssert(StringInStr($sResult, "_Try") = 0, "Block comment content is removed", StringInStr($sResult, "_Try"), "0")
EndFunc

Func _TestStripStringLiterals()
    _TestFmkHeader("Test: __TCL_StripStringLiterals")
    Local $sLine = '_TestFmkHeader("Test: _EndTry() decrements one level")'
    Local $sResult = __TCL_StripStringLiterals($sLine)
    _TestFmkAssert(StringInStr($sResult, "_EndTry") = 0, "String contents removed, no false _EndTry match", StringInStr($sResult, "_EndTry"), "0")
    _TestFmkAssert($sResult = '_TestFmkHeader("")', "Result is the function call with empty string", $sResult, '_TestFmkHeader("")')
EndFunc

Func _TestStripStringLiterals_PreservesCodeOutsideString()
    _TestFmkHeader("Test: __TCL_StripStringLiterals preserves real code outside the string")
    Local $sLine = '_Try() ; comment with "a string" inside'
    Local $sResult = __TCL_StripStringLiterals($sLine)
    _TestFmkAssert(StringInStr($sResult, "_Try()") > 0, "Real _Try() call outside the string survives", StringInStr($sResult, "_Try()") > 0, "True")
EndFunc

; ===============================================================================================================================
; Tests - function range splitting
; ===============================================================================================================================

Func _TestSplitIntoFunctionRanges()
    _TestFmkHeader("Test: __TCL_SplitIntoFunctionRanges")
    Local $aLines[6] = ["; top level", "Func _A()", "    _Try()", "EndFunc", "Func _B()", "EndFunc"]
    Local $aRanges = __TCL_SplitIntoFunctionRanges($aLines)

    _TestFmkAssert(UBound($aRanges) = 3, "Splits into 3 ranges (top-level + 2 funcs)", UBound($aRanges), "3")
    _TestFmkAssert($aRanges[0][0] = 1 And $aRanges[0][1] = 1, "Top-level range is line 1",   $aRanges[0][0] & "-" & $aRanges[0][1], "1-1")
    _TestFmkAssert($aRanges[1][0] = 2 And $aRanges[1][1] = 4, "Func _A() range is lines 2-4", $aRanges[1][0] & "-" & $aRanges[1][1], "2-4")
    _TestFmkAssert($aRanges[2][0] = 5 And $aRanges[2][1] = 6, "Func _B() range is lines 5-6", $aRanges[2][0] & "-" & $aRanges[2][1], "5-6")
EndFunc

Func _TestSplitIntoFunctionRanges_WithBlankLinesBetween()
    _TestFmkHeader("Test: __TCL_SplitIntoFunctionRanges handles blank lines between functions")
    Local $aLines[7] = ["Func _A()", "EndFunc", "", "Func _B()", "EndFunc", "", "_A()"]
    Local $aRanges = __TCL_SplitIntoFunctionRanges($aLines)
    _TestFmkAssert(UBound($aRanges) >= 2, "Finds both function ranges despite blank line separators", UBound($aRanges) >= 2, "True")
EndFunc

; ===============================================================================================================================
; Tests - Return-inside-try-region counting
; ===============================================================================================================================

Func _TestCountReturnsInsideTryRegions_CorrectPattern()
    _TestFmkHeader("Test: __TCL_CountReturnsInsideTryRegions - correctly closed early return")
    Local $aLines[7] = ["_Try()", '    _ThrowException("X")', "    If @error Then", "        Return _EndTry()", "    EndIf", "_Catch($e)", "_EndTry()"]
    Local $iCount = __TCL_CountReturnsInsideTryRegions($aLines)
    _TestFmkAssert($iCount = 1, "Counts the 1 Return inside the region (paired with its own _EndTry())", $iCount, "1")
EndFunc

Func _TestCountReturnsInsideTryRegions_MissingEndTry()
    _TestFmkHeader("Test: __TCL_CountReturnsInsideTryRegions - Return with missing _EndTry()")
    Local $aLines[6] = ["_Try()", '    _ThrowException("X")', "    If @error Then", "        Return False", "    EndIf", "_EndTry()"]
    Local $iCount = __TCL_CountReturnsInsideTryRegions($aLines)
    _TestFmkAssert($iCount = 1, "Still counts the Return even with no _EndTry() right before it", $iCount, "1")
EndFunc

Func _TestCountReturnsInsideTryRegions_UnrelatedReturn()
    _TestFmkHeader("Test: __TCL_CountReturnsInsideTryRegions - Return outside any try region")
    Local $aLines[1] = ["Return True"]
    Local $iCount = __TCL_CountReturnsInsideTryRegions($aLines)
    _TestFmkAssert($iCount = 0, "Does not count a Return with depth 0", $iCount, "0")
EndFunc

; ===============================================================================================================================
; Tests - literal argument extraction / merging
; ===============================================================================================================================

Func _TestExtractLiteralArgOccurrences()
    _TestFmkHeader("Test: __TCL_ExtractLiteralArgOccurrences")
    Local $aLines[3] = ['_ThrowException("Foo")', '_Catch($e, "Bar")', '_ThrowException("Foo")']
    Local $aResult = __TCL_ExtractLiteralArgOccurrences($aLines, "_ThrowException")
    _TestFmkAssert(UBound($aResult) = 2,  "Finds 2 occurrences (duplicates kept)", UBound($aResult), "2")
    _TestFmkAssert($aResult[0][0] = "Foo", "First occurrence name is correct",     $aResult[0][0],   "Foo")
    _TestFmkAssert($aResult[0][1] = 1,     "First occurrence line is correct",     $aResult[0][1],   "1")
    _TestFmkAssert($aResult[1][1] = 3,     "Second occurrence line is correct",    $aResult[1][1],   "3")
EndFunc

Func _TestExtractLiteralArgNames_Deduplicates()
    _TestFmkHeader("Test: __TCL_ExtractLiteralArgNames deduplicates")
    Local $aLines[2] = ['_RegisterException("Foo")', '_RegisterException("Foo")']
    Local $aResult = __TCL_ExtractLiteralArgNames($aLines, "_RegisterException")
    _TestFmkAssert(UBound($aResult) = 1, "Duplicate registrations collapse to 1 entry", UBound($aResult), "1")
EndFunc

Func _TestArrayContainsCI()
    _TestFmkHeader("Test: __TCL_ArrayContainsCI")
    Local $aArr[2] = ["Foo", "Bar"]
    _TestFmkAssert(__TCL_ArrayContainsCI($aArr, "foo") = True,  "Case-insensitive match found",     __TCL_ArrayContainsCI($aArr, "foo"), "True")
    _TestFmkAssert(__TCL_ArrayContainsCI($aArr, "Baz") = False, "Returns False when not found",     __TCL_ArrayContainsCI($aArr, "Baz"), "False")
EndFunc

Func _TestArrayMergeOccurrences()
    _TestFmkHeader("Test: __TCL_ArrayMergeOccurrences")
    Local $aTarget[1][2]
    $aTarget[0][0] = "Foo"
    $aTarget[0][1] = 1
    Local $aSource[1][2]
    $aSource[0][0] = "Bar"
    $aSource[0][1] = 2
    __TCL_ArrayMergeOccurrences($aTarget, $aSource)
    _TestFmkAssert(UBound($aTarget) = 2,    "Target now has 2 rows after merge", UBound($aTarget), "2")
    _TestFmkAssert($aTarget[1][0] = "Bar",  "Merged row name is correct",        $aTarget[1][0],   "Bar")
    _TestFmkAssert($aTarget[1][1] = 2,      "Merged row line is correct",        $aTarget[1][1],   "2")
EndFunc

; ===============================================================================================================================
; End-to-end tests - real file content, via temp files
; ===============================================================================================================================

Func __WriteTempFile($aContentLines)
    Local $sTempFile = @TempDir & "\TryCatchLint_Test_" & @AutoItPID & "_" & Random(1000, 9999, 1) & ".au3"
    Local $hFile = FileOpen($sTempFile, 2)
    For $sLine In $aContentLines
        FileWriteLine($hFile, $sLine)
    Next
    FileClose($hFile)
    Return $sTempFile
EndFunc

; Replicates _Main()'s Check 1 logic against a given file, returning True if ANY region is unbalanced
Func __RunCheck1($sPath)
    Local $sRawContent = FileRead($sPath)
    $sRawContent = __TCL_StripBlockComments($sRawContent)
    $sRawContent = StringReplace($sRawContent, @CRLF, @LF)
    Local $aRawSplit = StringSplit($sRawContent, @LF, 1)
    Local $aLines[$aRawSplit[0]]
    For $i = 1 To $aRawSplit[0]
        $aLines[$i - 1] = $aRawSplit[$i]
    Next

    Local $aCleanLines[0]
    For $i = 0 To UBound($aLines) - 1
        _ArrayAdd($aCleanLines, __TCL_CleanLine($aLines[$i]))
    Next

    Local $aRanges = __TCL_SplitIntoFunctionRanges($aCleanLines)
    Local $bAnyUnbalanced = False

    For $r = 0 To UBound($aRanges) - 1
        Local $aRangeLines = __TCL_SliceLines($aCleanLines, $aRanges[$r][0], $aRanges[$r][1])
        Local $iTryCount = 0
        Local $iEndTryCount = 0
        For $i = 0 To UBound($aRangeLines) - 1
            If StringRegExp($aRangeLines[$i], "_Try\s*\(\s*\)") Then $iTryCount += 1
            If StringRegExp($aRangeLines[$i], "_EndTry\s*\(") Then $iEndTryCount += 1
        Next
        Local $iReturnsInside = __TCL_CountReturnsInsideTryRegions($aRangeLines)
        If ($iTryCount + $iReturnsInside) <> $iEndTryCount Then $bAnyUnbalanced = True
    Next

    Return $bAnyUnbalanced
EndFunc

; Replicates _Main()'s Check 2 logic against a given file, returning True if ANY unregistered name is referenced
Func __RunCheck2($sPath)
    Local $aLines = __ReadCleanedLines($sPath)

    Local $aRegistered = __TCL_ExtractLiteralArgNames($aLines, "_RegisterException")
    Local $aFindings = __TCL_ExtractLiteralArgOccurrences($aLines, "_ThrowException")
    __TCL_ArrayMergeOccurrences($aFindings, __TCL_ExtractLiteralArgOccurrences($aLines, "_Catch"))

    For $i = 0 To UBound($aFindings) - 1
        If Not __TCL_ArrayContainsCI($aRegistered, $aFindings[$i][0]) Then Return True
    Next
    Return False
EndFunc

; Shared helper for the end-to-end tests: reads a file, strips block comments, normalizes line endings,
; and returns a clean 0-based array of lines (no string/comment stripping - Check 2 needs string contents intact)
Func __ReadCleanedLines($sPath)
    Local $sRawContent = FileRead($sPath)
    $sRawContent = __TCL_StripBlockComments($sRawContent)
    $sRawContent = StringReplace($sRawContent, @CRLF, @LF)
    Local $aRawSplit = StringSplit($sRawContent, @LF, 1)
    Local $aLines[$aRawSplit[0]]
    For $i = 1 To $aRawSplit[0]
        $aLines[$i - 1] = $aRawSplit[$i]
    Next
    Return $aLines
EndFunc

Func _TestEndToEnd_CorrectEarlyReturn_NotFlagged()
    _TestFmkHeader("Test: End-to-end - correctly closed early return is NOT flagged")
    Local $aContent[11] = [ _
        '_RegisterException("RealException", "msg")', _
        "Func _GoodFunc()", _
        "    _Try()", _
        '        _ThrowException("RealException")', _
        "        If @error Then", _
        "            Return _EndTry()", _
        "        EndIf", _
        "    Local $e", _
        "    _Catch($e)", _
        "    _EndTry()", _
        "EndFunc"]
    Local $sFile = __WriteTempFile($aContent)
    _TestFmkAssert(__RunCheck1($sFile) = False, "No unbalanced region detected", __RunCheck1($sFile), "False")
    FileDelete($sFile)
EndFunc

Func _TestEndToEnd_MissingEndTry_IsFlagged()
    _TestFmkHeader("Test: End-to-end - Return with missing _EndTry() IS flagged")
    Local $aContent[11] = [ _
        '_RegisterException("RealException", "msg")', _
        "Func _BadFunc()", _
        "    _Try()", _
        '        _ThrowException("RealException")', _
        "        If @error Then", _
        "            Return False", _
        "        EndIf", _
        "    Local $e", _
        "    _Catch($e)", _
        "    _EndTry()", _
        "EndFunc"]
    Local $sFile = __WriteTempFile($aContent)
    _TestFmkAssert(__RunCheck1($sFile) = True, "Unbalanced region IS detected", __RunCheck1($sFile), "True")
    FileDelete($sFile)
EndFunc

Func _TestEndToEnd_StringLiteralFalsePositive_NotFlagged()
    _TestFmkHeader("Test: End-to-end - _EndTry()-looking text inside a string is NOT flagged")
    Local $aContent[5] = [ _
        "Func _TestSomething()", _
        '    _TestFmkHeader("Test: _EndTry() decrements one level")', _
        "    _Try()", _
        "    _EndTry()", _
        "EndFunc"]
    Local $sFile = __WriteTempFile($aContent)
    _TestFmkAssert(__RunCheck1($sFile) = False, "String contents are not mistaken for a real call", __RunCheck1($sFile), "False")
    FileDelete($sFile)
EndFunc

Func _TestEndToEnd_UnregisteredException_IsFlagged()
    _TestFmkHeader("Test: End-to-end - unregistered exception name reference IS flagged")
    Local $aContent[7] = [ _
        '_RegisterException("RealException", "msg")', _
        "Func _TypoFunc()", _
        "    _Try()", _
        '        _ThrowException("TypoException")', _
        "    Local $e", _
        "    _Catch($e)", _
        "    _EndTry()"]
    Local $sFile = __WriteTempFile($aContent)
    _TestFmkAssert(__RunCheck2($sFile) = True, "Unregistered name reference IS detected", __RunCheck2($sFile), "True")
    FileDelete($sFile)
EndFunc

Func _TestEndToEnd_RegisteredException_NotFlagged()
    _TestFmkHeader("Test: End-to-end - registered exception name reference is NOT flagged")
    Local $aContent[7] = [ _
        '_RegisterException("RealException", "msg")', _
        "Func _GoodFunc()", _
        "    _Try()", _
        '        _ThrowException("RealException")', _
        "    Local $e", _
        "    _Catch($e)", _
        "    _EndTry()"]
    Local $sFile = __WriteTempFile($aContent)
    _TestFmkAssert(__RunCheck2($sFile) = False, "Registered name reference is NOT detected as a typo", __RunCheck2($sFile), "False")
    FileDelete($sFile)
EndFunc

Func _TestEndToEnd_CatchTypo_IsFlagged()
    _TestFmkHeader("Test: End-to-end - typo'd name in _Catch() (not _ThrowException) IS flagged")
    Local $aContent[8] = [ _
        '_RegisterException("RealException", "msg")', _
        "Func _CatchTypoFunc()", _
        "    _Try()", _
        '        _ThrowException("RealException")', _
        "    Local $e", _
        '    _Catch($e, "TypoCatchException")', _
        "    _EndTry()", _
        "EndFunc"]
    Local $sFile = __WriteTempFile($aContent)
    _TestFmkAssert(__RunCheck2($sFile) = True, "_Catch()'s own typo'd type argument is detected", __RunCheck2($sFile), "True")
    FileDelete($sFile)
EndFunc

Func _TestEndToEnd_MultipleDistinctTypos_AllFlagged()
    _TestFmkHeader("Test: End-to-end - multiple distinct typos in one file are all individually findable")
    Local $aContent[9] = [ _
        '_RegisterException("RealException", "msg")', _
        "Func _MultiTypoFunc()", _
        "    _Try()", _
        '        _ThrowException("FirstTypo")', _
        '        _ThrowException("SecondTypo")', _
        "    Local $e", _
        "    _Catch($e)", _
        "    _EndTry()", _
        "EndFunc"]
    Local $sFile = __WriteTempFile($aContent)

    Local $aLines = __ReadCleanedLines($sFile)
    Local $aRegistered = __TCL_ExtractLiteralArgNames($aLines, "_RegisterException")
    Local $aFindings = __TCL_ExtractLiteralArgOccurrences($aLines, "_ThrowException")
    Local $iUnregisteredCount = 0
    For $i = 0 To UBound($aFindings) - 1
        If Not __TCL_ArrayContainsCI($aRegistered, $aFindings[$i][0]) Then $iUnregisteredCount += 1
    Next

    _TestFmkAssert($iUnregisteredCount = 2, "Both distinct typos are found, not just the first", $iUnregisteredCount, "2")
    FileDelete($sFile)
EndFunc

Func _TestEndToEnd_DuplicateTypo_FoundOncePerOccurrence()
    _TestFmkHeader("Test: End-to-end - the SAME typo'd name used twice is reported per occurrence, not deduplicated away")
    Local $aContent[9] = [ _
        '_RegisterException("RealException", "msg")', _
        "Func _RepeatedTypoFunc()", _
        "    _Try()", _
        '        _ThrowException("SameTypo")', _
        '        _ThrowException("SameTypo")', _
        "    Local $e", _
        "    _Catch($e)", _
        "    _EndTry()", _
        "EndFunc"]
    Local $sFile = __WriteTempFile($aContent)

    Local $aLines = __ReadCleanedLines($sFile)
    Local $aFindings = __TCL_ExtractLiteralArgOccurrences($aLines, "_ThrowException")
    _TestFmkAssert(UBound($aFindings) = 2, "Both occurrences of the repeated typo are individually tracked (with their own line numbers)", UBound($aFindings), "2")
    FileDelete($sFile)
EndFunc

Func _TestEndToEnd_CaseInsensitiveMatch_NotFlagged()
    _TestFmkHeader("Test: End-to-end - registered name matched case-insensitively is NOT flagged as a typo")
    Local $aContent[7] = [ _
        '_RegisterException("RealException", "msg")', _
        "Func _CaseFunc()", _
        "    _Try()", _
        '        _ThrowException("realexception")', _
        "    Local $e", _
        "    _Catch($e)", _
        "    _EndTry()"]
    Local $sFile = __WriteTempFile($aContent)
    _TestFmkAssert(__RunCheck2($sFile) = False, "Differently-cased but otherwise matching name is NOT flagged", __RunCheck2($sFile), "False")
    FileDelete($sFile)
EndFunc

Func _TestEndToEnd_NoExceptionUsageAtAll_NotFlagged()
    _TestFmkHeader("Test: End-to-end - a file with no exception-related calls at all produces no Check 2 findings")
    Local $aContent[3] = ["Func _PlainFunc()", "    Return True", "EndFunc"]
    Local $sFile = __WriteTempFile($aContent)
    _TestFmkAssert(__RunCheck2($sFile) = False, "No findings when there's nothing exception-related to check", __RunCheck2($sFile), "False")
    FileDelete($sFile)
EndFunc

; ===============================================================================================================================
; Run all tests
; ===============================================================================================================================

Func _RunAllTests()
    Local $bAllPassed = True
    $bAllPassed = _TestFmkRun(_TestStripBlockComments_PreservesLineNumbers,      $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestStripStringLiterals,                          $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestStripStringLiterals_PreservesCodeOutsideString, $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestSplitIntoFunctionRanges,                      $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestSplitIntoFunctionRanges_WithBlankLinesBetween, $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestCountReturnsInsideTryRegions_CorrectPattern,  $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestCountReturnsInsideTryRegions_MissingEndTry,   $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestCountReturnsInsideTryRegions_UnrelatedReturn, $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestExtractLiteralArgOccurrences,                $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestExtractLiteralArgNames_Deduplicates,         $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestArrayContainsCI,                            $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestArrayMergeOccurrences,                      $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestEndToEnd_CorrectEarlyReturn_NotFlagged,      $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestEndToEnd_MissingEndTry_IsFlagged,            $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestEndToEnd_StringLiteralFalsePositive_NotFlagged, $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestEndToEnd_UnregisteredException_IsFlagged,    $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestEndToEnd_RegisteredException_NotFlagged,     $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestEndToEnd_CatchTypo_IsFlagged,               $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestEndToEnd_MultipleDistinctTypos_AllFlagged,  $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestEndToEnd_DuplicateTypo_FoundOncePerOccurrence, $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestEndToEnd_CaseInsensitiveMatch_NotFlagged,   $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestEndToEnd_NoExceptionUsageAtAll_NotFlagged,  $bAllPassed)
    _TestFmkSummary()
    Return $bAllPassed
EndFunc

_RunAllTests()
