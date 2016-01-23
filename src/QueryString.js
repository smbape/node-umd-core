deps = [{
    amd: 'qs',
    common: '!Qs'
}]

function factory(require, QueryString) {
    'use strict';

    var slice = Array.prototype.slice;

    if (!QueryString) {
        // nodejs, leave it as it is
        return require('qs');
    }

    var parse = QueryString.parse;

    QueryString.parse = function(search) {
        if (arguments.length === 0) {
            return parse.call(QueryString);
        }

        var args = arguments;
        if ('string' === typeof search && '?' === search.charAt(0)) {
            args = slice.call(arguments);
            args[0] = search.substring(1);
        }

        return parse.apply(QueryString, args);
    }

    return QueryString;
}