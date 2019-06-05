/* eslint-disable no-void */

const hasProp = Object.prototype.hasOwnProperty;

module.exports = function throttle(fn, delay, options) {
    let waiting = false;
    const leading = options && hasProp.call(options, "leading") ? options.leading : true;
    const trailing = options && hasProp.call(options, "trailing") ? options.trailing : true;
    let lastExecution = leading ? Date.now() - delay : 0;

    function throttled() {
        const now = Date.now();
        const wait = lastExecution ? lastExecution + delay - now : delay;

        if (wait <= 0) {
            waiting = false;
            lastExecution = leading ? now : 0;
            fn(...arguments);
            return;
        }

        if (waiting || !trailing) {
            return;
        }

        if (!leading) {
            lastExecution = now;
        }

        waiting = setTimeout(throttled, wait);
    }

    throttled.cancel = function() {
        if (waiting) {
            clearTimeout(waiting);
            waiting = false;
        }
    };

    return throttled;
};
