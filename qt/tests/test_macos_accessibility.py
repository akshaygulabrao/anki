# Copyright: Ankitects Pty Ltd and contributors
# License: GNU AGPL, version 3 or later; http://www.gnu.org/licenses/agpl.html

from unittest.mock import Mock

import pytest

from aqt import _macos_helper


@pytest.mark.parametrize("platform", ["linux", "win32", "darwin"])
def test_guard_requires_explicit_opt_in(
    monkeypatch: pytest.MonkeyPatch, platform: str
) -> None:
    helper = Mock()
    monkeypatch.setattr(_macos_helper.sys, "platform", platform)
    monkeypatch.setattr(_macos_helper, "macos_helper", helper)
    monkeypatch.delenv("ANKI_MACOS_ACCESSIBILITY_GUARD", raising=False)

    _macos_helper.install_qt_accessibility_guard("6.11.2")

    helper.install_qt_accessibility_guard.assert_not_called()


@pytest.mark.parametrize("platform", ["linux", "win32"])
def test_guard_is_macos_only(monkeypatch: pytest.MonkeyPatch, platform: str) -> None:
    helper = Mock()
    monkeypatch.setattr(_macos_helper.sys, "platform", platform)
    monkeypatch.setattr(_macos_helper, "macos_helper", helper)
    monkeypatch.setenv("ANKI_MACOS_ACCESSIBILITY_GUARD", "1")

    _macos_helper.install_qt_accessibility_guard("6.11.2")

    helper.install_qt_accessibility_guard.assert_not_called()


def test_guard_receives_runtime_version(monkeypatch: pytest.MonkeyPatch) -> None:
    helper = Mock()
    monkeypatch.setattr(_macos_helper.sys, "platform", "darwin")
    monkeypatch.setattr(_macos_helper, "macos_helper", helper)
    monkeypatch.setenv("ANKI_MACOS_ACCESSIBILITY_GUARD", "1")

    _macos_helper.install_qt_accessibility_guard("6.9.1")

    helper.install_qt_accessibility_guard.assert_called_once_with("6.9.1")


@pytest.mark.parametrize(
    "helper",
    [None, object(), Mock(install_qt_accessibility_guard=Mock(return_value=False))],
)
def test_unavailable_guard_does_not_block_startup(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture, helper: object
) -> None:
    monkeypatch.setattr(_macos_helper.sys, "platform", "darwin")
    monkeypatch.setattr(_macos_helper, "macos_helper", helper)
    monkeypatch.setenv("ANKI_MACOS_ACCESSIBILITY_GUARD", "1")

    _macos_helper.install_qt_accessibility_guard("6.11.2")

    assert "Qt accessibility guard" in caplog.text
