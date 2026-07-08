; #INDEX# =======================================================================================================================
; Title .........: AutoIt TryCatch - TryCatch.au3 library
; Version .......: 0.0.1
; AutoIt Version : 3.3.18.0
; Author ........: Crucial Thread
; Description ...: A try/catch pattern implementation for AutoIt.
;                  Provides _Try, _Catch, _EndTry, _OnErrorResume, _NoErr, _ThrowException, _TryWith,
;                  _StackTrace and _FormatStackTrace to enable try/catch error handling in AutoIt.
; Dependencies ..: Exception.au3
; Usage .........: #include "TryCatch.au3"
;
;                  ////////////////////////////////////////////////////////////////////////////////////
;
;                  ; *** 1. General Try block usage:
;                  _Try()
;                      ; Functions under Try/Catch block
;                      ; _Catch() block
;                  _EndTry()
;
;                  ////////////////////////////////////////////////////////////////////////////////////
;
;                  ; *** 2. Nested Try block usage:
;                  _Try()
;                      ; Functions under Try/Catch block
;                      ; >>> Including functions that uses Try/Catch block inside itself
;
;                      ;-- ### Nested Try/Catch block
;                      _Try()
;                      		; Functions under Try/Catch block
;                      		; _Catch() block - >>> exceptions scoped to this inner Try/Catch block
;                      _EndTry()	; >>> closes this nested Try/Catch block
;
;                      ;-- ### Can be used even inside _Catch()
;                      If _Catch($e) Then
;                          _Try()
;                          		; Functions under Try/Catch block
;                          		; _Catch() block
;                          _EndTry()
;                      EndIf
;                  _EndTry()
;
;                  ////////////////////////////////////////////////////////////////////////////////////
;
;                  ; *** 3. Early Return:
;                  ;     >>> Do not left Try blocks open <<<
;                  _Try()
;
;                      ; Functions under Try/Catch block
;
;                      ;-- ### Never Return from a _Try() without an _EndTry()
;                      Return _EndTry()
;
;                      ;-- ### Use _EndTry() right before Return if need to return something
;                      _EndTry()
;                      Return "Something"
;
;                      ; _Catch() block
;
;                  _EndTry()	;if returned early it will never be executed
;
;                  ////////////////////////////////////////////////////////////////////////////////////
;
;                  ; *** 4. Compatible TryBlock Function:
;                  ;     Return under any previous exception in stack, and throw exception under errors
;                  ;     >>> PREFERRED METHOD TO RUN FUNCTIONS WITHIN TRY/CATCH BLOCK <<<
;
;                  Func _MyCompatibleFunc()
;                      If _OnErrorResume() Then Return SetError(__GetStackCount(), 0, False)
;                      ; whatever you want
;                      Return SetError(_ThrowException("MyException", "MyMessage", _MyCompatibleFunc), 0, False)
;                  _EndFunc
;
;                  ////////////////////////////////////////////////////////////////////////////////////
;
;                  ; *** 5. Try block with function and/or instructions calls:
;                  _Try()
;
;                      ;-- ### Compatible TryCatch function (PREFERABLE, see 4 above)
;                      _MyCompatibleFunc()
;
;                      ;-- ### Non compatible function with regular _TryWith usage
;                      ;       run even if any previous function has thrown an error
;                      ;       But thrown a generic exception if any error for the function
;                      _TryWith(_AnyFunc($param))
;
;                      ;-- ### Non compatible function wrapped with _OnErr(), works similar to a TryCatch function
;                      ;       Do not run if any previous exception,
;                      ;       and thrown a generic exception if any error for the function
;                      _TryWith(_OnErr()? _AnotherFunc($param) : Null)
;
;                      ; _Catch() block
;
;                  _EndTry()
;
;                  ////////////////////////////////////////////////////////////////////////////////////
;
;                  ; *** 6. Try block with instructions calls wrapped:
;                  ;     >>> VALID BUT DISCOURAGED <<<
;                  ; 	 It is recommended to create a compatible TryCatch function instead (see 4 above)
;                  _Try()
;
;                      _AnyFunction()
;                      ...
;
;                      ;-- ### Compatible TryCatch wrapped instructions
;                      ;       Do not run the block if any previous exception was thrown,
;                      ;       and thrown custom excepions as needed
;
;                      If Not _OnErrorResume() Then
;                      		; Any call
;                      		...
;                      		_SomeFunctionCall($sParam)
;                      		If @error Then _ThrowException("SomeCallException", Default, _SomeFunctionCall)
;                      		...
;                      		_AnotherFunctionCall($vParam)
;                      		If @error Then _ThrowException("AnotherException", Default, _AnotherFunctionCall)
;                      		...
;                      		; Instructions
;                      		If @error Then _ThrowException("CustomException")
;                      EndIf
;
;                      ...
;                      _MoreFunction()
;
;                      ; _Catch() block
;
;                  _EndTry()
;
;                  ////////////////////////////////////////////////////////////////////////////////////
;
;                  ; *** 7. Catch block usage:
;                  _Try()
;
;                      ; Functions under Try/Catch block
;
;                      ;-- ### Exception return from _Catch match
;                      ;       $e.sException, $e.sMessage, $e.sSource
;                      Local $e
;
;                      ;-- Match only once under scope
;
;                      If _Catch($e, _AsExceptionType("SomeException")) Then
;                          ; reacts to this "SomeException" catch
;                      ElseIf _Catch($e, _AsExceptionType("AnotherException")) Then
;                          ; reacts to this "AnotherException" catch
;                      ElseIf _Catch($e) Then
;                          ; catch any exception, short for _Catch($e, $EXCEPTION_ROOT)
;                      EndIf
;
;                  _EndTry()
;
;                  ////////////////////////////////////////////////////////////////////////////////////
;
;                  ; *** 8. Catch block usage matching multiple types in a single call:
;				   ;
;                  ; --- _Catch($e, _AsExceptionType("FirstType,SecondType")) behaves the same as
;                  ;     If _Catch($e, _AsExceptionType("FirstType")) Then ... ElseIf _Catch($e, _AsExceptionType("SecondType")) Then ...
;				   ;
;                  ; --- Within the listed types, list order is checked first, exception recency second:
;                  ;     all possible matches for "FirstType" are checked (latest exceptions entry first) before
;                  ;     "SecondType" is ever considered, even if a "SecondType" entry is more recent overall
;                  _Try()
;
;                      ; Functions under Try/Catch block
;                      Local $e
;
;                      If _Catch($e, _AsExceptionType("FirstType,SecondType")) Then
;                          ; reacts to either "FirstType" or "SecondType" with the same logic
;                          ; if an exception is found as "FirstType" do not check "SecondType"
;                          ; the entrance order matters, it is not sorted anyhow
;                      ElseIf _Catch($e, _AsExceptionType("AnotherException")) Then
;                          ; reacts to this "AnotherException" catch
;                      ElseIf _Catch($e) Then
;                          ; catch any other exception
;                      EndIf
;
;                  _EndTry()
;
;                  ////////////////////////////////////////////////////////////////////////////////////
;
; **** NOTES ****:
;
;       - >>>>>> Do not left Try blocks open, _Try() must always be closed with _EndTry() <<<<
;       - The regular _EndTry() is preferred and should be good enough for all situations
;       - But optionally (>>>WITH CAUTION AND ONLY IF REALLY NECESSARY<<<) use _EndTry($FORCE_RESET), usually for outermost try block, to ensure full reset
;       - WARNING: _EndTry($FORCE_RESET) can mess up everything if used uncarefully
;       - Nested try blocks are supported - inner errors propagate to outer
;
;       - _Catch() does not close the try block - _EndTry() must be called explicitly
;       - _Catch() can only catch once per try block scope - subsequent calls return False
;       - Use If/ElseIf chains of _Catch() calls to test multiple exception types - only the first match wins
;       - _Catch() also accepts a comma-separated list of types via _AsExceptionType() to match several types in one call
;       - Comma-separated list of types for _Catch() behaves the same as splitting them across an If/ElseIf chain, one type per branch, in the same order
;       - Error Scope: Inner _Catch sees only its scope exceptions, outer _Catch sees all exceptions
;
;       - Compatible TryCatch functions must use _OnErrorResume() and _ThrowException()
;       - _OnErrorResume() enable compatible TryCatch functions not to run if any previous function has thrown an error
;       - _ThrowException() is used to record a registered exception on the stack and also returns the error code for inline use with SetError()
;       - _ThrowException() will try to auto-register the exception if it isn't already registered, falling back to $EXCEPTION_ROOT if not possible
;       - This _ThrowException() auto-register provide convenience to avoid having to explicitly register an exception before use, but typo carefulness is advised
;
;       - Functions not compatible with TryCatch can be wrapped with _TryWith() to capture their errors
;       - Any function called using _TryWith() will thrown a generic exception under errors
;       - _NoErr() is the inverse of _OnErrorResume() - useful for guarding a single non-compatible call with _TryWith()
;       - _TryWith(_AnyFunction()) syntax always runs non compatible functions regardless of previous errors
;       - _TryWith(_NoErr()? _AnyFunction() : Null) wrapped with _NoErr() make the function not run if any previous function has thrown an error
;
;       - _StackTrace() and _FormatStackTrace() are utilities to inspect/log the current scope's exceptions
;		- Custom functions with signature "Func _CustomFunc($mEntries, $iCount)" can be created and passed as a param to _StackTrace(_CustomFunc)
;		- _FormatStackTrace() can be used as a reference for how to create custom functions to pass to _StackTrace()
;
; ===============================================================================================================================

#include-once
#include <Array.au3>
#include "Exception.au3"

; ===============================================================================================================================
; Constants and Enums
; ===============================================================================================================================

; Depth level delta enum - used by __SetDepthLevel to enter or leave a try block
Global Enum $DEPTH_ENTER = 1, $DEPTH_LEAVE = -1

; Try block status enum - used by __SetTry to initialize or end a try block
Global Enum $INIT_TRY = True, $END_TRY = False

; The outermost try block depth level
Global Const $ROOT_TRYBLOCK = 1

; Placeholder source name for exceptions from non compatible TryCatch functions via _TryWith
Global Const $UNDEFINED_SOURCE = "UNDEFINED"

; Force reset constant for _EndTry - pass to force full reset regardless of nesting depth
Global Const $FORCE_RESET = True

; Stack entry type enum
; $DEFINED_ENTRY   - entry from a function built with this TryCatch pattern with a valid caller
; $UNDEFINED_ENTRY - entry from a non compatible function via _TryWith or invalid caller
Global Enum $DEFINED_ENTRY = 1, $UNDEFINED_ENTRY = 2

; ===============================================================================================================================
; State - single map holding all try/catch state
; ===============================================================================================================================

Global $__g_mTryCatch[]

; Initialize the try/catch state map - called automatically on include
Func __TryCatchInit()
    Local $oEmpty[]
    $__g_mTryCatch.bInTry      = False    ; whether we are inside an active try block
    $__g_mTryCatch.iDepth      = 0        ; current try block depth level (1 = outermost, 2 = first nested, etc.)
    $__g_mTryCatch.iStackCount = 0        ; total number of entries recorded in the exception stack
    $__g_mTryCatch.mStack      = $oEmpty  ; map storing all recorded stack entries across all nesting levels
    $__g_mTryCatch.mOffsets    = $oEmpty  ; maps depth level to the base stack index of its try block scope
    $__g_mTryCatch.mCatched    = $oEmpty  ; maps depth level to whether _Catch has succeeded for that scope
EndFunc

__TryCatchInit()

; ===============================================================================================================================
; Internal helpers - try/catch state accessors
; ===============================================================================================================================

; Returns the current bInTry flag value
Func __GetInTry()
    Return $__g_mTryCatch.bInTry
EndFunc

; Sets the bInTry flag - True when inside an active try block
Func __SetInTry($bTry = True)
    $__g_mTryCatch.bInTry = $bTry
EndFunc

; Returns True if currently inside an active try block
Func __IsInTry()
    Return __GetInTry() = True
EndFunc

; Returns the current try block nesting depth
Func __GetDepthLevel()
    Return $__g_mTryCatch.iDepth
EndFunc

; Function reference alias for __GetDepthLevel - used for readability
Global Const $CURRENT_DEPTH = __GetDepthLevel

; Returns True if the current depth is 0 - meaning no active try block
Func __IsFloorDepth()
	Return __GetDepthLevel() = 0
EndFunc

; Resets the nesting depth to 0
Func __ResetDepthLevel()
    $__g_mTryCatch.iDepth = 0
EndFunc

; Adjusts the nesting depth by $iDelta - use $DEPTH_ENTER or $DEPTH_LEAVE
; Depth is floored at 0 to prevent negative values
Func __SetDepthLevel($iDelta = $DEPTH_ENTER)
    $__g_mTryCatch.iDepth += $iDelta
	If __IsFloorDepth() Then __ResetDepthLevel()
EndFunc

; Returns True if the current depth is the outermost try block
Func __IsRootTryBlock()
    Return __GetDepthLevel() == $ROOT_TRYBLOCK
EndFunc

; Returns the total number of entries recorded across all nesting levels
Func __GetStackCount()
    Return $__g_mTryCatch.iStackCount
EndFunc

; Function reference alias for __GetStackCount - used for readability
Global Const $STACK_INDEX = __GetStackCount

; Returns True if there are any entries recorded in the exception stack
Func __HasStackEntry()
    Return __GetStackCount() > 0
EndFunc

; Returns the number of entries recorded within the current try block scope
Func __GetScopeStackCount()
    Local $iScopeStart = __GetScopeOffset($CURRENT_DEPTH())
    Return __GetStackCount() - $iScopeStart
EndFunc

; Returns True if there are any entries recorded within the current try block scope
Func __HasScopeStackEntry()
    Return __GetScopeStackCount() > 0
EndFunc

; Sets the total stack count to $iStackCount
Func __SetStackCount($iStackCount = 0)
    $__g_mTryCatch.iStackCount = $iStackCount
EndFunc

; Resets the total stack count to 0
Func __ResetStackCount()
    __SetStackCount(0)
EndFunc

; Increases the total stack count by 1
Func __IncreaseStackCount()
    __SetStackCount(__GetStackCount() + 1)
EndFunc

; ===============================================================================================================================
; Internal helpers - offset stack accessors
; ===============================================================================================================================

; Records the base stack index for the given depth level
; $iDepth      - depth level to record the offset for (default: current depth)
; $iStackIndex - base stack index to record (default: current stack count)
Func __OffsetsPush($iDepth = $CURRENT_DEPTH(), $iStackIndex = $STACK_INDEX())
    $__g_mTryCatch["mOffsets"][$iDepth] = $iStackIndex
EndFunc

; Returns the base stack index for the given depth level
; $iDepth - depth level to retrieve the offset for (default: current depth)
Func __GetScopeOffset($iDepth = $CURRENT_DEPTH())
    Return $__g_mTryCatch["mOffsets"][$iDepth]
EndFunc

; Resets the offset stack by setting the root try block offset to 0
Func __ResetOffsets()
    __OffsetsPush($ROOT_TRYBLOCK, 0)
EndFunc

; ===============================================================================================================================
; Internal helpers - exception stack accessors
; ===============================================================================================================================

; Resets the exception stack to an empty map
Func __ResetStack()
    Local $oEmpty[]
    $__g_mTryCatch.mStack = $oEmpty
EndFunc

; Initializes or ends the try/catch state
; $bStatus - $INIT_TRY to initialize, $END_TRY to end
Func __SetTry($bStatus = $INIT_TRY)
    __SetInTry($bStatus)
    __ResetStack()
    __ResetStackCount()
    __ResetOffsets()
    __ResetCatched()
EndFunc

; Returns the source string for the given caller
; $vCaller - function reference of the caller (Default for external exceptions)
; Returns: function name string or $UNDEFINED_SOURCE for external exceptions or invalid sources
Func __StackEntrySource($vCaller = Default)
    Return ($vCaller <> Default And IsFunc($vCaller)) ? FuncName($vCaller) : $UNDEFINED_SOURCE
EndFunc

; Factory function - creates a new stack entry map with consistent structure and type coercion
; $sException - registered exception name
; $sMessage   - resolved exception message
; $sSource    - source identifier - function name or $UNDEFINED_SOURCE for external exceptions
; Returns     : stack entry map
Func __StackEntryNew($sException, $sMessage, $sSource)
    Local $mEntry[]
    $mEntry.sException  = String($sException)
    $mEntry.sMessage    = String($sMessage)
    $mEntry.sSource     = String($sSource)
    Return $mEntry
EndFunc

; Pushes an entry onto the exception stack
; $sException - registered exception name
; $sMessage   - message override (Default = use registered exception message)
; $sSource    - source identifier - function name or $UNDEFINED_SOURCE for external exceptions
Func __StackPush($sException, $sMessage = Default, $sSource = Default)
    If Not _IsExceptionExists($sException) Then Return
    $__g_mTryCatch["mStack"][$STACK_INDEX()] = __StackEntryNew($sException, $sMessage, $sSource)
    __IncreaseStackCount()
EndFunc

; Returns the stack entry at the given index
; $iIndex - zero-based index of the entry to retrieve
Func __GetStackEntry($iIndex)
    Return $__g_mTryCatch["mStack"][$iIndex]
EndFunc

; Returns a map of stack entries recorded within the current try block scope
Func __GetStackEntriesInScope()
    Local $iStackIndexStart = __GetScopeOffset($CURRENT_DEPTH())
    Local $iStackIndexEnd   = __GetStackCount() - 1

    Local $mScopedEntries[]
    Local $iIdx = 0

    For $iStackIndex = $iStackIndexStart To $iStackIndexEnd
        $mScopedEntries[$iIdx] = __GetStackEntry($iStackIndex)
        $iIdx += 1
    Next

    Return $mScopedEntries
EndFunc

; ===============================================================================================================================
; Internal helpers - catched state accessors
; ===============================================================================================================================

; Returns True if _Catch has already succeeded at the given depth level
; $iDepth - depth level to check (default: current depth)
Func __IsCatched($iDepth = $CURRENT_DEPTH())
    Return MapExists($__g_mTryCatch["mCatched"], $iDepth)
EndFunc

; Marks the given depth level as catched
; $iDepth - depth level to mark (default: current depth)
Func __SetCatched($iDepth = $CURRENT_DEPTH())
    $__g_mTryCatch["mCatched"][$iDepth] = True
EndFunc

; Releases the caught state for the given depth level
; $iDepth - depth level to release (default: current depth)
Func __ReleaseCatch($iDepth = $CURRENT_DEPTH())
    MapRemove($__g_mTryCatch["mCatched"], $iDepth)
EndFunc

; Resets the catched state map to empty
Func __ResetCatched()
    Local $oEmpty[]
    $__g_mTryCatch.mCatched = $oEmpty
EndFunc

; ===============================================================================================================================
; Internal helpers - stack entry type
; ===============================================================================================================================

; Returns $DEFINED_ENTRY if $sSource is a known function name, $UNDEFINED_ENTRY otherwise
Func __StackEntryType($sSource)
    Return $sSource <> $UNDEFINED_SOURCE ? $DEFINED_ENTRY : $UNDEFINED_ENTRY
EndFunc

; Returns True if the stack entry originated from a function compatible with the try/catch pattern
Func __IsTryCatchStackEntry($sSource)
    Return __StackEntryType($sSource) = $DEFINED_ENTRY
EndFunc

; Returns True if the stack entry originated from a function called with _TryWith
Func __IsExternalStackEntry($sSource)
    Return __StackEntryType($sSource) = $UNDEFINED_ENTRY
EndFunc

; ===============================================================================================================================
; Internal helpers - catch matching
; ===============================================================================================================================

; Coerces every element of $aTypes to a string in place
; $aTypes - array of type names (returned unchanged if not an array)
; Returns : the same array with all elements coerced to string, or $aTypes unchanged if not an array
Func __TypeExceptionsToString($aTypes)
	If Not IsArray($aTypes) Then Return $aTypes

	For $i = 0 To UBound($aTypes) - 1
		$aTypes[$i] = String($aTypes[$i])
	Next

	Return $aTypes
EndFunc

; Normalizes $vTypes into an array of type name strings
; $vTypes - a single type name, a comma-separated list of type names, or an array of type names
; Returns : array of type name strings, in the same order as provided
Func __TypesToArray($vTypes)
	Local $aTypes = []

	If Not IsArray($vTypes) Then
		If Not IsString($vTypes) Then $vTypes = String($vTypes)
		$aTypes = _ArrayFromString($vTypes, ",")
	Else
		$aTypes = $vTypes
	EndIf

	$aTypes = __TypeExceptionsToString($aTypes)
	Return $aTypes
EndFunc

; Identity wrapper for exception type filters - improves readability at call sites
; $vException - exception name, comma-separated list of names, or array of names to use as a type filter (Default = $EXCEPTION_ROOT)
; Returns     : array of type name strings, suitable for use as $vType in _Catch()
; Usage.......: _Catch($e, _AsExceptionType("MyException"))
; Usage.......: _Catch($e, _AsExceptionType("FirstType,SecondType")) ; matches either type, list order then recency
Func _AsExceptionType($vException = $EXCEPTION_ROOT)
    Return __TypesToArray($vException)
EndFunc

; Returns the latest stack entry matching any type in $aTypeList, searching types in list order,
; and within each type, entries from most recent to oldest
; $mEntries   - map of stack entries to search
; $iCount     - number of entries in $mEntries
; $aTypeList  - array of exception type names to match against (using hierarchy via _IsExceptionOf)
; Returns     : matching stack entry map, or Default if no match found for any listed type
Func __FindLatestMatch($mEntries, $iCount, $aTypeList)
	For $sType In $aTypeList
		If Not _IsExceptionExists($sType) Then ContinueLoop
		For $i = $iCount - 1 To 0 Step -1
			If _IsExceptionOf($mEntries[$i].sException, $sType) Then Return $mEntries[$i]
		Next
	Next
	Return Default
EndFunc

; ===============================================================================================================================
; Public API
; ===============================================================================================================================

; Start a try block
; Supports nested try blocks - each _Try() must be paired with _EndTry()
Func _Try()
    __SetDepthLevel($DEPTH_ENTER)
    __OffsetsPush($CURRENT_DEPTH(), $STACK_INDEX())
    If __IsRootTryBlock() Then __SetTry($INIT_TRY)
EndFunc

; End a try block
; $bForceReset - ### USE WITH CAUTION ###
;				 pass $FORCE_RESET to force full reset regardless of nesting depth
;                usually used only for outermost try block to ensure clean state
Func _EndTry($bForceReset = False)
    __ReleaseCatch($CURRENT_DEPTH())
    __SetDepthLevel($DEPTH_LEAVE)

    If __IsFloorDepth() Or $bForceReset Then
        __ResetDepthLevel()
        __SetTry($END_TRY)
    EndIf
EndFunc

; Throw an exception - records it in the try/catch stack
; $sName    - exception name - auto-registered if not existent falling back to $EXCEPTION_ROOT if not possible to auto-register
; $sMessage - message override (Default = use registered exception message)
; $sCaller  - function reference of the caller (Default for external exceptions)
; Returns   : exception error code for inline use with SetError()
; Note......: If $sName is not a registered exception it is registered on the fly (no message, parent = $EXCEPTION_ROOT)
;             falls back to $EXCEPTION_ROOT itself only if that auto-registration somehow fails
; Note......: Auto register provide convenience to avoid having to explicitly register an exception before use, but typo carefulness is advised
; Usage.....: Return SetError(_ThrowException("DownloadException", Default, _MyFunc), 0, False)
; Usage.....: Return SetError(_ThrowException("DownloadException", "Failed to download X.zip", _MyFunc), 0, False)
Func _ThrowException($sName, $sMessage = Default, $sCaller = Default)
    If Not __IsInTry() Then Return 0

	; check if the exception exists, register it if not
    Local $bRegistered = _IsExceptionExists($sName) ? True : _RegisterException($sName)

	; fall-back to $EXCEPTION_ROOT if not existent due an error like empty string exception name
    Local $sException  = $bRegistered ? $sName : $EXCEPTION_ROOT
    Local $sMsg        = ($sMessage = Default Or String($sMessage) = "") ? _GetExceptionMessage($sException) : String($sMessage)
    Local $sSource     = __StackEntrySource($sCaller)

    __StackPush($sException, $sMsg, $sSource)
    Return _GetExceptionCode($sException)
EndFunc

; Check if execution should be skipped due to previous exceptions in the try block
; Returns: True if exceptions exist and try/catch is active, False otherwise
; Usage..: If _OnErrorResume() Then Return SetError(_ThrowException(<name>, Default, <func>), 0, False)
Func _OnErrorResume()
    If __IsInTry() And __HasStackEntry() Then Return True
    Return False
EndFunc

; Returns True if there are NO previous exceptions in the current try block scope
; Inverse of _OnErrorResume() - useful for guarding a single non-compatible call with _TryWith()
; Returns: True if no exceptions exist in scope (safe to proceed), False otherwise
; Usage..: _TryWith(_NoErr() ? _ArraySort($aArray) : Null)
Func _NoErr()
    Return Not _OnErrorResume()
EndFunc

; Catch exceptions from the current try level matching a given exception type, set $eOut by reference
; $eOut  - ByRef output - receives the matched stack entry if found
; $vType - exception type(s) to match against - a single type, a comma-separated list, or an array,
;          normally built via _AsExceptionType() (Default = $EXCEPTION_ROOT, matches anything)
; Returns: True if a match was found, False otherwise
; Note...: Only the LATEST matching entry in scope is returned
; Note...: Use in an If/ElseIf chain to test multiple types - only the first match wins
; Note...: A comma-separated list/array of types is equivalent to splitting them across multiple
;          ElseIf _Catch() branches, in the same order - see _AsExceptionType()
; Usage..: If _Catch($e, _AsExceptionType("SomeException")) Then
; Usage..: ElseIf _Catch($e) Then
Func _Catch(ByRef $eOut, $vType = _AsExceptionType($EXCEPTION_ROOT))
    If __IsCatched() Then Return False

	Local $aType    = IsArray($vType) ? $vType : _AsExceptionType($vType)

    Local $mEntries = __GetStackEntriesInScope()
    Local $iCount   = __GetScopeStackCount()
    Local $mMatch   = __FindLatestMatch($mEntries, $iCount, $aType)

    If $mMatch = Default Then Return False

    __SetCatched($CURRENT_DEPTH())
    $eOut = $mMatch
    Return True
EndFunc

; Wrap a non TryCatch compliant function call to capture its exceptions into the try/catch stack
; $vReturn - return value of the wrapped function call
; $iError  - @error from the wrapped function - auto-captured via default param at call time
; Returns  : $vReturn
; Usage....: _TryWith(_ArraySort($aArray))
; Usage....: _TryWith(_NoErr() ? _ArraySort($aArray) : Null)
Func _TryWith($vReturn, $iError = @error)
    If $iError Then _ThrowException($EXCEPTION_ROOT)
    Return $vReturn
EndFunc

; Returns the stack entries recorded within the current try block scope, or a transformed result via $vHandler
; $vHandler - custom function to transform/process ($mEntries, $iCount) (Default = no custom function)
; Returns   : $vHandler's return value if provided, otherwise the raw map of stack entries for the current scope
;             False with @error=0xDEAD, @extended=0xBEEF if $vHandler has an incompatible signature
; Note......: Does NOT mark the scope as caught - safe to call any number of times, anywhere in the try block
; Note......: Useful for inspecting/logging the current scope's exceptions
; Usage.....: Local $mEntries = _StackTrace()
; Usage.....: Local $sReport  = _StackTrace(_FormatStackTrace)
Func _StackTrace($vHandler = Default)
    Local $mEntries = __GetStackEntriesInScope()
    Local $iCount   = __GetScopeStackCount()

    If $vHandler <> Default And IsFunc($vHandler) Then
        Local $vHandlerReturn = Call(FuncName($vHandler), $mEntries, $iCount)
        If @error = 0xDEAD And @extended = 0xBEEF Then Return SetError(@error, @extended, False)
        Return $vHandlerReturn
    EndIf

    Return $mEntries
EndFunc

; Returns a human-readable string for one stack entry plus its registered exception ancestor chain
; $mEntry - a single stack entry (sException, sMessage, sSource)
Func __FormatEntryChain($mEntry)
    Local $sOutput = "[" & $mEntry.sException & "] " & $mEntry.sMessage & " (source: " & $mEntry.sSource & ")" & @CRLF

    Local $sParent = _GetExceptionParent($mEntry.sException)
    While $sParent <> Default And Not __IsExceptionRoot($sParent)
        $sOutput &= "  caused by [" & $sParent & "] " & _GetExceptionMessage($sParent) & @CRLF
        $sParent = _GetExceptionParent($sParent)
    WEnd

    Return $sOutput
EndFunc

; Returns a human-readable, multi-line string for all stack entries in scope, each with its ancestor chain
; $mEntries - map of stack entries (from _StackTrace())
; $iCount   - number of entries in $mEntries (Default = __GetScopeStackCount())
; Usage....: _StackTrace(_FormatStackTrace)
; Usage....: _FormatStackTrace(_StackTrace())
; Note: Use it as example to how to create custom functions to pass to _StackTrace()
Func _FormatStackTrace($mEntries, $iCount = __GetScopeStackCount())
    Local $sOutput = ""
    For $i = 0 To $iCount - 1
        $sOutput &= __FormatEntryChain($mEntries[$i])
    Next
    Return $sOutput
EndFunc
