// Copyright: Ankitects Pty Ltd and contributors
// License: GNU AGPL, version 3 or later; http://www.gnu.org/licenses/agpl.html

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static IMP originalDealloc;
static IMP originalRemove;
static ptrdiff_t idOffset;

static bool returnsType(Method method, const char *type)
{
    char actual[8];
    method_getReturnType(method, actual, sizeof(actual));
    return strcmp(actual, type) == 0;
}

static bool managedByParent(id element)
{
    SEL selector = sel_registerName("isManagedByParent");
    IMP method = class_getMethodImplementation(object_getClass(element), selector);
    return ((BOOL (*)(id, SEL))method)(element, selector);
}

static void guardedDealloc(id element, SEL selector)
{
    // A synthesized row/column/cell borrows its table's ID. Clear only the
    // borrowed ID so Qt's original cleanup cannot delete the table interface.
    if (managedByParent(element))
        *(uint32_t *)((char *)element + idOffset) = 0;
    ((void (*)(id, SEL))originalDealloc)(element, selector);
}

static void guardedRemove(id cls, SEL selector, NSArray *elements)
{
    NSMutableArray *owned = [NSMutableArray arrayWithCapacity:elements.count];
    for (id element in elements) {
        if (!managedByParent(element))
            [owned addObject:element];
    }
    ((void (*)(id, SEL, NSArray *))originalRemove)(cls, selector, owned);
}

// Temporary ownership workaround for QTBUG-149612; remove once a fixed Qt ships.
// Mirrors the ownership guards proposed in qtbase change 765434 without linking
// against Qt's private C++ APIs. Install on the main thread after QApplication.
bool install_qt_accessibility_guard(const char *version)
{
    unsigned major, minor, patch;
    char extra;
    if (!version || sscanf(version, "%u.%u.%u%c", &major, &minor, &patch, &extra) != 3
        || major != 6 || minor < 8 || minor > 11
        || (minor == 8 && patch < 1) || (minor == 11 && patch > 2))
        return false;
    if (![NSThread isMainThread])
        return false;
    if (originalDealloc)
        return true;
    Class cls = objc_getClass("QMacAccessibilityElement");
    Ivar axid = class_getInstanceVariable(cls, "axid");
    Method dealloc = class_getInstanceMethod(cls, sel_registerName("dealloc"));
    Method remove = class_getClassMethod(cls, sel_registerName("removeElementsFromCache:"));
    Method managed = class_getInstanceMethod(cls, sel_registerName("isManagedByParent"));
    if (!cls || !axid || !dealloc || !remove || !managed
        || strcmp(ivar_getTypeEncoding(axid), @encode(uint32_t)) != 0
        || method_getNumberOfArguments(dealloc) != 2
        || method_getNumberOfArguments(remove) != 3
        || method_getNumberOfArguments(managed) != 2
        || !returnsType(dealloc, @encode(void))
        || !returnsType(remove, @encode(void))
        || !returnsType(managed, @encode(BOOL)))
        return false;
    idOffset = ivar_getOffset(axid);
    if (idOffset < 0 || idOffset + sizeof(uint32_t) > class_getInstanceSize(cls))
        return false;
    originalRemove = method_setImplementation(remove, (IMP)guardedRemove);
    originalDealloc = method_setImplementation(dealloc, (IMP)guardedDealloc);
    return true;
}
