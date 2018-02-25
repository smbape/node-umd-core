module.exports = function() {
    const fns = [];
    let size = 0;
    const len = arguments.length;

    for (let i = 0; i < len; i++) {
        const arg = arguments[i];
        if ("function" === typeof arg) {
            fns.push(arg);
            size++;
        }
    }

    if (size === 0 || size === 1) {
        return fns[0];
    }

    const func = function() {
        const len1 = fns.length;

        for (let j = 0; j < len1; j++) {
            fns[j].apply(null, arguments);
        }
    };

    return func;
};
