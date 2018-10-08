(function(global, factory) {
    if (typeof define === "function" && define.amd) {
        define(["module"], factory);
    } else if (typeof exports === "object" && typeof module !== "undefined") {
        factory(module);
    } else {
        var mod = {
            exports: {}
        };
        factory(mod);
        global.fastDeepEqual = mod.exports;
    }
})(function(_this) {
    var g;

    if (typeof window !== "undefined") {
        g = window;
    } else if (typeof global !== "undefined") {
        g = global;
    } else if (typeof self !== "undefined") {
        g = self;
    } else {
        g = _this;
    }

    return g;
}(this), function(module) {
    'use strict';

    var isArray = Array.isArray;
    var keyList = Object.keys;
    var hasProp = Object.prototype.hasOwnProperty;

    module.exports = function equal(a, b) {
        if (a === b) return true;

        if (a && b && typeof a == 'object' && typeof b == 'object') {
            var arrA = isArray(a),
                arrB = isArray(b), i, length, key;

            if (arrA && arrB) {
                length = a.length;
                if (length != b.length) return false;
                for (i = length; i-- !== 0;)
                    if (!equal(a[i], b[i])) return false;
                return true;
            }

            if (arrA !== arrB) return false;

            var dateA = a instanceof Date,
                dateB = b instanceof Date;
            if (dateA !== dateB) return false;
            if (dateA && dateB) return a.getTime() == b.getTime();

            var regexpA = a instanceof RegExp,
                regexpB = b instanceof RegExp;
            if (regexpA !== regexpB) return false;
            if (regexpA && regexpB) return a.toString() == b.toString();

            var keys = keyList(a);
            length = keys.length;

            if (length !== keyList(b).length)
                return false;

            for (i = length; i-- !== 0;)
                if (!hasProp.call(b, keys[i])) return false;

            for (i = length; i-- !== 0;) {
                key = keys[i];
                if (!equal(a[key], b[key])) return false;
            }

            return true;
        }

        return a !== a && b !== b;
    };
});