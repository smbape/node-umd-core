const hasProp = Object.prototype.hasOwnProperty;

module.exports = function inherits(child, parent) {
    for (const key in parent) {
        if (hasProp.call(parent, key)) {
            child[key] = parent[key];
        }
    }

    /** @this Ctor */
    function Ctor() {
        this.constructor = child;
    }

    Ctor.prototype = parent.prototype;
    child.prototype = new Ctor();
    child.__super__ = parent.prototype;

    return child;
};
