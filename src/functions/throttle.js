function factory() {
    var hasProp = Object.prototype.hasOwnProperty;

    return function throttle(fn, delay, options) {
        var waiting = false;
        var leading = options && hasProp.call(options, "leading") ? options.leading : true;
        var trailing = options && hasProp.call(options, "trailing") ? options.trailing : true;
        var lastExecution = leading ? new Date().getTime() - delay : 0;

        function throttled() {
            var now = new Date().getTime();
            var wait = lastExecution ? lastExecution + delay - now : delay;

            if (wait <= 0) {
                waiting = false;
                lastExecution = leading ? now : 0;
                return fn.apply(this, arguments);
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
}