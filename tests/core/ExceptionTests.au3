; #INDEX# =======================================================================================================================
; Title .........: AutoIt TryCatch - Exception.au3 Tests
; Version .......: 0.0.1
; AutoIt Version : 3.3.18.0
; Author ........: Crucial Thread
; Description ...: Unit tests for Exception.au3
;                  Tests cover: initial state, exception registration, exception retrieval,
;                  exception hierarchy, root protection, self-inheritance prevention,
;                  exception code resolution, push validation, exception type checking,
;                  and name sanitization (__SanitizeIdentifier / _RegisterException).
; Dependencies ..: TestFramework.au3, Exception.au3
; ===============================================================================================================================

#include "..\..\lib\TestFramework\TestFramework.au3"
#include "..\..\src\core\Exception.au3"

; ===============================================================================================================================
; Tests
; ===============================================================================================================================

Func _TestInitialState()
    _TestFmkHeader("Test: Initial State")
    _TestFmkAssert(_IsExceptionExists($EXCEPTION_ROOT),                     "Root exception registered on include",         _IsExceptionExists($EXCEPTION_ROOT),        "True")
    _TestFmkAssert(_GetExceptionMessage($EXCEPTION_ROOT) = "An exception occurred", "Root exception has correct message",   _GetExceptionMessage($EXCEPTION_ROOT),      "An exception occurred")
    _TestFmkAssert(_GetExceptionCode($EXCEPTION_ROOT) = 1,                  "Root exception has code 1",                    _GetExceptionCode($EXCEPTION_ROOT),         "1")
    _TestFmkAssert(_GetExceptionParent($EXCEPTION_ROOT) = __ExceptionKey($EXCEPTION_ROOT), "Root parent is itself",         _GetExceptionParent($EXCEPTION_ROOT),       __ExceptionKey($EXCEPTION_ROOT))
EndFunc

Func _TestIsExceptionExists()
    _TestFmkHeader("Test: _IsExceptionExists")
    _RegisterException("ExistsTest")
    _TestFmkAssert(_IsExceptionExists("ExistsTest"),        "Returns True for registered exception",    _IsExceptionExists("ExistsTest"),       "True")
    _TestFmkAssert(_IsExceptionExists("EXISTSTEST"),        "Case insensitive — uppercase",             _IsExceptionExists("EXISTSTEST"),       "True")
    _TestFmkAssert(_IsExceptionExists("existstest"),        "Case insensitive — lowercase",             _IsExceptionExists("existstest"),       "True")
    _TestFmkAssert(_IsExceptionExists("NotRegistered") = False, "Returns False for unregistered",       _IsExceptionExists("NotRegistered"),    "False")
    _TestFmkAssert(_IsExceptionExists("") = False,          "Returns False for empty string",           _IsExceptionExists(""),                 "False")
EndFunc

Func _TestGetException()
    _TestFmkHeader("Test: _GetException")
    _RegisterException("GetExTest", "Get exception test message")
    Local $mEx = _GetException("GetExTest")
    _TestFmkAssert(IsMap($mEx),                             "Returns a map for registered exception",   VarGetType($mEx),   "Map")
    _TestFmkAssert($mEx.sName = "GetExTest",                "Map has correct sName",                    $mEx.sName,         "GetExTest")
    _TestFmkAssert($mEx.sMessage = "Get exception test message", "Map has correct sMessage",            $mEx.sMessage,      "Get exception test message")
    _TestFmkAssert(_GetException("NotRegistered") = Default, "Returns Default for unregistered",        _GetException("NotRegistered"), "Default")
EndFunc

Func _TestGetExceptionMessage()
    _TestFmkHeader("Test: _GetExceptionMessage")
    _RegisterException("MsgTest", "Test message")
    _TestFmkAssert(_GetExceptionMessage("MsgTest") = "Test message",    "Returns correct message",          _GetExceptionMessage("MsgTest"),        "Test message")
    _TestFmkAssert(_GetExceptionMessage("NotRegistered") = Default,     "Returns Default for unregistered", _GetExceptionMessage("NotRegistered"),  "Default")
EndFunc

Func _TestGetExceptionCode()
    _TestFmkHeader("Test: _GetExceptionCode")
    _RegisterException("CodeTest", Default, Default, 42)
    _TestFmkAssert(_GetExceptionCode("CodeTest") = 42,          "Returns correct code",             _GetExceptionCode("CodeTest"),      "42")
    _TestFmkAssert(_GetExceptionCode("NotRegistered") = Default, "Returns Default for unregistered", _GetExceptionCode("NotRegistered"), "Default")
EndFunc

Func _TestGetExceptionParent()
    _TestFmkHeader("Test: _GetExceptionParent")
    _RegisterException("ParentBase")
    _RegisterException("ParentChild", Default, "ParentBase")
    _TestFmkAssert(_GetExceptionParent("ParentChild") = "parentbase",       "Returns correct parent",           _GetExceptionParent("ParentChild"),     "parentbase")
    _TestFmkAssert(_GetExceptionParent("NotRegistered") = Default,          "Returns Default for unregistered", _GetExceptionParent("NotRegistered"),   "Default")
EndFunc

Func _TestRegisterException()
    _TestFmkHeader("Test: _RegisterException")

    ; Basic registration
    Local $bResult = _RegisterException("RegTest", "Registration test")
    _TestFmkAssert($bResult = True,                         "Returns True on success",              $bResult,                           "True")
    _TestFmkAssert(_IsExceptionExists("RegTest"),           "Exception exists after registration",  _IsExceptionExists("RegTest"),      "True")

    ; Message fallback to name
    _RegisterException("RegNoMsg")
    _TestFmkAssert(_GetExceptionMessage("RegNoMsg") = "RegNoMsg", "Message falls back to name when not provided", _GetExceptionMessage("RegNoMsg"), "RegNoMsg")

    ; Empty message fallback to name
    _RegisterException("RegEmptyMsg", "")
    _TestFmkAssert(_GetExceptionMessage("RegEmptyMsg") = "RegEmptyMsg", "Empty message falls back to name", _GetExceptionMessage("RegEmptyMsg"), "RegEmptyMsg")

    ; Auto-increment code
    Local $iCode1 = _GetExceptionCode("RegTest")
    _RegisterException("RegTest2", "Test 2")
    Local $iCode2 = _GetExceptionCode("RegTest2")
    _TestFmkAssert($iCode2 > $iCode1,                       "Auto-incremented code is greater than previous", $iCode2, "> " & $iCode1)

    ; Custom code
    _RegisterException("RegCustomCode", Default, Default, 999)
    _TestFmkAssert(_GetExceptionCode("RegCustomCode") = 999, "Custom code is stored correctly",    _GetExceptionCode("RegCustomCode"), "999")

    ; Custom parent
    _RegisterException("RegParent")
    _RegisterException("RegChild", Default, "RegParent")
    _TestFmkAssert(_GetExceptionParent("RegChild") = "regparent", "Custom parent stored correctly", _GetExceptionParent("RegChild"), "regparent")

    ; Overwrite existing
    _RegisterException("RegOverwrite", "Original message")
    _RegisterException("RegOverwrite", "Overwritten message")
    _TestFmkAssert(_GetExceptionMessage("RegOverwrite") = "Overwritten message", "Overwrites existing exception", _GetExceptionMessage("RegOverwrite"), "Overwritten message")
EndFunc

Func _TestRegisterExceptionValidation()
    _TestFmkHeader("Test: _RegisterException validation")

    ; Empty name
    Local $bResult = _RegisterException("")
    _TestFmkAssert($bResult = False,                        "Returns False for empty name",         $bResult,   "False")

    ; Root redefinition
    $bResult = _RegisterException($EXCEPTION_ROOT, "Overwritten")
    _TestFmkAssert($bResult = False,                        "Returns False when redefining root",   $bResult,   "False")
    _TestFmkAssert(_GetExceptionMessage($EXCEPTION_ROOT) = "An exception occurred", "Root message unchanged after redefinition attempt", _GetExceptionMessage($EXCEPTION_ROOT), "An exception occurred")

    ; Self-inheritance
    $bResult = _RegisterException("SelfInherit", Default, "SelfInherit")
    _TestFmkAssert($bResult = False,                        "Returns False for self-inheritance",   $bResult,   "False")
EndFunc

Func _TestExtendsException()
    _TestFmkHeader("Test: _ExtendsException")

    ; Default returns root
    _TestFmkAssert(_ExtendsException() = __ExceptionKey($EXCEPTION_ROOT),       "Default returns root key",             _ExtendsException(),                __ExceptionKey($EXCEPTION_ROOT))

    ; Registered parent
    _RegisterException("ExtendsBase")
    _TestFmkAssert(_ExtendsException("ExtendsBase") = "extendsbase",            "Returns normalized key for registered", _ExtendsException("ExtendsBase"),   "extendsbase")

    ; Unregistered parent — auto-registers
    _TestFmkAssert(_ExtendsException("AutoCreatedParent") = "autocreatedparent", "Returns key for auto-created parent",  _ExtendsException("AutoCreatedParent"), "autocreatedparent")
    _TestFmkAssert(_IsExceptionExists("AutoCreatedParent"),                     "Auto-created parent exists in registry", _IsExceptionExists("AutoCreatedParent"), "True")
EndFunc

Func _TestAsErrCode()
    _TestFmkHeader("Test: _AsErrCode")
    Local $iNext = __NextExceptionCode()
    _TestFmkAssert(_AsErrCode(5) = 5,                       "Valid code returned as-is",                _AsErrCode(5),          "5")
    _TestFmkAssert(_AsErrCode(0) = $iNext,                  "Zero falls back to auto-increment",        _AsErrCode(0),          $iNext)
    _TestFmkAssert(_AsErrCode(-1) = $iNext,                 "Negative falls back to auto-increment",    _AsErrCode(-1),         $iNext)
    _TestFmkAssert(_AsErrCode("abc") = $iNext,              "Non-integer falls back to auto-increment", _AsErrCode("abc"),      $iNext)
EndFunc

Func _TestPushException()
    _TestFmkHeader("Test: __PushException validation")

    ; Empty key
    Local $mValid[]
    $mValid.sName    = "Test"
    $mValid.sMessage = "Test message"
    $mValid.sParent  = "trycatchexception"
    $mValid.iCode    = 1
    _TestFmkAssert(__PushException("", $mValid) = False,    "Returns False for empty key",          __PushException("", $mValid),   "False")

    ; Invalid exception map — missing fields
    Local $mInvalid[]
    $mInvalid.sName = "Test"
    _TestFmkAssert(__PushException("testkey", $mInvalid) = False, "Returns False for invalid map", __PushException("testkey", $mInvalid), "False")

    ; Valid push
    _TestFmkAssert(__PushException("pushtest", $mValid) = True, "Returns True for valid push",     __PushException("pushtest", $mValid), "True")
    _TestFmkAssert(_IsExceptionExists("pushtest"),          "Exception exists after valid push",    _IsExceptionExists("pushtest"),     "True")
EndFunc

Func _TestIsExceptionOf()
    _TestFmkHeader("Test: _IsExceptionOf")
    _RegisterException("Animal", "An animal")
    _RegisterException("Dog", "A dog", "Animal")
    _RegisterException("Labrador", "A labrador", "Dog")
    _RegisterException("Cat", "A cat", "Animal")

    ; Exact match
    _TestFmkAssert(_IsExceptionOf("Dog", "Dog"),            "Exact match returns True",                 _IsExceptionOf("Dog", "Dog"),           "True")

    ; Direct parent
    _TestFmkAssert(_IsExceptionOf("Dog", "Animal"),         "Direct parent returns True",               _IsExceptionOf("Dog", "Animal"),        "True")

    ; Grandparent
    _TestFmkAssert(_IsExceptionOf("Labrador", "Animal"),    "Grandparent returns True",                 _IsExceptionOf("Labrador", "Animal"),   "True")

    ; Root
    _TestFmkAssert(_IsExceptionOf("Labrador", $EXCEPTION_ROOT), "Root always returns True",            _IsExceptionOf("Labrador", $EXCEPTION_ROOT), "True")

    ; Different branch
    _TestFmkAssert(_IsExceptionOf("Dog", "Cat") = False,    "Different branch returns False",           _IsExceptionOf("Dog", "Cat"),           "False")

    ; Child is not parent
    _TestFmkAssert(_IsExceptionOf("Animal", "Dog") = False, "Child is not parent returns False",        _IsExceptionOf("Animal", "Dog"),        "False")

    ; Unregistered exception
    _TestFmkAssert(_IsExceptionOf("NotRegistered", "Animal") = False, "Unregistered exception returns False", _IsExceptionOf("NotRegistered", "Animal"), "False")

    ; Case insensitive
    _TestFmkAssert(_IsExceptionOf("DOG", "animal"),         "Case insensitive returns True",            _IsExceptionOf("DOG", "animal"),        "True")
EndFunc

Func _TestSanitizeIdentifier()
    _TestFmkHeader("Test: __SanitizeIdentifier")
    _TestFmkAssert(__SanitizeIdentifier("MyException") = "MyException",     "Already-valid name passes through unchanged",    __SanitizeIdentifier("MyException"),     "MyException")
    _TestFmkAssert(__SanitizeIdentifier("My Exception!") = "MyException",   "Strips spaces and punctuation",                  __SanitizeIdentifier("My Exception!"),   "MyException")
    _TestFmkAssert(__SanitizeIdentifier("2ndException") = "_2ndException",  "Prefixes underscore when starting with a digit", __SanitizeIdentifier("2ndException"),    "_2ndException")
    _TestFmkAssert(__SanitizeIdentifier("Valid_Name123") = "Valid_Name123", "Letters, digits, underscore preserved",          __SanitizeIdentifier("Valid_Name123"),   "Valid_Name123")
    _TestFmkAssert(__SanitizeIdentifier("---") = "",                        "Fully invalid input sanitizes to empty",         __SanitizeIdentifier("---"),             "(empty)")
    _TestFmkAssert(__SanitizeIdentifier("") = "",                           "Empty input stays empty",                        __SanitizeIdentifier(""),                "(empty)")
EndFunc

Func _TestRegisterExceptionSanitizesName()
    _TestFmkHeader("Test: _RegisterException sanitizes invalid characters instead of rejecting")
    Local $bResult = _RegisterException("My Exception!")
    _TestFmkAssert($bResult = True,                          "Registration succeeds despite invalid characters", $bResult, "True")
    _TestFmkAssert(_IsExceptionExists("MyException") = True, "Sanitized name is registered",                     _IsExceptionExists("MyException"), "True")
    _TestFmkAssert(_GetException("MyException").sName = "MyException", "Stored sName is the sanitized form",      _GetException("MyException").sName, "MyException")

    Local $bResult2 = _RegisterException("---") ; fully invalid - sanitizes to empty
    _TestFmkAssert($bResult2 = False, "Registration fails when sanitization leaves nothing", $bResult2, "False")
EndFunc

; ===============================================================================================================================
; Run all tests
; ===============================================================================================================================

Func _RunAllTests()
    Local $bAllPassed = True
    $bAllPassed = _TestFmkRun(_TestInitialState,                $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestIsExceptionExists,           $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestGetException,                $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestGetExceptionMessage,         $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestGetExceptionCode,            $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestGetExceptionParent,          $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestRegisterException,           $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestRegisterExceptionValidation, $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestExtendsException,            $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestAsErrCode,                   $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestPushException,               $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestIsExceptionOf,               $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestSanitizeIdentifier,            $bAllPassed)
    $bAllPassed = _TestFmkRun(_TestRegisterExceptionSanitizesName, $bAllPassed)
    _TestFmkSummary()
    Return $bAllPassed
EndFunc

_RunAllTests()
