// Copyright: Ankitects Pty Ltd and contributors
// License: GNU AGPL, version 3 or later; http://www.gnu.org/licenses/agpl.html

#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <QApplication>
#include <QAccessible>
#include <QTableWidget>
#include <cstdio>

#ifdef ANKI_MAC_HELPER_LIBRARY
#include <dlfcn.h>
static bool install_qt_accessibility_guard(const char *version)
{
    // Match ctypes.CDLL in the Python helper and keep the library loaded for
    // the lifetime of the swizzled Objective-C methods.
    static void *library = dlopen(ANKI_MAC_HELPER_LIBRARY, RTLD_NOW | RTLD_LOCAL);
    if (!library)
        return false;
    static auto guard = reinterpret_cast<bool (*)(const char *)>(
            dlsym(library, "install_qt_accessibility_guard"));
    return guard && guard(version);
}
#else
extern "C" bool install_qt_accessibility_guard(const char *version);
#endif

@interface NSObject (QtAXRegression)
+ (id)elementWithInterface:(QAccessibleInterface *)interface;
- (BOOL)isManagedByParent;
- (NSArray *)accessibilityRows;
- (NSArray *)accessibilityChildren;
- (NSArray *)accessibilitySelectedChildren;
- (NSString *)accessibilityRole;
@end

int main(int argc, char **argv)
{
    for (const char *unsupported : {"6.7.3", "6.8.0", "6.11.3", "6.12.0", "6.11.2beta", "invalid"}) {
        if (install_qt_accessibility_guard(unsupported))
            return 6;
    }
    if (install_qt_accessibility_guard(nullptr))
        return 6;
    QApplication app(argc, argv);
    fprintf(stderr, "Qt %s\n", qVersion());
    if (argc > 1 && std::string(argv[1]) == "--guard") {
        if (!install_qt_accessibility_guard(qVersion())
            || !install_qt_accessibility_guard(qVersion())) {
            fprintf(stderr, "guard unavailable\n");
            return 2;
        }
    }
    QAccessible::Id tableId = 0;
    QAccessible::Id cellId = 0;
    @autoreleasepool {
        QTableWidget table(3, 2);
        table.setSelectionBehavior(QAbstractItemView::SelectRows);
        for (int row = 0; row < 3; ++row)
            for (int col = 0; col < 2; ++col)
                table.setItem(row, col, new QTableWidgetItem(QString::number(row * 2 + col)));
        table.show();
        app.processEvents();
        table.selectRow(0);
        QAccessible::setActive(true);
        auto *interface = QAccessible::queryAccessibleInterface(&table);
        auto id = QAccessible::uniqueId(interface);
        tableId = id;
        Class cls = objc_getClass("QMacAccessibilityElement");
        NSObject *element = [cls elementWithInterface:interface];
        NSArray *rows = [element accessibilityRows];
        for (NSObject *row in rows)
            (void)[row accessibilityChildren];
        fprintf(stderr, "placeholders created, table id=%u\n", id);
        for (int cycle = 0; cycle < 20; ++cycle) {
            for (int row = 0; row < 3; ++row) {
                table.selectRow(row);
                app.processEvents();
                NSArray *selected = [element accessibilitySelectedChildren];
                if (selected.count != 2 || !QAccessible::accessibleInterface(id))
                    return 3;
                for (NSObject *cell in selected)
                    if (![[cell accessibilityRole] isEqualToString:NSAccessibilityCellRole])
                        return 4;
            }
        }
        for (int cols : {3, 2}) {
            table.clearSelection();
            table.setColumnCount(cols);
            for (int row = 0; row < 3; ++row)
                for (int col = 0; col < cols; ++col)
                    if (!table.item(row, col))
                        table.setItem(row, col, new QTableWidgetItem(QString::number(row * cols + col)));
            table.selectRow(0);
            app.processEvents();
            rows = [element accessibilityRows];
            for (NSObject *row in rows)
                (void)[row accessibilityChildren];
            NSArray *selected = [element accessibilitySelectedChildren];
            if (selected.count != (NSUInteger)cols || !QAccessible::accessibleInterface(id)) {
                fprintf(stderr, "columns %d selected %lu interface %p\n", cols, selected.count,
                        QAccessible::accessibleInterface(id));
                return 5;
            }
        }
        cellId = QAccessible::uniqueId(interface->tableInterface()->cellAt(0, 0));
        fprintf(stderr, "PASS: selected children, table lifetime, column changes\n");
    }
    if (QAccessible::accessibleInterface(tableId) || QAccessible::accessibleInterface(cellId))
        return 7;
    fprintf(stderr, "PASS: table and real-cell interface destruction\n");
    return 0;
}
