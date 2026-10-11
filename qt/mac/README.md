Helper library for macOS-specific functionality.

The experimental workaround for QTBUG-149612 is enabled with
`ANKI_MACOS_ACCESSIBILITY_GUARD=1` after installing a locally built helper 0.1.2.
It checks the Qt version and Objective-C class layout before installing the
ownership guards. The native regression test verifies that the accessible table and selected
cells survive placeholder replacement.
Unsupported runtimes are left unchanged. This is a temporary workaround until a fixed Qt runtime is available.

Build the universal helper with `python qt/mac/helper_build.py`. Run the native
regression test with a Qt 6 development installation (for example Homebrew's
`qtbase`):

```sh
cmake -S qt/mac/tests -B extra/mac-ax-tests -G Ninja \
    -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qtbase \
    -DANKI_MAC_HELPER_LIBRARY="$PWD/qt/mac/anki_mac_helper/libankihelper.dylib"
cmake --build extra/mac-ax-tests
ctest --test-dir extra/mac-ax-tests --output-on-failure
```

Running `extra/mac-ax-tests/ax-regression` without `--guard` is the negative
control. On affected Qt releases it can crash, so use a disposable process.
The fixture exercises the Cocoa methods in process; an external AX client or
accessibility permission is not required. It does not open an Anki collection.
For a full integration check, use a disposable Anki profile with no add-ons,
select a row in Browse, and inspect it with an authorized accessibility client.
Confirm that selected cells remain exposed and that changing the selection,
search results, columns, and closing Browse do not crash.


To run this fork from source with its local helper, first install the usual
Anki development requirements, then run:

```sh
tools/run-macos-accessibility -b "$PWD/extra/ax-profile" -p "AX Test"
```

This builds Anki and the universal helper, installs the helper only into
`out/pyenv`, and enables the guard for that process. The separate base folder
keeps this test profile independent of a normal study profile. The helper
wheel is built locally; publishing a new package to PyPI is not required.

Validation on macOS 26.6.2 arm64: the native negative control crashes on Qt
6.9.1, 6.11.1, and 6.11.2. With the guard enabled, all three pass 60 row-selection
changes, a 2→3→2 column-count sequence, cell-role checks, and table/real-cell
interface destruction. The Qt 6.9.1 baseline faults at `libqcocoa + 0x812b0`,
the same offset observed in the Anki crashes tracked in
[ankitects/anki#5800](https://github.com/ankitects/anki/issues/5800).

The 13 Python helper/startup tests and Ruff checks pass. A disposable Anki
26.9.3 / Qt 6.11.2 runtime, using this fork’s modified startup/helper modules
with the released backend and generated assets, also survived Browse accessibility
reads, changing a selected row, an empty search and restoring results, and a
fullscreen transition. **The workaround is experimental:** some table cell
values disappear from AX snapshots after Browse refreshes, and Qt logs invalid
object warnings. A broader native 2→3→2→4 column sequence also returned three
selected cells for the final four-column table. These additional accessibility
problems remain unresolved; the guard addresses the reproduced ownership crash.
VoiceOver and x86_64 execution have not been validated. Both helper architectures
compile, but the local full `./ninja check` is blocked by Rust 1.87.0 (the repo
pins 1.99.0). Keep using a disposable profile for evaluation.
