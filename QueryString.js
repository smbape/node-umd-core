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

        if ('string' === typeof search && '?' === search.charAt(0)) {
            search = search.substring(1);
        }

        var args = slice.call(arguments);
        args[0] = search;

        return parse.apply(QueryString, args);
    }

    return QueryString;
}