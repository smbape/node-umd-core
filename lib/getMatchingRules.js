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
        global.getMatchingRules = mod.exports;
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
    "use strict";

    module.exports = function getMatchingRules(el) {
        const sheets = el.ownerDocument.styleSheets;
        const matchingRules = [];

        el.matches = el.matches || el.webkitMatchesSelector || el.mozMatchesSelector || el.msMatchesSelector || el.oMatchesSelector;

        // eslint-disable-next-line guard-for-in
        for (const i in sheets) {
            const rules = sheets[i].rules || sheets[i].cssRules;
            for (const r in rules) {
                if (el.matches(rules[r].selectorText)) {
                    matchingRules.push(rules[r]);
                }
            }
        }

        return matchingRules;
    };
});