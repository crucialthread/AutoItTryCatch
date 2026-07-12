; #INDEX# =======================================================================================================================
; Title .........: AutoIt TryCatch - Exception.au3 library
; Version .......: 0.0.1
; AutoIt Version : 3.3.18.0
; Author ........: Crucial Thread
; Description ...: Exception registration and management for TryCatch.au3
;                  Provides exception hierarchy, registration and throwing.
; Dependencies ..: None
; Usage .........: #include "TryCatch.au3" (Exception.au3 is included automatically via TryCatch.au3)
;
;                  --------------------------------------------------------------------------------------------------------------
;                  >>> _RegisterException() Examples: <<<
;
;                  _RegisterException("MyException")
;                  _RegisterException("MyException", "")
;                  _RegisterException("MyException", Default)
;                  _RegisterException("MyException", "My exception message")
;                  _RegisterException("MyException", "My exception message", Default)
;                  _RegisterException("MyException", "My exception message", "TryCatchException")
;                  _RegisterException("MyException", "My exception message", _ExtendsException("TryCatchException"))
;                  _RegisterException("MyException", "My exception message", $EXCEPTION_ROOT)
;                  _RegisterException("MyException", "My exception message", _ExtendsException($EXCEPTION_ROOT))
;                  _RegisterException("MyException", "My exception message", Default, Default)
;                  _RegisterException("MyException", "My exception message", Default, __NextExceptionCode())
;                  _RegisterException("MyException", "My exception message", Default, 1)
;                  _RegisterException("MyException", "My exception message", Default, _AsErrCode(1))
;
;                  _RegisterException("MyChildException", "", "MyException")
;                  _RegisterException("MyChildException", Default, "MyException")
;                  _RegisterException("MyChildException", "My child exception", "MyException")
;                  _RegisterException("MyChildException", "My child exception", _ExtendsException("MyException"))
;                  _RegisterException("MyChildException", "My child exception", _ExtendsException("MyException"), _AsErrCode(7))
;                  ... and all the above but with "MyException" as the parent, the parent will be created if not existent
;
;                  More information about _RegisterException() defaults and usages on the function comments below
;
; ===============================================================================================================================

#include-once

; Root exception name - all exceptions inherit from this
Global Const $EXCEPTION_ROOT = "TryCatchException"

; Exception registry map - stores all registered exceptions
Global $__g_mExceptionRegistry[]

; ===============================================================================================================================
; Internal helpers
; ===============================================================================================================================

; Strips any character that isn't a letter, digit, or underscore from $sName
; If the result starts with a digit, prefixes it with an underscore to stay identifier-valid
; $sName - value to sanitize
Func __SanitizeIdentifier($sName)
    Local $sClean = StringRegExpReplace(String($sName), "[^a-zA-Z0-9_]", "")
    If StringRegExp($sClean, "^[0-9]") Then $sClean = "_" & $sClean
    Return $sClean
EndFunc

; Returns the normalized exception key - lowercased for case insensitive lookups
; $sValue - value to normalize
Func __ExceptionKey($sValue)
    Return StringLower(__SanitizeIdentifier($sValue))
EndFunc

; Returns the next available exception code based on registry size
; Used for auto-incrementing exception codes when none is provided
Func __NextExceptionCode()
    Return UBound(MapKeys($__g_mExceptionRegistry)) + 1
EndFunc

; Resolves a parent name to a normalized key
; Returns root exception key if $sParent is Default or empty
; $sParent - parent exception name to resolve
Func __ResolveExceptionParent($sParent)
    If $sParent = Default Or __ExceptionKey($sParent) = "" Then Return __ExceptionKey($EXCEPTION_ROOT)
    Return __ExceptionKey($sParent)
EndFunc

; Returns True if the given exception name is the root exception
; $sExceptionName - exception name to check
Func __IsExceptionRoot($sExceptionName)
    Return __ExceptionKey($sExceptionName) = __ExceptionKey($EXCEPTION_ROOT)
EndFunc

; Returns True if $sExceptionName and $sParent resolve to the same key - self-inheritance
; $sExceptionName - exception name to check
; $sParent        - parent name to check against
Func __IsSelfInheritance($sExceptionName, $sParent)
    Return __ExceptionKey($sExceptionName) = __ResolveExceptionParent($sParent)
EndFunc

; Returns True if the exception name is valid for registration
; An exception name is invalid if it is empty or matches $EXCEPTION_ROOT
; $sName - exception name to validate
Func __IsValidExceptionName($sName)
    If __ExceptionKey($sName) = "" Then Return False
    If __IsExceptionRoot($sName) Then Return False
    Return True
EndFunc

; Returns True if both the exception name and parent are valid for registration
; $sExceptionName - exception name to validate
; $sParent        - parent name to validate against self-inheritance
Func __IsValidException($sExceptionName, $sParent)
    If Not __IsValidExceptionName($sExceptionName) Then Return False
    If __IsSelfInheritance($sExceptionName, $sParent) Then Return False
    Return True
EndFunc

; Factory function - creates a new exception map with consistent structure and type coercion
; $sName      - exception name
; $sMsg       - exception message
; $sParentKey - normalized parent exception key
; $iErrCode   - exception error code
; Returns     : exception map
Func __ExceptionNew($sName, $sMsg, $sParentKey, $iErrCode)
    Local $mException[]
    $mException.sName    = String($sName)
    $mException.sMessage = String($sMsg)
    $mException.sParent  = String($sParentKey)
    $mException.iCode    = Int($iErrCode)
    Return $mException
EndFunc

; Returns True if $mException is a valid exception map with all required fields
; $mException - map to validate
Func __IsException($mException)
    If Not IsMap($mException) Then Return False
    If Not MapExists($mException, "sName") Then Return False
    If Not MapExists($mException, "sMessage") Then Return False
    If Not MapExists($mException, "sParent") Then Return False
    If Not MapExists($mException, "iCode") Then Return False
    Return True
EndFunc

; Pushes an exception map into the registry under the given key
; $sKey       - registry key (normalized internally)
; $mException - exception map to store - must be a valid exception map
; Returns     : True on success, False if key is empty or exception map is invalid
Func __PushException($sKey, $mException)
    If __ExceptionKey($sKey) = "" Then Return False
    If Not __IsException($mException) Then Return False
    $__g_mExceptionRegistry[__ExceptionKey($sKey)] = $mException
    Return @error ? False : True
EndFunc

; Resolves the exception message - falls back to $sExceptionName if message is Default or empty
; $sExceptionName - exception name used as fallback message
; $sMessage       - provided message (Default = use $sExceptionName as message)
; Returns         : resolved message string
Func __ResolveExceptionMsg($sExceptionName, $sMessage = Default)
    If $sMessage = Default Then Return String($sExceptionName)
    $sMessage = String($sMessage)
    Return $sMessage = "" ? String($sExceptionName) : $sMessage
EndFunc

; Bootstrap the root exception - called once on include
; Bypasses normal validation since root exception parent is itself
Func __RegisterRootException()
    Local $sKey     = __ExceptionKey($EXCEPTION_ROOT)
    Local $sName    = $EXCEPTION_ROOT
    Local $sMessage = "An exception occurred"
    Local $sParent  = $sKey
    Local $iCode    = 1

    __PushException($sKey, __ExceptionNew($sName, $sMessage, $sParent, $iCode))
EndFunc

; ===============================================================================================================================
; Public API
; ===============================================================================================================================

; Returns True if an exception exists in the registry
; $sName - exception name to check (normalized internally)
Func _IsExceptionExists($sName)
    Return MapExists($__g_mExceptionRegistry, __ExceptionKey($sName))
EndFunc

; Retrieve a registered exception by name
; $sName - exception name
; Returns: exception map if found, Default otherwise
Func _GetException($sName)
    If Not _IsExceptionExists($sName) Then Return Default
    Return $__g_mExceptionRegistry[__ExceptionKey($sName)]
EndFunc

; Returns the registered default message for an exception
; $sName   - exception name
; Returns  : message string if exception exists, Default otherwise
Func _GetExceptionMessage($sName)
    Local $mException = _GetException($sName)
	Return ($mException = Default)? Default : $mException.sMessage
EndFunc

; Returns the registered code for an exception
; $sName   - exception name
; Returns  : integer code if exception exists, Default otherwise
Func _GetExceptionCode($sName)
    Local $mException = _GetException($sName)
	Return ($mException = Default)? Default : $mException.iCode
EndFunc

; Returns the registered parent name for an exception
; $sName   - exception name
; Returns  : parent name string if exception exists, Default otherwise
Func _GetExceptionParent($sName)
    Local $mException = _GetException($sName)
	Return ($mException = Default)? Default : $mException.sParent
EndFunc

; Resolves the exception code - validates provided code or falls back to auto-increment
; $iCode - exception code (Default = auto-incremented from registry size)
; Returns: provided code if valid positive integer, otherwise next auto-incremented code
Func _AsErrCode($iCode = __NextExceptionCode())
    $iCode = Int($iCode)
    Return ($iCode > 0) ? $iCode : __NextExceptionCode()
EndFunc

; Returns True if $sException is of type $sType or inherits from it
; Traverses the exception hierarchy until root is reached or a match is found
; $sException - exception name to check
; $sType      - exception type to check against
; Returns     : True if $sException is $sType or inherits from it, False otherwise
Func _IsExceptionOf($sException, $sType)
    Local $sKException    	 = __ExceptionKey($sException)
    Local $sKTypeOfException = __ExceptionKey($sType)

    ; $sException must exist in the registry
    If Not _IsExceptionExists($sKException) Then Return False

    ; every registered exception inherits from root
    If __IsExceptionRoot($sKTypeOfException) Then Return True

    While $sKException <> ""
        If $sKException = $sKTypeOfException Then Return True
        Local $mException = _GetException($sKException)
        If $mException = Default Then Return False			 ; exception not found
        $sKException = $mException.sParent					 ; use parent as the next to compare
        If __IsExceptionRoot($sKException) Then Return False ; reached root - no match found
    WEnd

    Return False
EndFunc

; Resolves the exception to extend from. Auto-registers parent if not found and not root
; $sParent - parent exception name (Default = root exception)
; Returns  : normalized parent key
Func _ExtendsException($sParent = Default)
    $sParent = __ResolveExceptionParent($sParent)
    If Not __IsExceptionRoot($sParent) Then
        If Not _IsExceptionExists($sParent) Then _RegisterException($sParent)
    EndIf
    Return __ExceptionKey($sParent)
EndFunc

; Register an exception type
; $sName    - exception name - can only contain letters, digits, and underscore, cannot start with a digit,
;             and cannot be empty; sanitized before registration by stripping invalid characters,
;             if nothing remains after sanitization does not register
; $sMessage - default message (Default = $sName; falls back to $sName if empty or not a string)
; $sParent  - parent exception name (Default = $EXCEPTION_ROOT, auto-registered if not found)
; $iCode    - exception code (Default = auto-incremented from registry size)
; Returns   : True on success, False otherwise
; Note......: Overwrites if exception name already exists
; Note......: Cannot redefine $EXCEPTION_ROOT or set self as parent (self inheritance)
Func _RegisterException($sName, $sMessage = Default, $sParent = Default, $iCode = Default)
    $sName = __SanitizeIdentifier($sName)
    If Not __IsValidException($sName, $sParent) Then Return False

    Local $sKey       = __ExceptionKey($sName)
    Local $sMsg       = __ResolveExceptionMsg($sName, $sMessage)
    Local $sParentKey = _ExtendsException($sParent)
    Local $iErrCode   = _AsErrCode($iCode)

    Return __PushException($sKey, __ExceptionNew($sName, $sMsg, $sParentKey, $iErrCode))
EndFunc

; Bootstrap root exception on include
__RegisterRootException()