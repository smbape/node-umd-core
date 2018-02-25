import QueryString from "%{ amd: 'qs', common: 'qs', brunch: '!Qs' }";

let exports;

if (!QueryString) {
    // nodejs, leave it as it is
    exports = require("qs");
} else {
    exports = QueryString;

    const slice = Array.prototype.slice;
    const parse = QueryString.parse;

    QueryString.parse = function(search) {
        if (arguments.length === 0) {
            return parse.call(QueryString);
        }

        let args = arguments;

        if ("string" === typeof search && "?" === search[0]) {
            args = slice.call(arguments);
            args[0] = search.slice(1);
        }

        return parse.apply(QueryString, args);
    };
}

module.exports = exports;
