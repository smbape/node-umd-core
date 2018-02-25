const commonCamel = {
    "-": {
        toCamel(str) {
            return str.replace(/-\w/g, match => {
                return match[1].toUpperCase();
            });
        },
        toCapitalCamel(str) {
            return str.replace(/(?:^|-)(\w)/g, (match, letter) => {
                return letter.toUpperCase();
            });
        }
    },
    ":": {
        toCamel(str) {
            return str.replace(/:\w/g, match => {
                return match[1].toUpperCase();
            });
        },
        toCapitalCamel(str) {
            return str.replace(/(?:^|:)(\w)/g, (match, letter) => {
                return letter.toUpperCase();
            });
        }
    },
    " ": {
        toCamel(str) {
            return str.replace(RegExp(" \\w", "g"), match => {
                return match[1].toUpperCase();
            });
        },
        toCapitalCamel(str) {
            return str.replace(/(?:^| )(\w)/g, (match, letter) => {
                return letter.toUpperCase();
            });
        }
    }
};

const StringUtil = Object.assign({}, {
    escapeRegExp(str) {
        return str.replace(/([\\/^$.|?*+()[\]{}])/g, "\\$1");
    },
    capitalize(str) {
        return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
    },
    firstUpper(str) {
        return str.charAt(0).toUpperCase() + str.slice(1);
    },
    toCamel(str, mark) {
        if (mark == null) {
            mark = "-";
        }
        if (commonCamel[mark]) {
            return commonCamel[mark].toCamel(str);
        }

        const reg = new RegExp(`${ StringUtil.escapeRegExp(mark) }\\w`, "g");
        return str.replace(reg, match => {
            return match[1].toUpperCase();
        });
    },
    toCapitalCamel(str, mark) {
        if (commonCamel[mark]) {
            return commonCamel[mark].toCapitalCamel(str);
        }

        const reg = new RegExp(`(?:^|${ StringUtil.escapeRegExp(mark) })(\\w)`, "g");
        return str.replace(reg, (match, letter) => {
            return letter.toUpperCase();
        });
    },
    toCamelDash(str) {
        return str.replace(/-(\w)/g, match => {
            return match[1].toUpperCase();
        });
    },
    toCapitalCamelDash(str) {
        return StringUtil.toCamelDash(StringUtil.capitalize(str));
    },
    firstSubstring(str, n) {
        if (typeof str !== "string") {
            return str;
        }
        if (n >= str.length) {
            return "";
        }
        return str.substring(0, str.length - n);
    },
    lastSubstring(str, n) {
        if (typeof str !== "string") {
            return str;
        }
        if (n >= str.length) {
            return str;
        }
        return str.substring(str.length - n, str.length);
    }
});

const _entityMap = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;",
    "/": "&#x2F;"
};

StringUtil.escapeHTML = function(html) {
    if (typeof html === "string") {
        return html.replace(/[&<>"'/]/g, s => {
            return _entityMap[s];
        });
    }
    return html;
};

module.exports = StringUtil;
