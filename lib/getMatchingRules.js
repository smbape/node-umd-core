/* eslint-disable no-invalid-this */
(function umd(root, factory) {
    if (typeof exports === "object" && typeof module === "object") {
        module.exports = factory();
    } else if (typeof define === "function" && define.amd) {
        define([], factory);
    } else if (typeof exports === "object") {
        exports.getMatchingRules = factory();
    } else {
        root.getMatchingRules = factory();
    }
})(this, function() {
    return function getMatchingRules(el) {
        var sheets = el.ownerDocument.styleSheets,
            matchingRules = [];

        el.matches = el.matches || el.webkitMatchesSelector || el.mozMatchesSelector || el.msMatchesSelector || el.oMatchesSelector;

        for (var i in sheets) {
            var rules = sheets[i].rules || sheets[i].cssRules;
            for (var r in rules) {
                if (el.matches(rules[r].selectorText)) {
                    matchingRules.push(rules[r]);
                }
            }
        }

        return matchingRules;
    };
});
