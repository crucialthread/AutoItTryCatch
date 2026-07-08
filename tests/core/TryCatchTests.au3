; #INDEX# =======================================================================================================================
; Title .........: AutoIt TryCatch - TryCatch.au3 Tests
; Version .......: 0.0.1
; AutoIt Version : 3.3.18.0
; Author ........: Crucial Thread
; Description ...: Unit tests for TryCatch.au3
;                  Tests cover: initial state, try activation, exception throwing/auto-registration,
;                  function skipping via _OnErrorResume/_NoErr, _TryWith (with and without _NoErr guard),
;                  _Catch single-match-per-scope behavior and If/ElseIf type chains, nested try/catch,
;                  _EndTry() decrementing one level vs _EndTry($FORCE_RESET), stack entry source/type, exception message
;                  override, scope stack count, _Catch inside another _Catch's reaction block,
;                  _StackTrace/_FormatStackTrace, and _AsExceptionType/multi-type _Catch matching
;                  (bare string, comma-separated list, array passthrough, list-order-beats-recency).
; Dependencies ..: TestFramework.au3, TryCatch.au3
; Note ..........: _EndTry($FORCE_RESET) is only used where genuinely required (the force-reset test itself, or
;                  cleaning up after a deliberately unclosed nested _Try()). Every other test uses _EndTry() as
;                  normally written, since that is the common/default usage being verified.
; ===============================================================================================================================

#include "..\..\lib\TestFramework\TestFramework.au3"
#include "..\..\src\core\TryCatch.au3"
#include <Array.au3>

; ===============================================================================================================================
; Register test exceptions
; ===============================================================================================================================

_RegisterException("TestException", "A test exception occurred")
_RegisterException("TestChildException", "A child test exception occurred", "TestException")
_RegisterException("OtherException", "An unrelated exception occurred")
_RegisterException("AlphaException", "Alpha exception occurred")
_RegisterException("BetaException", "Beta exception occurred")

; ===============================================================================================================================
; Helper functions for tests - compatible TryCatch functions follow the documented pattern
; ===============================================================================================================================

Func _FuncNoError()
    If _OnErrorResume() Then Return SetError(__GetStackCount(), 0, False)
EndFunc

Func _FuncWithError($sException = "TestException", $sMessage = Default)
    If _OnErrorResume() Then Return SetError(__GetStackCount(), 0, False)
    Return SetError(_ThrowException($sException, $sMessage, _FuncWithError), 0, False)
EndFunc

Func _FuncRecordExecution(ByRef $bExecuted)
    If _OnErrorResume() Then Return SetError(__GetStackCount(), 0, False)
    $bExecuted = True
EndFunc

; ===============================================================================================================================
; Tests
; ===============================================================================================================================

Func _TestInitialState()
    _TestFmkHeader("Test: Initial State")
    _TestFmkAssert(__IsInTry() = False,    "Try/catch inactive by default", __IsInTry(),        "False")
    _TestFmkAssert(__GetDepthLevel() = 0,  "Depth is 0 by default",         __GetDepthLevel(),  "0")
    _TestFmkAssert(__GetStackCount() = 0,  "Stack count is 0 by default",   __GetStackCount(),  "0")
    _TestFmkAssert(__IsCatched() = False,  "Not catched by default",        __IsCatched(),      "False")
EndFunc

Func _TestTryActivates()
    _TestFmkHeader("Test: _Try activates try/catch, _EndTry deactivates it")
    _Try()
    _TestFmkAssert(__IsInTry() = True,    "Try/catch active after _Try",      __IsInTry(),        "True")
    _TestFmkAssert(__GetDepthLevel() = 1, "Depth is 1 after _Try",            __GetDepthLevel(),  "1")
    _EndTry()
    _TestFmkAssert(__IsInTry() = False,   "Try/catch inactive after _EndTry", __IsInTry(),        "False")
    _TestFmkAssert(__GetDepthLevel() = 0, "Depth is 0 after _EndTry",         __GetDepthLevel(),  "0")
EndFunc

Func _TestEndTryDecrementsOneLevel()
    _TestFmkHeader("Test: _EndTry() decrements exactly one level when nested")
    _Try()                                 ; depth 1
        _Try()                             ; depth 2
            _TestFmkAssert(__GetDepthLevel() = 2, "Depth is 2 inside nested _Try", __GetDepthLevel(), "2")
        _EndTry()                          ; decrements only one level - should not reset everything
        _TestFmkAssert(__GetDepthLevel() = 1, "Depth is 1 after inner _EndTry", __GetDepthLevel(), "1")
        _TestFmkAssert(__IsInTry() = True,    "Still inside try/catch after inner _EndTry", __IsInTry(), "True")
    _EndTry()                              ; decrements the outermost level - back to depth 0
    _TestFmkAssert(__GetDepthLevel() = 0, "Depth is 0 after outer _EndTry", __GetDepthLevel(), "0")
    _TestFmkAssert(__IsInTry() = False,   "Try/catch inactive after outer _EndTry", __IsInTry(), "False")
EndFunc

Func _TestExceptionCaptured()
    _TestFmkHeader("Test: Exception captured correctly")
    _Try()
        _FuncWithError("TestException")
    Local $e
    _Catch($e)
    _TestFmkAssert(__GetStackCount() = 1,                            "One entry captured",              __GetStackCount(),  "1")
    _TestFmkAssert($e.sException = "TestException",                  "Entry exception name is correct", $e.sException,      "TestException")
    _TestFmkAssert($e.sSource <> $UNDEFINED_SOURCE,                  "Function name captured",          $e.sSource,         "not " & $UNDEFINED_SOURCE)
    _TestFmkAssert(__IsTryCatchStackEntry($e.sSource),                "Entry type is TryCatch",          $e.sSource,         $DEFINED_ENTRY)
    _EndTry()
    _TestFmkAssert(__GetStackCount() = 0,                            "Stack count reset after _EndTry", __GetStackCount(),  "0")
EndFunc

Func _TestFunctionSkippedOnError()
    _TestFmkHeader("Test: Function skipped on error (_OnErrorResume)")
    Local $bExecuted = False
    _Try()
        _FuncWithError("TestException")
        _FuncRecordExecution($bExecuted)
    Local $e
    _Catch($e)
    _TestFmkAssert($bExecuted = False, "Function skipped after error", $bExecuted, "False")
    _EndTry()
EndFunc

Func _TestFunctionExecutedWithoutError()
    _TestFmkHeader("Test: Function executes without error")
    Local $bExecuted = False
    _Try()
        _FuncNoError()
        _FuncRecordExecution($bExecuted)
    Local $e
    _Catch($e)
    _TestFmkAssert($bExecuted = True, "Function executed when no error", $bExecuted, "True")
    _EndTry()
EndFunc

Func _TestNoErr()
    _TestFmkHeader("Test: _NoErr is the inverse of _OnErrorResume")
    _Try()
        _TestFmkAssert(_NoErr() = True, "_NoErr is True before any error", _NoErr(), "True")
        _FuncWithError("TestException")
        _TestFmkAssert(_NoErr() = False, "_NoErr is False after an error", _NoErr(), "False")
    Local $e
    _Catch($e)
    _EndTry()
EndFunc

Func _TestExternalExceptionViaTryWith()
    _TestFmkHeader("Test: External exception captured via _TryWith")
    _Try()
        _TryWith(_ArraySort(0))
    Local $e
    _Catch($e)
    _TestFmkAssert(__GetStackCount() = 1,               "One entry captured",                __GetStackCount(), "1")
    _TestFmkAssert($e.sException = $EXCEPTION_ROOT,     "Entry exception is root exception", $e.sException,     $EXCEPTION_ROOT)
    _TestFmkAssert(__IsExternalStackEntry($e.sSource),  "Entry type is External",            $e.sSource,        $UNDEFINED_SOURCE)
    _TestFmkAssert($e.sSource = $UNDEFINED_SOURCE,      "Source is UNDEFINED for external",  $e.sSource,        $UNDEFINED_SOURCE)
    _EndTry()
EndFunc

Func _TestTryWithAlwaysRuns()
    _TestFmkHeader("Test: _TryWith always runs regardless of previous errors")
    _Try()
        _FuncWithError("TestException")
        _TryWith(_ArraySort(0)) ; should still run and add a 2nd entry, even though an error already exists
    _TestFmkAssert(__GetScopeStackCount() = 2, "_TryWith ran despite previous error", __GetScopeStackCount(), "2")
    Local $e
    _Catch($e)
    _EndTry()
EndFunc

Func _TestTryWithGuardedByNoErr()
    _TestFmkHeader("Test: _TryWith wrapped with _NoErr behaves like a compatible function")
    _Try()
        _FuncWithError("TestException")
        _TryWith(_NoErr() ? _ArraySort(0) : Null) ; should be skipped since an error already exists
    _TestFmkAssert(__GetScopeStackCount() = 1, "_TryWith guarded by _NoErr did not run", __GetScopeStackCount(), "1")
    Local $e
    _Catch($e)
    _EndTry()
EndFunc

Func _TestCatchSingleMatchPerScope()
    _TestFmkHeader("Test: _Catch can only match once per try block scope")
    _Try()
        _FuncWithError("TestException")
    Local $e
    Local $bFirst  = _Catch($e)
    Local $bSecond = _Catch($e) ; same scope already catched - must return False
    _TestFmkAssert($bFirst = True,   "First _Catch in scope returns True",                  $bFirst,  "True")
    _TestFmkAssert($bSecond = False, "Second _Catch in same scope returns False",           $bSecond, "False")
    _TestFmkAssert(__IsCatched(),    "Scope is marked as catched after a successful catch", __IsCatched(), "True")
    _EndTry()
    _TestFmkAssert(__IsCatched() = False, "Catched state reset after _EndTry", __IsCatched(), "False")
EndFunc

Func _TestCatchTypeMatchingChain()
    _TestFmkHeader("Test: _Catch If/ElseIf chain matches by type, only first match wins")
    _Try()
        _FuncWithError("TestChildException")
    Local $e
    Local $sWhichBranch = ""
    If _Catch($e, _AsExceptionType("OtherException")) Then
        $sWhichBranch = "OtherException"
    ElseIf _Catch($e, _AsExceptionType("TestChildException")) Then
        $sWhichBranch = "TestChildException"
    ElseIf _Catch($e, _AsExceptionType("TestException")) Then
        $sWhichBranch = "TestException" ; TestChildException extends TestException - would also match, but should never run
    ElseIf _Catch($e) Then
        $sWhichBranch = "RootCatchAll"
    EndIf
    _TestFmkAssert($sWhichBranch = "TestChildException", "Most specific matching branch wins", $sWhichBranch, "TestChildException")
    _TestFmkAssert($e.sException = "TestChildException",  "$e holds the matched entry",         $e.sException, "TestChildException")
    _EndTry()
EndFunc

Func _TestCatchHierarchyMatch()
    _TestFmkHeader("Test: _Catch matches via exception hierarchy (_IsExceptionOf)")
    _Try()
        _FuncWithError("TestChildException")
    Local $e
    Local $bMatched = _Catch($e, _AsExceptionType("TestException")) ; parent type, should still match the child exception
    _TestFmkAssert($bMatched = True,                "Catching parent type matches a thrown child exception", $bMatched,      "True")
    _TestFmkAssert($e.sException = "TestChildException", "$e holds the actual thrown exception",              $e.sException,  "TestChildException")
    _EndTry()
EndFunc

Func _TestCatchNoMatchFallsThrough()
    _TestFmkHeader("Test: _Catch returns False and leaves scope uncatched when nothing matches")
    _Try()
        _FuncWithError("TestException")
    Local $e
    Local $bMatched = _Catch($e, _AsExceptionType("OtherException")) ; unrelated branch - should not match
    _TestFmkAssert($bMatched = False,     "No match returns False",                     $bMatched,     "False")
    _TestFmkAssert(__IsCatched() = False, "Scope remains uncatched after a non-match",  __IsCatched(), "False")
    _Catch($e) ; catch-all should still be able to match afterwards
    _TestFmkAssert(__IsCatched() = True,  "Scope becomes catched once a real match occurs", __IsCatched(), "True")
    _EndTry()
EndFunc

Func _TestCatchLatestEntryWins()
    _TestFmkHeader("Test: _Catch returns the LATEST matching entry, not the first")
    _Try()
        _ThrowException($EXCEPTION_ROOT, "First entry - should NOT be returned") ; 1st entry - root
        _TryWith(_ArraySort(0))                                                  ; 2nd entry - root, registered default message
    Local $e
    _Catch($e, _AsExceptionType($EXCEPTION_ROOT))
    _TestFmkAssert(__GetScopeStackCount() = 2, "Two entries exist in scope", __GetScopeStackCount(), "2")
    _TestFmkAssert($e.sMessage <> "First entry - should NOT be returned", "Latest entry is returned, not the first", $e.sMessage, "<> First entry - should NOT be returned")
    _TestFmkAssert($e.sMessage = _GetExceptionMessage($EXCEPTION_ROOT),  "Returned entry matches the 2nd (latest) thrown exception", $e.sMessage, _GetExceptionMessage($EXCEPTION_ROOT))
    _EndTry()
EndFunc

Func _TestNestedTryCatch()
    _TestFmkHeader("Test: Nested try/catch - inner sees only its own scope, outer sees all")
    _Try()
        _FuncWithError("TestException")
        Local $eInner
        _Try()
            _TryWith(_ArraySort(0))
        _Catch($eInner)
        _TestFmkAssert(__GetScopeStackCount() = 1, "Inner scope has 1 entry", __GetScopeStackCount(), "1")
        _EndTry()
    Local $eOuter
    _Catch($eOuter)
    _TestFmkAssert(__GetScopeStackCount() = 2,        "Outer scope has 2 entries (its own + inner's)", __GetScopeStackCount(), "2")
    _TestFmkAssert($eOuter.sException = $EXCEPTION_ROOT, "Outer catch matched the LATEST entry (inner's)", $eOuter.sException, $EXCEPTION_ROOT)
    _EndTry()
    _TestFmkAssert(__IsInTry() = False,   "Try/catch inactive after all EndTry", __IsInTry(),       "False")
    _TestFmkAssert(__GetDepthLevel() = 0, "Depth is 0 after all EndTry",         __GetDepthLevel(), "0")
EndFunc

Func _TestOuterCatchNotBlockedByInnerCatch()
    _TestFmkHeader("Test: Outer _Catch is not blocked by an inner _Catch succeeding")
    _Try()
        _FuncWithError("TestException")
        Local $eInner
        _Try()
            _TryWith(_ArraySort(0))
        _Catch($eInner) ; inner scope catched here
        _EndTry()
    Local $eOuter
    Local $bOuterMatched = _Catch($eOuter) ; outer scope is a DIFFERENT depth - must still be able to match
    _TestFmkAssert($bOuterMatched = True, "Outer catch still succeeds despite inner catch having matched", $bOuterMatched, "True")
    _EndTry()
EndFunc

Func _TestCatchInsideAnotherCatchReaction()
    _TestFmkHeader("Test: A new _Try/_Catch can run inside a _Catch's reaction block")
    _Try()
        _FuncWithError("TestException")
    Local $eOuter
    Local $sInnerException = ""
    If _Catch($eOuter) Then
        _Try()
            _TryWith(_ArraySort(0))
        Local $eInner
        _Catch($eInner)
        $sInnerException = $eInner.sException
        _EndTry()
    EndIf
    _EndTry()
    _TestFmkAssert($sInnerException = $EXCEPTION_ROOT, "Inner try/catch started inside outer catch reaction works correctly", $sInnerException, $EXCEPTION_ROOT)
    _TestFmkAssert(__IsInTry() = False,   "Try/catch inactive after all EndTry", __IsInTry(),       "False")
    _TestFmkAssert(__GetDepthLevel() = 0, "Depth is 0 after all EndTry",         __GetDepthLevel(), "0")
EndFunc

Func _TestForceReset()
    _TestFmkHeader("Test: _EndTry(\$FORCE_RESET) cleans up a deliberately unclosed nested _Try()")
    _Try()
        _Try() ; inner deliberately left unclosed - only $FORCE_RESET should be able to recover from this
    Local $e
    _Catch($e)
    _EndTry($FORCE_RESET)
    _TestFmkAssert(__IsInTry() = False,    "Try/catch inactive after force reset",  __IsInTry(),       "False")
    _TestFmkAssert(__GetDepthLevel() = 0,  "Depth is 0 after force reset",          __GetDepthLevel(), "0")
    _TestFmkAssert(__GetStackCount() = 0,  "Stack count is 0 after force reset",    __GetStackCount(), "0")
    _TestFmkAssert(__IsCatched() = False,  "Catched state reset after force reset", __IsCatched(),     "False")
EndFunc

Func _TestStackEntrySourceAndType()
    _TestFmkHeader("Test: Stack entry source and type")
    _Try()
        _FuncWithError("TestException")
        _TryWith(_ArraySort(0))
    _TestFmkAssert(__GetStackEntry(0).sSource <> $UNDEFINED_SOURCE, "TryCatch entry has function name as source", __GetStackEntry(0).sSource, "not " & $UNDEFINED_SOURCE)
    _TestFmkAssert(__GetStackEntry(1).sSource = $UNDEFINED_SOURCE,  "External entry has UNDEFINED as source",     __GetStackEntry(1).sSource, $UNDEFINED_SOURCE)
    _TestFmkAssert(__StackEntryType(__GetStackEntry(0).sSource) = $DEFINED_ENTRY,   "TryCatch entry type is $DEFINED_ENTRY",   __StackEntryType(__GetStackEntry(0).sSource), $DEFINED_ENTRY)
    _TestFmkAssert(__StackEntryType(__GetStackEntry(1).sSource) = $UNDEFINED_ENTRY, "External entry type is $UNDEFINED_ENTRY", __StackEntryType(__GetStackEntry(1).sSource), $UNDEFINED_ENTRY)
    _TestFmkAssert(__IsTryCatchStackEntry(__GetStackEntry(0).sSource), "IsTryCatchStackEntry returns True for TryCatch", __IsTryCatchStackEntry(__GetStackEntry(0).sSource), "True")
    _TestFmkAssert(__IsExternalStackEntry(__GetStackEntry(1).sSource), "IsExternalStackEntry returns True for external", __IsExternalStackEntry(__GetStackEntry(1).sSource), "True")
    Local $e
    _Catch($e)
    _EndTry()
EndFunc

Func _TestExceptionMessage()
    _TestFmkHeader("Test: Exception message - default and override")
    _Try()
        _FuncWithError("TestException")
    Local $e
    _Catch($e)
    _TestFmkAssert($e.sMessage = "A test exception occurred", "Entry uses registered default message", $e.sMessage, "A test exception occurred")
    _EndTry()

    _Try()
        _FuncWithError("TestException", "Custom override message")
    Local $e2
    _Catch($e2)
    _TestFmkAssert($e2.sMessage = "Custom override message", "Entry uses overridden message", $e2.sMessage, "Custom override message")
    _EndTry()
EndFunc

Func _TestThrowExceptionAutoRegisters()
    _TestFmkHeader("Test: _ThrowException auto-registers an unregistered exception name")
    _TestFmkAssert(_IsExceptionExists("AutoRegisteredException") = False, "Exception not registered before throw", _IsExceptionExists("AutoRegisteredException"), "False")
    _Try()
        _FuncWithError("AutoRegisteredException")
    Local $e
    _Catch($e)
    _TestFmkAssert(_IsExceptionExists("AutoRegisteredException") = True, "Exception auto-registered after throw", _IsExceptionExists("AutoRegisteredException"), "True")
    _TestFmkAssert($e.sException = "AutoRegisteredException",            "Thrown entry uses the auto-registered name", $e.sException, "AutoRegisteredException")
    _EndTry()
EndFunc

Func _TestThrowExceptionOutsideTry()
    _TestFmkHeader("Test: _ThrowException outside a try block")
    Local $iResult = _ThrowException("TestException")
    _TestFmkAssert($iResult = 0, "Returns 0 when not inside a try block", $iResult, "0")
EndFunc

Func _TestScopeStackCount()
    _TestFmkHeader("Test: Scope stack count - isolated per nesting level")
    _Try()
        _FuncWithError("TestException")
        _Try()
            _TryWith(_ArraySort(0))
            _TryWith(_ArraySort(0))
        Local $e
        _Catch($e)
        _TestFmkAssert(__GetScopeStackCount() = 2, "Inner scope has 2 entries", __GetScopeStackCount(), "2")
        _EndTry()
    Local $e2
    _Catch($e2)
    _TestFmkAssert(__GetScopeStackCount() = 3, "Outer scope has 3 entries", __GetScopeStackCount(), "3")
    _EndTry()
EndFunc

Func _TestStackTraceReturnsEntries()
    _TestFmkHeader("Test: _StackTrace returns raw scope entries with no handler")
    _Try()
        _FuncWithError("TestException")
        _TryWith(_ArraySort(0))
    Local $mEntries = _StackTrace()
    _TestFmkAssert(UBound($mEntries) = 2, "_StackTrace returns all entries in scope", UBound($mEntries), "2")
    Local $e
    _Catch($e)
    _EndTry()
EndFunc

Func _TestStackTraceWithHandler()
    _TestFmkHeader("Test: _StackTrace returns the handler's result when one is provided")
    _Try()
        _FuncWithError("TestException")
    Local $sReport = _StackTrace(_FormatStackTrace)
    _TestFmkAssert(StringInStr($sReport, "TestException") > 0, "Report contains the exception name", $sReport, "contains TestException")
    _TestFmkAssert(StringInStr($sReport, "A test exception occurred") > 0, "Report contains the exception message", $sReport, "contains message")
    Local $e
    _Catch($e)
    _EndTry()
EndFunc

Func _TestStackTraceInvalidHandlerDoesNotCrash()
    _TestFmkHeader("Test: _StackTrace does not crash on a handler with the wrong signature")
    _Try()
        _FuncWithError("TestException")
    Local $vResult = _StackTrace(_FuncNoError) ; wrong arity on purpose - _FuncNoError takes 0 params
    Local $iError  = @error ; capture immediately - @error resets on the next function call
    _TestFmkAssert($vResult = False, "Returns False for an incompatible handler",    $vResult, "False")
    _TestFmkAssert($iError = 0xDEAD, "@error is 0xDEAD for an incompatible handler", $iError,  "0xDEAD")
    Local $e
    _Catch($e)
    _EndTry()
EndFunc

Func _TestFormatStackTraceStandalone()
    _TestFmkHeader("Test: _FormatStackTrace works standalone with default $iCount")
    _Try()
        _FuncWithError("TestChildException")
    Local $sReport = _FormatStackTrace(_StackTrace())
    _TestFmkAssert(StringInStr($sReport, "TestChildException") > 0, "Report contains the exception name", $sReport, "contains TestChildException")
    _TestFmkAssert(StringInStr($sReport, "caused by") > 0,          "Report contains the ancestor chain",  $sReport, "contains 'caused by'")
    Local $e
    _Catch($e)
    _EndTry()
EndFunc

Func _TestAsExceptionTypeSingleString()
    _TestFmkHeader("Test: _AsExceptionType normalizes a single string into a 1-element array")
    Local $aType = _AsExceptionType("TestException")
    _TestFmkAssert(IsArray($aType) = True, "Returns an array", IsArray($aType), "True")
    _TestFmkAssert(UBound($aType) = 1,     "Array has exactly 1 element", UBound($aType), "1")
    _TestFmkAssert($aType[0] = "TestException", "Element matches the input string", $aType[0], "TestException")
EndFunc

Func _TestAsExceptionTypeCommaList()
    _TestFmkHeader("Test: _AsExceptionType normalizes a comma-separated list into a multi-element array")
    Local $aType = _AsExceptionType("AlphaException,BetaException")
    _TestFmkAssert(IsArray($aType) = True, "Returns an array",            IsArray($aType), "True")
    _TestFmkAssert(UBound($aType) = 2,     "Array has exactly 2 elements", UBound($aType), "2")
    _TestFmkAssert($aType[0] = "AlphaException", "First element is correct", $aType[0], "AlphaException")
    _TestFmkAssert($aType[1] = "BetaException",  "Second element is correct", $aType[1], "BetaException")
EndFunc

Func _TestAsExceptionTypeArrayPassthrough()
    _TestFmkHeader("Test: _AsExceptionType passes an already-built array through coerced to strings")
    Local $aInput[2] = ["AlphaException", "BetaException"]
    Local $aType = _AsExceptionType($aInput)
    _TestFmkAssert(IsArray($aType) = True, "Returns an array",             IsArray($aType), "True")
    _TestFmkAssert(UBound($aType) = 2,     "Array still has 2 elements",   UBound($aType), "2")
    _TestFmkAssert($aType[0] = "AlphaException", "First element unchanged", $aType[0], "AlphaException")
    _TestFmkAssert($aType[1] = "BetaException",  "Second element unchanged", $aType[1], "BetaException")
EndFunc

Func _TestCatchBareStringStillWorks()
    _TestFmkHeader("Test: _Catch accepts a bare string type without _AsExceptionType wrapping")
    _Try()
        _FuncWithError("TestException")
    Local $e
    Local $bMatched = _Catch($e, "TestException") ; bare string, not wrapped in _AsExceptionType
    _TestFmkAssert($bMatched = True,             "Bare string type matches correctly", $bMatched,      "True")
    _TestFmkAssert($e.sException = "TestException", "$e holds the matched entry",      $e.sException,  "TestException")
    _EndTry()
EndFunc

Func _TestCatchMultiTypeListOrderBeatsRecency()
    _TestFmkHeader("Test: _Catch with a multi-type list checks list order before recency")
    _Try()
        ; Use _ThrowException() directly (not _FuncWithError) - both throws must happen
        ; unconditionally, regardless of _OnErrorResume(), to actually populate 2 entries.
        _ThrowException("BetaException")  ; older entry - 2nd listed type
        _ThrowException("AlphaException") ; newer entry - 1st listed type
    Local $e
    ; Both types are present; AlphaException is listed first AND is also the most recent entry here,
    ; so this alone wouldn't distinguish "list order" from "recency" as the deciding factor.
    _Catch($e, _AsExceptionType("AlphaException,BetaException"))
    _TestFmkAssert($e.sException = "AlphaException", "First-listed type matches when present", $e.sException, "AlphaException")
    _EndTry()

    ; Now invert: make BetaException (2nd listed) the newer entry, AlphaException (1st listed) the older one.
    ; If list order truly wins over recency, AlphaException (older, but listed first) should still be returned.
    _Try()
        _ThrowException("AlphaException") ; older entry - 1st listed type
        _ThrowException("BetaException")  ; newer entry - 2nd listed type
    Local $e2
    _Catch($e2, _AsExceptionType("AlphaException,BetaException"))
    _TestFmkAssert($e2.sException = "AlphaException", "List order wins even when the 1st-listed type's entry is older than the 2nd-listed type's entry", $e2.sException, "AlphaException")
    _EndTry()
EndFunc

; ===============================================================================================================================
; Run all tests
; ===============================================================================================================================

Func _RunAllTests()
    Local $bAllPassed = True
    $bAllPassed = _TestFmkRun(_TestInitialState,                       $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestTryActivates,                       $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestEndTryDecrementsOneLevel,           $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestExceptionCaptured,                  $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestFunctionSkippedOnError,             $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestFunctionExecutedWithoutError,       $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestNoErr,                              $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestExternalExceptionViaTryWith,        $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestTryWithAlwaysRuns,                  $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestTryWithGuardedByNoErr,              $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestCatchSingleMatchPerScope,           $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestCatchTypeMatchingChain,             $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestCatchHierarchyMatch,                $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestCatchNoMatchFallsThrough,           $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestCatchLatestEntryWins,               $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestNestedTryCatch,                     $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestOuterCatchNotBlockedByInnerCatch,   $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestCatchInsideAnotherCatchReaction,    $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestForceReset,                         $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestStackEntrySourceAndType,            $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestExceptionMessage,                   $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestThrowExceptionAutoRegisters,        $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestThrowExceptionOutsideTry,           $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestScopeStackCount,                    $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestStackTraceReturnsEntries,           $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestStackTraceWithHandler,              $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestStackTraceInvalidHandlerDoesNotCrash, $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestFormatStackTraceStandalone,         $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestAsExceptionTypeSingleString,        $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestAsExceptionTypeCommaList,           $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestAsExceptionTypeArrayPassthrough,    $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestCatchBareStringStillWorks,          $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestCatchMultiTypeListOrderBeatsRecency, $bAllPassed)
    _TestFmkSummary()
    Return $bAllPassed
EndFunc

_RunAllTests()
