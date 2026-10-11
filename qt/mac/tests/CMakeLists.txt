# Copyright: Ankitects Pty Ltd and contributors
# License: GNU AGPL, version 3 or later; http://www.gnu.org/licenses/agpl.html

cmake_minimum_required(VERSION 3.21)
project(anki_ax_regression LANGUAGES CXX OBJC OBJCXX)
find_package(Qt6 REQUIRED COMPONENTS Widgets)
add_executable(ax-regression accessibility.mm)
if(ANKI_MAC_HELPER_LIBRARY)
    target_compile_definitions(ax-regression PRIVATE ANKI_MAC_HELPER_LIBRARY="${ANKI_MAC_HELPER_LIBRARY}")
else()
    target_sources(ax-regression PRIVATE ../accessibility.m)
endif()
target_link_libraries(ax-regression PRIVATE Qt6::Widgets "-framework AppKit")
target_compile_features(ax-regression PRIVATE cxx_std_17)
target_compile_options(ax-regression PRIVATE -fno-objc-arc)
# Allows the same public-API fixture to test older PyQt framework bundles.
target_compile_definitions(ax-regression PRIVATE QT_NO_VERSION_TAGGING)
enable_testing()
add_test(NAME accessibility-ownership COMMAND ax-regression --guard)
