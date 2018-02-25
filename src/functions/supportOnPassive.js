const emptyFn = Function.prototype;
const hasProp = Object.prototype.hasOwnProperty;

// https://github.com/WICG/EventListenerOptions/blob/gh-pages/explainer.md
const supportsPassive = (function() {
    let _supportsPassive = false;

    try {
        window.addEventListener("test", null, Object.defineProperty({}, "passive", {
            // eslint-disable-next-line getter-return
            get() {
                _supportsPassive = true;
            }
        }));
    } catch ( error ) {
        //
    }

    return _supportsPassive;
})();

const captureOptions = supportsPassive ? {
    passive: true
} : false;


const supportOnPassive = (jQuery, name) => {
    if (!captureOptions) {
        return emptyFn;
    }

    if (/\s/.test(name)) {
        const names = name.split(/\s+/g);

        let destroyers = new Array(names.length);

        names.forEach((_name, i) => {
            destroyers[i] = supportOnPassive(jQuery, _name);
        });

        return () => {
            for (let i = destroyers.length - 1; i >= 0; i--) {
                destroyers[i]();
            }

            destroyers = null;
        };
    }

    let special = jQuery.event.special;
    let hasSpecial = false;
    let preSetup, hasPrevSetup;

    if (hasProp.call(special, name)) {
        hasSpecial = true;
        if (hasProp.call(special[name], "setup")) {
            preSetup = special[name].setup;

            if (preSetup.passiveSupported) {
                return emptyFn;
            }

            hasPrevSetup = true;
        }
    } else {
        special[name] = {};
    }

    special[name].setup = function(data, namespaces, eventHandle) {
        this.addEventListener(name, eventHandle, captureOptions);
    };

    const setup = special[name].setup;
    setup.passiveSupported = true;

    return () => {
        if (hasPrevSetup) {
            special[name].setup = preSetup;
            preSetup = null;
        } else if (hasSpecial) {
            delete special[name].setup;
        } else {
            delete special[name].setup;
            delete special[name];
        }

        name = null;
        special = null;
        jQuery = null;
    };
};

module.exports = supportOnPassive;
