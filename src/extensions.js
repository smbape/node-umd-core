import $ from "%{amd: 'jquery', brunch: '!jQuery', common: 'jquery'}";
import { discard } from "./util/DOMUtil";
import supportOnPassive from "./functions/supportOnPassive";

const {hasOwnProperty: hasProp} = Object.prototype;

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/assign#Polyfill
if (typeof Object.assign !== "function") {
    Object.assign = function(target) {
        if (target == null) { // TypeError if undefined or null
            throw new TypeError("Cannot convert undefined or null to object");
        }

        const to = Object(target);
        const len = arguments.length;

        for (let i = 1; i < len; i++) {
            const nextSource = arguments[i];

            if (nextSource != null) { // Skip over if undefined or null
                for (const nextKey in nextSource) {
                    // Avoid bugs when hasOwnProperty is shadowed
                    if (hasProp.call(nextSource, nextKey)) {
                        to[nextKey] = nextSource[nextKey];
                    }
                }
            }
        }
        return to;
    };
}

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/repeat#Polyfill
// https://www.rosettacode.org/wiki/Ethiopian_multiplication#JavaScript
if (!String.prototype.repeat) {
    // eslint-disable-next-line no-extend-native
    String.prototype.repeat = function(count) {
        // known faster way to convert to number particularly on IE11 and Firefox
        // https://jsperf.com/parse-vs-plus/10
        count |= 0;

        if (count < 0) {
            throw new RangeError("Invalid count value");
        }

        let str = '' + this;
        const len = str.length;

        // avoid unecessary computation when string is empty
        if (len === 0 || count === 0) {
            return "";
        }

        // tests on chrome 72 throw this error if total lengh exceeds 0x4FFFFFFF
        if (len * count >= 0x4FFFFFFF) { // eslint-disable-line no-magic-numbers
            throw new RangeError("Invalid string length");
        }

        let res = "";

        while (count > 1) {
            if (count & 1) {
                res += str; // 3. integer odd/even? (bit-wise and 1)
            }
            count >>>= 1;   // 1. integer halved (by right-shift)
            str += str;     // 2. integer doubled (addition to self)
        }

        return res + str;
    };
}

// https://github.com/uxitten/polyfill/blob/master/string.polyfill.js
// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/padStart#Polyfill
if (!String.prototype.padStart) {
    // eslint-disable-next-line no-extend-native
    String.prototype.padStart = function padStart(targetLength, padString) {
        targetLength >>= 0; //truncate if number, or convert non-number to 0;
        padString = "" + (typeof padString !== "undefined" ? padString : " ");
        if (this.length >= targetLength) {
            return "" + this;
        }
        targetLength -= this.length;
        if (targetLength > padString.length) {
            padString += padString.repeat(targetLength / padString.length); //append to original to ensure we are longer than needed
        }
        return padString.slice(0, targetLength) + this;
    };
}

// https://github.com/uxitten/polyfill/blob/master/string.polyfill.js
// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/padEnd#Polyfill
if (!String.prototype.padEnd) {
    // eslint-disable-next-line no-extend-native
    String.prototype.padEnd = function padEnd(targetLength, padString) {
        targetLength >>= 0; //floor if number or convert non-number to 0;
        padString = "" + (typeof padString !== "undefined" ? padString : " ");
        if (this.length > targetLength) {
            return "" + this;
        }
        targetLength -= this.length;
        if (targetLength > padString.length) {
            padString += padString.repeat(targetLength / padString.length); //append to original to ensure we are longer than needed
        }
        return this + padString.slice(0, targetLength);
    };
}

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/startsWith#Polyfill
if (!String.prototype.startsWith) {
    // eslint-disable-next-line no-extend-native
    String.prototype.startsWith = function(searchString, position) {
        return this.substr(!position || position < 0 ? 0 : +position, searchString.length) === searchString;
    };
}

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/endsWith#Polyfill
if (!String.prototype.endsWith) {
    // eslint-disable-next-line no-extend-native
    String.prototype.endsWith = function(searchString, length) {
        if (length === undefined || length > this.length) {
            length = this.length;
        }
        return this.substring(length - searchString.length, length) === searchString;
    };
}

$.fn.destroy = function(selector) {
    const el = this.remove();

    let i = 0;
    let elem;

    while ((elem = this[i]) != null) {
        discard(elem);
        i++;
    }

    return el;
};

$.fn.insertAt = function(index, elements) {
    /* eslint-disable no-invalid-this */
    return this.domManip([elements], function(elem) {
        if (this.children) {
            if (this.children.length < index) {
                this.appendChild(elem);
            } else if (index < 0) {
                this.insertBefore(elem, this.firstChild);
            } else {
                this.insertBefore(elem, this.children[index]);
            }
        } else {
            this.appendChild(elem);
        }
    });
/* eslint-enable no-invalid-this */
};

let {requestAnimationFrame} = window;

if (!requestAnimationFrame) {
    const vendors = ["ms", "moz", "webkit", "o"];
    const len = vendors.length;

    for (let i = 0, prefix; i < len; i++) {
        prefix = vendors[i];
        requestAnimationFrame = window[`${ prefix }RequestAnimationFrame`];
        if (requestAnimationFrame) {
            break;
        }
    }
}

(function delegateMaterialRipple(MaterialRipple) {
    if (!MaterialRipple || typeof $.fn.on !== "function") {
        return;
    }

    const HANDLED_EVENTS = {
        touch: /^touch/,
        mouse: /^mouse/
    };

    let HANDLED_EVENT = null;

    const shouldHandleEvent = evt => {
        const {type} = evt;
        if (!/^(?:touch|mouse)/.test(type)) {
            return true;
        }

        if (!HANDLED_EVENT) {
            for (const name in HANDLED_EVENTS) { // eslint-disable-line guard-for-in
                const reg = HANDLED_EVENTS[name];
                if (reg.test(type)) {
                    HANDLED_EVENT = reg;
                    return true;
                }
            }
            return true;
        }

        return HANDLED_EVENT.test(type);
    };

    class DelegatedMaterialRipple extends MaterialRipple {
        init() {
            super.init(...arguments);
            delete this.animFrameHandler;
        }

        animFrameHandler() {
            if (this.destroyed) {
                return;
            }

            if (this.frameCount_-- > 0) {
                window.requestAnimationFrame(this.animFrameHandler.bind(this));
            } else {
                this.setRippleStyles(false);
            }
        }

        upHandler_(evt) {
            if (!shouldHandleEvent(evt)) {
                return;
            }

            if (evt && evt.detail !== 2) {
                setTimeout(() => {
                    if (this.destroyed) {
                        return;
                    }

                    this.rippleElement_.classList.remove(this.CssClasses_.IS_VISIBLE);
                    $.removeData(this.element_, "ripple");

                    for (const prop in this) {
                        if (!hasProp.call(this, prop)) {
                            continue;
                        }
                        delete this[prop];
                    }

                    this.destroyed = true;
                }, 0);
            }
        }

        downHandler_(evt) {
            if (!shouldHandleEvent(evt)) {
                return;
            }
            super.downHandler_(...arguments);
        }
    }

    const rippleEvents = "mousedown touchstart mouseup mouseleave touchend blur";
    const restore = supportOnPassive($, rippleEvents);

    $(document).on(rippleEvents, ".mdl-js-ripple-effect:not([data-upgraded]):not(.mdl-js-ripple-effect--ignore-events)", evt => {
        if (!shouldHandleEvent(evt)) {
            return;
        }

        const element_ = evt.currentTarget;
        let ripple = $.data(element_, "ripple");

        if (!ripple) {
            ripple = new DelegatedMaterialRipple(element_);
            ripple.element_.removeEventListener("mousedown", ripple.boundDownHandler);
            ripple.element_.removeEventListener("touchstart", ripple.boundDownHandler);
            ripple.element_.removeEventListener("mouseup", ripple.boundUpHandler);
            ripple.element_.removeEventListener("mouseleave", ripple.boundUpHandler);
            ripple.element_.removeEventListener("touchend", ripple.boundUpHandler);
            ripple.element_.removeEventListener("blur", ripple.boundUpHandler);
            $.data(element_, "ripple", ripple);
        }

        if (!(ripple instanceof DelegatedMaterialRipple)) {
            return;
        }

        const overridedEvt = {};

        for (const prop in evt.originalEvent) { // eslint-disable-line guard-for-in
            overridedEvt[prop] = evt.originalEvent[prop];
        }

        overridedEvt.currentTarget = element_;

        const {type} = evt;
        if ((type) === "mousedown" || type === "touchstart") {
            ripple.downHandler_(overridedEvt);
        } else {
            ripple.upHandler_(overridedEvt);
        }
    });

    restore();
})(window.MaterialRipple);

// module.exports = Symbol("extensions");
