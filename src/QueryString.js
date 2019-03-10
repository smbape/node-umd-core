import QueryString from "%{ amd: 'qs', brunch: '!Qs', common: 'qs', node: 'qs' }";

// nodejs, leave it as it is
if (typeof process !== "object" || typeof process.platform === "undefined") {
    exports = QueryString;

    const slice = Array.prototype.slice;
    const parse = QueryString.parse;

    QueryString.parse = function(search) {
        let args = arguments;

        if (args.length === 0) {
            return parse.call(QueryString);
        }

        if ("string" === typeof search && "?" === search[0]) {
            args = slice.call(args);
            args[0] = search.slice(1);
        }

        return parse.apply(QueryString, args);
    };
    
    module.exports = exports;
}
