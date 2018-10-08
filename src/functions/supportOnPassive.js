const emptyFn = Function.prototype;
const hasProp = Object.prototype.hasOwnProperty;

// https://github.com/WICG/EventListenerOptions/blob/gh-pages/explainer.md
const isPassiveEventListenerSupported = () => {
    let supportsPassive = false;

    try {
        window.addEventListener("test", null, Object.defineProperty({}, "passive", {
            // eslint-disable-next-line getter-return
            get() {
                supportsPassive = true;
            }
        }));
    } catch ( error ) {
        /* Nothing to do */
    }

    return supportsPassive;
};

const captureOptions = isPassiveEventListenerSupported() ? {
    passive: true
} : false;

const supportOnPassive = ($, name) => {
    if (!captureOptions) {
        // passive event listener is not supported
        return emptyFn;
    }

    if (/\s/.test(name)) {
        const names = name.split(/\s+/g);
        let destroyers = [];
        const len = names.length;

        for (let j = 0; j < len; j++) {
            name = names[j];
            destroyers.push(supportOnPassive($, name));
        }

        return () => {
            let i = destroyers.length - 1;

            while (i !== -1) {
                destroyers[i]();
                i--;
            }

            destroyers = null;
        };
    }

    let special = $.event.special;
    let hasSpecial = false;
    let prevSetup, hasPrevSetup;

    if (hasProp.call(special, name)) {
        hasSpecial = true;
        if (hasProp.call(special[name], "setup")) {
            prevSetup = special[name].setup;

            if (prevSetup.passiveSupported) {
                // passive event listener with $.fn.on is already enabled
                return emptyFn;
            }

            hasPrevSetup = true;
        }
    } else {
        special[name] = {};
    }

    const setup = function(data, namespaces, eventHandle) {
        // eslint-disable-next-line no-invalid-this
        this.addEventListener(name, eventHandle, captureOptions);
    };

    setup.passiveSupported = true;

    special[name].setup = setup;

    // restore original $.fn.on behaviour
    return () => {
        if (hasPrevSetup) {
            special[name].setup = prevSetup;
            prevSetup = null;
        } else if (hasSpecial) {
            delete special[name].setup;
        } else {
            delete special[name].setup;
            delete special[name];
        }

        name = null;
        special = null;
        $ = null;
    };
};

module.exports = supportOnPassive;
