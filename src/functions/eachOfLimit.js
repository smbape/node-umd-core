function onlyOnce(fn) {
    return function() {
        if (fn === null) {
            throw new Error("Callback was already called.");
        }

        const callFn = fn;
        fn = null;
        callFn.apply(null, arguments);
    };
}

const eachOfLimit = (obj, limit, iteratee, callback) => {
    if (callback == null) {
        callback = Function.prototype;
    }

    if (limit <= 0 || !obj) {
        callback(null);
        return;
    }

    let nextIndex = -1;
    const isArray = Array.isArray(obj);
    const keys = isArray ? null : Object.keys(obj);
    const len = isArray ? obj.length : keys.length;

    if (len === 0) {
        callback();
        return;
    }

    let done = false;
    let running = 0;
    let looping = false;

    function iterateeCallback(err, value) {
        running--;
        if (err) {
            done = true;
            callback(err);
        } else if (done && running <= 0) {
            done = true;
            callback(null);
        } else if (!looping) {
            replenish();
        }
    }

    function replenish() {
        looping = true;

        while (running < limit && !done) {
            if (++nextIndex === len) {
                done = true;
                if (running <= 0) {
                    callback(null);
                }
                return;
            }

            const key = isArray ? nextIndex : keys[nextIndex];

            const value = obj[key];
            running++;
            iteratee(value, key, onlyOnce(iterateeCallback));
        }

        looping = false;
    }

    replenish();
};

module.exports = eachOfLimit;
