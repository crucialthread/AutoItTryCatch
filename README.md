# AutoIt TryCatch Solution

A try/catch pattern implementation for AutoIt. Brings structured exception handling to AutoIt with named exception types, an inheritance hierarchy, compatible try/catch functions, and a static analysis lint tool for SciTE.

See the full [documentation](https://crucialthread.github.io/AutoItTryCatch/) for more details.

## Features

AutoIt TryCatch Solution brings the try/catch pattern to AutoIt, giving developers a structured way to handle errors:

- **Compatible try/catch functions** - write functions that skip automatically when a prior exception is on the stack, keeping the happy path clean
- **Named exception types with hierarchy** - define exceptions like `FileException` extending `IOException`, and catch entire families of related errors in one handler
- **Integration with existing code** - `_TryWith()` wraps any AutoIt function that uses `@error`/`SetError()` into the exception model without modifying it
- **Stack trace inspection** - `_StackTrace()` and `_FormatStackTrace()` let you inspect the current exception scope at any point
- **TryCatchLint** - static analysis tool for SciTE that detects unbalanced `_Try()`/`_EndTry()` calls and unregistered exception names before your code even runs

## Quick Example

```autoit
#include <TryCatch.au3>

_RegisterException("FileException", "A file operation failed")

Func _ReadConfig($sPath)
    If _OnErrorResume() Then Return SetError(__GetStackCount(), 0, False)
    If Not FileExists($sPath) Then
        Return SetError(_ThrowException("FileException", "Config not found: " & $sPath, _ReadConfig), 0, False)
    EndIf
    Return FileRead($sPath)
EndFunc

_Try()
    _ReadConfig("config.ini")
    _ReadConfig("settings.ini")
Local $e
If _Catch($e, _AsExceptionType("FileException")) Then
    ConsoleWrite("Caught: " & $e.sException & " - " & $e.sMessage & @CRLF)
EndIf
_EndTry()
```

## Installation

### Option 1 - Installer (recommended)

Download the latest installer from the [releases page](https://github.com/crucialthread/AutoItTryCatch/releases) and run it. Two installation modes are available:

**Full installation** - installs `TryCatch.au3` and `Exception.au3` to your AutoIt Vendor include folder, registers them via the registry so they are available from any project, and installs the TryCatchLint tool for SciTE. Recommended for new users.

```autoit
#include <TryCatch.au3>
```

**Lint Tool Only** - installs only the TryCatchLint tool and registers it in SciTE. Recommended for developers already using TryCatch as a git submodule who still want the SciTE lint integration.

The installer also includes the documentation (`TryCatch.chm`) and an uninstaller registered in Add/Remove Programs.

> **Note:** the installer requires administrator rights to write to the AutoIt installation folder. It is recommended to close SciTE before running the installer.

> ⚠️ **Windows security warning:** Windows may show a SmartScreen warning when running the installer for the first time since it is not digitally signed. This is expected for open source tools distributed outside the Microsoft Store. You can proceed in one of two ways:
> - Click **More info** then **Run anyway** on the SmartScreen dialog
> - Right-click the downloaded `.exe` > **Properties** > check **Unblock** at the bottom > click OK, then run it normally
>
> If you prefer not to run the installer, you can install manually by downloading and extracting the source code zip from the releases page and following Option 2 and Installing the Lint Tool Manually below.

### Option 2 - Local project folder

Download and extract the source code zip from the [releases page](https://github.com/crucialthread/AutoItTryCatch/releases), copy `src/core/TryCatch.au3` and `src/core/Exception.au3` into your project folder, and reference them with a relative path:

```autoit
#include "TryCatch.au3"
```

`TryCatch.au3` includes `Exception.au3` automatically - only one include is needed.

This is the simplest option but means you need a separate copy for each project (or you can keep them in a shared folder from where all your projects reference them).

### Option 3 - Git submodule (recommended for Git projects)

If your project is a Git repository, you can add AutoIt TryCatch Solution as a submodule directly from the `dist` branch. This gives you `TryCatch.au3` and `Exception.au3` with no extra content from the development repo, and lets you pin to a specific version and update deliberately when you are ready.

**Step 1 - Add the submodule:**

```bash
git submodule add -b dist https://github.com/crucialthread/AutoItTryCatch lib/TryCatch
git submodule update --init
```

**Step 2 - Reference it from your scripts:**

```autoit
#include "lib/TryCatch/TryCatch.au3"
```

**Cloning a project that already uses the submodule:**

```bash
git clone --recurse-submodules https://github.com/youruser/YourProject
```

Or if you already cloned without it:

```bash
git submodule update --init
```

**Updating to a newer version when ready:**

```bash
git submodule update --remote lib/TryCatch
git add lib/TryCatch
git commit -m "Update TryCatch to latest"
```

## Installing the Lint Tool Manually

If you chose not to use the installer, you can set up TryCatchLint in SciTE manually.

**Step 1 - Copy the lint files:**

Download and extract the source code zip from the [releases page](https://github.com/crucialthread/AutoItTryCatch/releases) and copy `src/lint/TryCatchLint.au3` and `src/lint/TryCatchLintSciTE.au3` to a folder of your choice, for example:

```
C:\Program Files (x86)\AutoIt3\SciTE\TryCatchLint\
```

**Step 2 - Register TryCatchLint in SciTEUser.properties:**

The simplest way is to use the self-registration feature built into TryCatchLint itself. Open `TryCatchLint.au3` directly in SciTE and press **F5/Go** with no arguments. This triggers the self-registration flow which:

- Detects whether TryCatch Lint is already registered in `SciTEUser.properties`
- Finds the next available Tools menu slot
- Writes the registration block to `SciTEUser.properties`
- Prompts you to restart SciTE for the change to take effect

**Step 3 - Restart SciTE:**

After registration, restart SciTE. TryCatch Lint will appear in the Tools menu with the shortcut **Ctrl+Alt+L**.

## Troubleshooting

### Conflict between global installation and Git submodule

If you have AutoIt TryCatch Solution installed globally (via the installer) and are working on a Git project that also includes it as a submodule, you will get duplicate declaration errors at runtime. This happens because AutoIt sees two copies of the same files from different paths.

To resolve this, uninstall the global installation via Add/Remove Programs and use the submodule reference (`#include "lib/TryCatch/TryCatch.au3"`) for that project. Then install it locally as described in Option 2, and any other scripts that previously used `#include <TryCatch.au3>` will need to be updated to reference the files directly.

## Usage

See the [documentation](https://crucialthread.github.io/AutoItTryCatch/) for the full function reference, concepts guide, and worked examples.

## API

### TryCatch.au3

| Function | Description |
|---|---|
| `_Try()` | Opens a try scope and activates the exception stack. |
| `_EndTry([$bForceReset])` | Closes the current try scope. |
| `_Catch(ByRef $eOut [, $vType])` | Checks the scope's stack for a matching exception and returns True if found. |
| `_ThrowException($sName [, $sMessage [, $sCaller]])` | Adds a named exception entry to the scope's stack. Used in compatible try/catch functions. |
| `_OnErrorResume()` | Returns True if exceptions exist on the stack. Used as the skip guard in compatible functions. |
| `_NoErr()` | Returns True if no exceptions exist on the stack. Used with `_TryWith()`. |
| `_TryWith($vReturn [, $iError])` | Wraps a non-compatible function and converts a non-zero `@error` into a generic exception. |
| `_AsExceptionType($vException)` | Normalizes an exception type for use with `_Catch()`. |
| `_StackTrace([$vHandler])` | Returns the current scope's exception entries. |
| `_FormatStackTrace($mEntries, $iCount)` | Formats stack entries as a human-readable string. |

### Exception.au3 (included automatically by TryCatch.au3)

| Function | Description |
|---|---|
| `_RegisterException($sName [, $sMessage [, $sParent [, $iCode]]])` | Registers a named exception type in the global registry. |
| `_GetExceptionMessage($sName)` | Returns the registered default message for an exception type. |
| `_GetExceptionCode($sName)` | Returns the numeric code for an exception type. |
| `_GetExceptionParent($sName)` | Returns the parent type name of an exception type. |
| `_IsExceptionExists($sName)` | Returns True if an exception type is registered. |
| `_IsExceptionOf($sName, $sType)` | Returns True if an exception type is equal to or descends from another. |
| `_ExtendsException($sName, $sParent)` | Returns True if an exception type directly or indirectly extends another. |
| `_AsErrCode([$iCode])` | Resolves an exception code - validates provided code or returns the next auto-incremented value. |

## Requirements

- AutoIt 3.3.18.0 or later
- SciTE4AutoIt3 (for TryCatchLint integration)

## License

MIT
