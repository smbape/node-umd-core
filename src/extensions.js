import inherits from "./functions/inherits";
import $ from "%{amd: 'jquery', common: 'jquery', brunch: '!jQuery'}";
import { discard } from "./util/DOMUtil";
import supportOnPassive from "./functions/supportOnPassive";

const hasProp = Object.prototype.hasOwnProperty;

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/assign#Polyfill
if (typeof Object.assign !== "function") {
    Object.assign = function(target) {
        "use strict";
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

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/startsWith#Polyfill
if (!String.prototype.startsWith) {
    String.prototype.startsWith = function(searchString, position) {
        return this.substr(!position || position < 0 ? 0 : +position, searchString.length) === searchString;
    };
}

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/endsWith#Polyfill
if (!String.prototype.endsWith) {
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
            // eslint-disable-next-line guard-for-in
            for (const name in HANDLED_EVENTS) {
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

    function DelegatedMaterialRipple() {
        DelegatedMaterialRipple.__super__.constructor.apply(this, arguments);
    }

    inherits(DelegatedMaterialRipple, MaterialRipple);

    Object.assign(DelegatedMaterialRipple.prototype, {

        init() {
            DelegatedMaterialRipple.__super__.init.apply(this, arguments);
            delete this.animFrameHandler;
        },

        animFrameHandler() {
            if (this.destroyed) {
                return;
            }

            if (this.frameCount_-- > 0) {
                window.requestAnimationFrame(this.animFrameHandler.bind(this));
            } else {
                this.setRippleStyles(false);
            }
        },

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
        },

        downHandler_(evt) {
            if (!shouldHandleEvent(evt)) {
                return;
            }
            DelegatedMaterialRipple.__super__.downHandler_.apply(this, arguments);
        }

    });

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

        // eslint-disable-next-line guard-for-in
        for (const prop in evt.originalEvent) {
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
