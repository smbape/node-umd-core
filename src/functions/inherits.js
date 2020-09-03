const inherits = (Child, Parent) => {
    Object.defineProperties(Child, {
        super_: {
            value: Parent,
            writable: true,
            configurable: true
        },

        __super__: {
            value: Parent.prototype,
            writable: true,
            configurable: true
        }
    });

    // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/setPrototypeOf
    // Until engine developers address this issue, if you are concerned about performance,
    // you should avoid setting the [[Prototype]] of an object.
    // Instead, create a new object with the desired [[Prototype]] using Object.create().

    Child.prototype = Object.create(Parent.prototype, {
        constructor: {
            value: Child,
            writable: true,
            configurable: true
        }
    });

    Object.setPrototypeOf(Child.prototype, Parent.prototype);

    return Child;
};

module.exports = inherits;
