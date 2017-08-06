deps = [
    "../../lib/getMatchingRules",
    "../../lib/specificity"
]

function factory(getMatchingRules, specificity) {

    // https://developer.mozilla.org/en-US/docs/Glossary/Vendor_Prefix
    function getStylePrefix(name, style) {
        var styleProp = name.toLowerCase();
        if (styleProp in style) {
            return "";
        }

        // Modernizr/src/omPrefixes.js
        var omPrefixes = ["Webkit", "Moz", "O", "ms"];
        var prefix;

        for (var i = 0, len = omPrefixes.length; i < len; i++) {
            prefix = omPrefixes[i];
            styleProp = prefix + name;
            if (styleProp in style) {
                return prefix;
            }
        }

        return null;
    }

    function getStyleEventName(prefix, eventName) {
        switch (prefix) {
            case "Webkit":
                return "webkit" + eventName[0].toUpperCase() + eventName.slice(1);
            case "Moz":
                return "moz" + eventName[0].toUpperCase() + eventName.slice(1);
            case "O":
                return "o" + eventName.toLowerCase();
            case "ms":
                return "MS" + eventName[0].toUpperCase() + eventName.slice(1);
            default:
                return eventName;
        }
    }

    const prefix = getStylePrefix("Transform", document.createElement("span").style);

    return function getMatchingCssRule(el, name) {
        name = getStyleEventName(prefix, name);
        if (!("style" in el)) {
            return null;
        }

        if (el.style[name] !== 0) {
            return el.style[name];
        }

        const rule = getMatchingRules(el).filter(rule => {
            return Boolean(rule.style[name]);
        }).sort((a, b) => {
            a = specificity.calculate(a.selectorText).specificity;
            b = specificity.calculate(b.selectorText).specificity;
            return a > b ? 1 : a < b ? -1 : 0;
        })[0];

        return rule ? rule.style[name] : null;
    };
}
