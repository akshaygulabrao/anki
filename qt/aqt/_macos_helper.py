# Copyright: Ankitects Pty Ltd and contributors
# License: GNU AGPL, version 3 or later; http://www.gnu.org/licenses/agpl.html

from __future__ import annotations

import logging
import os
import sys

if sys.platform == "darwin":
    from anki_mac_helper import macos_helper
else:
    macos_helper = None


def install_qt_accessibility_guard(qt_version: str) -> None:
    # Opt-in while this workaround for Qt's private Cocoa implementation is
    # evaluated. Older helper wheels continue to work without the workaround.
    if (
        sys.platform != "darwin"
        or os.environ.get("ANKI_MACOS_ACCESSIBILITY_GUARD") != "1"
    ):
        return
    guard = getattr(macos_helper, "install_qt_accessibility_guard", None)
    if guard is None:
        logging.warning("Qt accessibility guard requires anki-mac-helper 0.1.2")
    elif not guard(qt_version):
        logging.warning("Qt accessibility guard does not support this Qt runtime")
