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

const supportOnPassive = isPassiveEventListenerSupported() ? ($, name) => {
    if (/\s/.test(name)) {
        const names = name.split(/\s+/g);
        const destroyers = [];
        const len = names.length;

        for (let j = 0; j < len; j++) {
            name = names[j];
            destroyers.push(supportOnPassive($, name));
        }

        return () => {
            let i = destroyers.length - 1;

            while (i !== -1) {
                destroyers[i--]();
            }

            destroyers.length = 0;
        };
    }

    let special = $.event.special;
    let hasSpecial = false;

    if (hasProp.call(special, name)) {
        hasSpecial = true;
        if (hasProp.call(special[name], "setup")) {
            // a previous setup exists and is most likely either a fix or an already passive support
            return emptyFn;
        }
    } else {
        special[name] = {};
    }

    special[name].setup = function(data, namespaces, eventHandle) {
        // eslint-disable-next-line no-invalid-this
        this.addEventListener(name, eventHandle, {
            passive: true
        });
    };

    // https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/removeEventListener#Matching_event_listeners_for_removal
    // Only the capture flag is used when matching event listeners for removal
    // Therefore, events registered with passive flag will still be removed when performing elem.removeEventListener( type, handle );
    // Therefore, the default jQuery.removeEvent which performs elem.removeEventListener( type, handle ); doesn't need to be altered
    // Therefore, a teardown is not needed
    // Therefore there is no need to call supportOnPassive before removing event listeners

    // restore the original $.fn.on behaviour
    return () => {
        delete special[name].setup;
        if (!hasSpecial) {
            delete special[name];
        }

        name = null;
        special = null;
        $ = null;
    };
} : () => {
    return emptyFn;
};

module.exports = supportOnPassive;
