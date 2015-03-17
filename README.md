# XCodePostFacto

XcodePostFacto enables the use of Yosemite-only Xcode 6.3 on Mac OS X 10.9 Mavericks. 

The name is, of course, a nod to the original [XPostFacto](https://en.wikipedia.org/wiki/XPostFacto).

## Why

It seems a bit gratitious to break compatibility with an OS release that was current less than 6 months ago, and while the the Yosemite upgrade is free, it has it's own inherent costs -- especially in terms of [privacy](https://fix-macosx.com/) and [quality](http://mjtsai.com/blog/2015/01/06/apples-software-quality-continued/) [issues](http://mjtsai.com/blog/2014/10/11/apples-software-quality-decline/).

Plus, I don't like being told what to do :-)

## Usage

After building the `xpf-bootstrap.framework`, Xcode can be launched from the command-line:

    env DYLD_INSERT_LIBRARIES=$ABSOLUTE_PATH_TO_FRAMEWORK/xpf-bootstrap.framework/xpf-bootstrap /Applications/Xcode-beta.app/Contents/MacOS/Xcode

Contribution of a wrapping launch application would be most appreciated, especially one that supports drag-and-drop of the Xcode binary to create a new launcher :-)

## Status

The code has seen limited local testing, but Xcode 6.3-beta3 launches and is operable; until the code has stabilized, I expect to find and fix issues during day-to-day use of Xcode.

## How

There are a number of hurdles to getting Xcode 6.3 running on an earlier release:

* Xcode declares a minimum system version of 10.10, preventing launch via `LaunchServices` and triggering an abort() in `HIServices` if you bypass the initial `LaunchServices` check.
* Xcode continues to ship with no-longer functional 10.9 compatibity code, and enables that code if it detects it's running on Mavericks. This results in crashes -- and even if you got past those, the result wouldn't actually be Xcode 6.3.
* Xcode links against 10.10-only APIs, which trigger both link-time and runtime crashes.

To resolve these issues, we must patch Xcode and system libraries: disabling the legacy compatibility code, all version checks, and performing runtime rebinding of missing symbols.

XcodePostFacto leverages the following mechanisms to achieve this:

* Prior to Xcode's main(), the private `dyld_register_image_state_change_handler` API is used to hook `dyld` and modify library symbol references that are critical to bootstrapping the process:
	*  After the library has been rebased, but before it has been linked, we use a custom single-stepping implementation of dyld symbol rebinding to find strong references to Yosemite-only symbols and rewrite them as weak references.
	* Once the library has been linked, but before it has been initialized, we use the same `BIND_OPCODE_*` evaluator to rebind symbols to our custom replacements.
* Before handing control back to Xcode, the bootstrap code uses my [PLPatchMaster](https://opensource.plausible.coop/src/projects/PLTP/repos/plpatchmaster/browse) library to register a future patch on Xcode's `DVTPlugInManager` class. This patch adds `xpf_bootstrap.framework/Contents/Resources/Xcode` to `DVTPlugInManager`'s plugin search path. 
* A custom plugin in `xpf_bootstrap.framework/Contents/Resources/Xcode` uses Xcode's standard plugin mechanisms to hook the `IDEInitialize` step, performing a final set of bootstrap operations within the now-initialized Xcode process.
