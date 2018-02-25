const hasProp = Object.prototype.hasOwnProperty;

module.exports = function inherits(child, parent) {
    for (const key in parent) {
        if (hasProp.call(parent, key)) {
            child[key] = parent[key];
        }
    }

    /** @this ctor */
    function ctor() {
        this.constructor = child;
    }

    ctor.prototype = parent.prototype;
    child.prototype = new ctor();
    child.__super__ = parent.prototype;

    return child;
};
