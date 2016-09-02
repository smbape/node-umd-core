(function(root, factory) {
    'use strict';
    if (typeof exports !== 'undefined') {
        module.exports = factory();
    } else if (typeof define === 'function' && define.amd) {
        define(factory);
    } else {
        root.clone = factory();
    }
})(this, function() {
    'use strict';

    var toString = Object.prototype.toString,
        hasProp = Object.prototype.hasOwnProperty,
        ARRAY_LIKE = '[object Array]',
        REGEXP_LIKE = '[object RegExp]',
        DATE_LIKE = '[object Date]',
        OBJECT_LIKE = '[object Object]',
        useBuffer = 'undefined' !== typeof Buffer;

    return {
        cloneDeep: cloneDeep,
        defaultsDeep: defaultsDeep,
        defaults: defaults
    };

    /**
     * Clones (copies) an Object using deep copying.
     *
     * This function supports circular references by default, but if you are certain
     * there are no circular references in your object, you can save some CPU time
     * by calling clone(obj, false).
     *
     * Caution: if `circular` is false and `parent` contains circular references,
     * your program may enter an infinite loop and crash.
     *
     * @param `parent` - the object to be cloned
     * @param `circular` - set to true if the object to be cloned may contain
     *    circular references. (optional - true by default)
     * @param `depth` - set to a number if the object is only to be cloned to
     *    a particular depth. (optional - defaults to Infinity)
     * @param `prototype` - sets the prototype to be used when cloning an object.
     *    (optional - defaults to parent prototype).
     */
    function cloneDeep(parent, circular, depth, prototype) {
        var allParents, allChildren;

        if (typeof circular === 'object') {
            depth = circular.depth;
            prototype = circular.prototype;
            circular = circular.circular;
        }

        if (typeof circular === 'undefined') {
            circular = true;
        }

        if (typeof depth === 'undefined') {
            depth = Infinity;
        }

        if (circular) {
            // maintain two arrays for circular references, where corresponding parents
            // and children have the same index
            allParents = [];
            allChildren = [];
        }

        return _clone(parent, depth, circular, prototype, allParents, allChildren);
    }

    // recurse this function so we don't reset allParents and allChildren
    function _clone(parent, depth, circular, prototype, allParents, allChildren) {
        var child, proto, flags;

        if (parent === null || depth === 0 || typeof parent !== 'object') {
            return parent;
        }

        switch (toString.call(parent)) {
            case ARRAY_LIKE:
                child = [];
                break;
            case REGEXP_LIKE:
                flags = [];
                if (parent.global) {
                    flags.push('g');
                }
                if (parent.ignoreCase) {
                    flags.push('i');
                }
                if (parent.multiline) {
                    flags.push('m');
                }
                child = new RegExp(parent.source, flags.join(''));
                if (parent.lastIndex) {
                    child.lastIndex = parent.lastIndex;
                }
                break;
            case DATE_LIKE:
                child = new Date(parent.getTime());
                break;
            default:
                if (useBuffer && Buffer.isBuffer(parent)) {
                    child = new Buffer(parent.length);
                    parent.copy(child);
                    return child;
                }

                if (typeof prototype === 'undefined') {
                    proto = Object.getPrototypeOf(parent);
                } else {
                    proto = prototype;
                }
                child = Object.create(proto);
        }

        if (circular) {
            var index = allParents.indexOf(parent);

            if (index !== -1) {
                return allChildren[index];
            }
            allParents.push(parent);
            allChildren.push(child);
        }

        var attrs;
        for (var key in parent) {
            if (!hasProp.call(parent, key)) {
                // ignore inherited properties
                continue;
            }

            child[key] = _clone(parent[key], depth - 1, circular, prototype, allParents, allChildren);
        }

        return child;
    }

    function defaults(child) {
        var depth = 1,
            circular = true,
            prototype;

        for (var i = 1, len = arguments.length; i < len; i++) {
            _defaults(child, arguments[i], depth, circular, prototype, [], []);
        }

        return child;
    }

    function defaultsDeep(child) {
        var depth = Infinity,
            circular = true,
            prototype;

        for (var i = 1, len = arguments.length; i < len; i++) {
            _defaults(child, arguments[i], depth, circular, prototype, [], []);
        }

        return child;
    }

    function _defaults(child, parent, depth, circular, prototype, allParents, allChildren) {
        var proto, flags;

        if (depth === 0 || child === null || typeof child !== 'object') {
            return child;
        }

        if (parent === null || typeof parent !== 'object') {
            return child;
        }

        if (typeof prototype === 'undefined') {
            proto = Object.getPrototypeOf(child);
        }

        if (circular) {
            var index = allParents.indexOf(parent);

            if (index !== -1) {
                return allChildren[index];
            }
            allParents.push(parent);
            allChildren.push(child);
        }

        var attrs, parentStr, childStr;
        for (var key in parent) {
            if (!hasProp.call(parent, key)) {
                // ignore inherited properties
                continue;
            }

            if (hasProp.call(child, key)) {
                parentStr = toString.call(parent[key]);
                childStr = toString.call(child[key]);

                if (childStr !== parentStr) {
                    continue;
                }

                if (childStr !== OBJECT_LIKE && childStr !== ARRAY_LIKE) {
                    continue;
                }

                _defaults(child[key], parent[key], depth - 1, circular, prototype, allParents, allChildren);
            } else {
                child[key] = _clone(parent[key], depth - 1, circular, prototype, allParents, allChildren);
            }
        }

        return child;
    }

});