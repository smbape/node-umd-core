import inherits from "../functions/inherits";
import React from "%{ amd: 'react', common: '!React' }";
import ReactDOM from "%{ amd: 'react-dom', common: '!ReactDOM' }";
import AbstractModelComponent from "./AbstractModelComponent";
import dialogPolyfill from "../../lib/dialog-polyfill";
import getMatchingCssStyle from "../functions/getMatchingCssStyle";

const testElementStyle = document.createElement("div").style;
const transformJSPropertyName = "transform" in testElementStyle ? "transform" : "webkitTransform";
const transitionJSPropertyName = "transition" in testElementStyle ? "transition" : "webkitTransition";
const CSSMatrix = window.WebKitCSSMatrix;
const { addClass } = AbstractModelComponent.prototype;
const hasProp = Object.prototype.hasOwnProperty;

const EVENTS = [
    // Focus Events
    "blur",
    "focus",

    // CSS Animation Events
    "animationend",
    "animationiteration",
    "animationstart",

    // CSS Transition Events
    "transitionstart",
    "transitionrun",
    "transitionend",
    "transitioncancel",

    // Form Events
    "reset",
    "submit",

    // Text Composition Events
    "componsitionstart",
    "componsitionupdate",
    "componsitionend",

    // View Events
    "scroll",

    // Clipboard Events
    "cut",
    "copy",
    "paste",

    // Keyboard Events
    "keydown",
    "keypress",
    "keyup",

    // Mouse Events
    "mouseenter",
    "mouseover",
    "mousemove",
    "mousedown",
    "mouseup",
    "auxclick",
    "click",
    "dblclick",
    "contextmenu",
    "wheel",
    "mouseleave",
    "mouseout",
    "select",
    "pointerlockchange",
    "pointerlockerror",

    // Drag & Drop Events
    "dragstart",
    "drag",
    "dragend",
    "dragenter",
    "dragover",
    "dragleave",
    "drop",

    // Value change events
    "input",

    // Standard events
    "cancel",
    "change",
    "error",
    "load",
    "pointercancel",
    "pointerdown",
    "pointerenter",
    "pointerleave",
    "pointermove",
    "pointerout",
    "pointerover",
    "pointerup",
    "touchcancel",
    "touchend",
    "touchmove",
    "touchstart",
    "wheel",
];

// Includes all common event props including KeyEvent and MouseEvent specific props
const COMMON_EVENT_PROPS = [
    "altKey",
    "bubbles",
    "cancelable",
    "changedTouches",
    "ctrlKey",
    "detail",
    "eventPhase",
    "metaKey",
    "pageX",
    "pageY",
    "shiftKey",
    "view",
    "char",
    "charCode",
    "key",
    "keyCode",
    "button",
    "buttons",
    "clientX",
    "clientY",
    "offsetX",
    "offsetY",
    "pointerId",
    "pointerType",
    "screenX",
    "screenY",
    "targetTouches",
    "toElement",
    "touches",
];

const createDialog = props => {
    props = Object.assign({}, props);
    const children = props.children;

    delete props.children;
    delete props.spModel;
    delete props.onOpen;
    delete props.onCancel;

    let args;

    if (Array.isArray(children)) {
        args = ["dialog", props].concat(children);
    } else if (children) {
        args = ["dialog", props, children];
    } else {
        args = ["dialog", props];
    }

    addClass(props, "mdl-dialog");
    return React.createElement(...args);
};

const shouldPolyfill = !document.createElement("dialog").showModal;

function Dialog() {
    Dialog.__super__.constructor.apply(this, arguments);
    this.hidden_prop = Math.random().toString(16).slice(2)
}

inherits(Dialog, AbstractModelComponent);

Object.assign(Dialog.prototype, {

    componentDidMount() {
        Dialog.__super__.componentDidMount.apply(this, arguments);

        let el = this.el;

        if (shouldPolyfill) {
            this.dispatchEvent = this._dispatchEvent.bind(this, el);
            const container = el.ownerDocument.createElement("div");
            container.className = "dialog-polyfill-container";
            el.ownerDocument.body.appendChild(container);
            ReactDOM.render(createDialog(this.props), container);
            el = container.firstChild;
            el.setAttribute("dialog-needs-centering", "");
            this.container = container;
            this.el = el;
            this._applyPolyfill(el);
        }

        EVENTS.forEach(type => {
            const prop = `on${ type[0].toUpperCase() }${ type.slice(1) }`;
            this._addEventListener(el, type, this.props[prop]);

            if (shouldPolyfill) {
                el.addEventListener(type, this.dispatchEvent);
            }
        });

        if (this.props.open) {
            el.showModal();
        }
    },

    componentDidUpdate(prevProps, prevState) {
        if (shouldPolyfill) {
            ReactDOM.render(createDialog(this.props), this.container);
            dialogPolyfill.reposition(this.el);
        }

        EVENTS.forEach(type => {
            const prop = `on${ type[0].toUpperCase() }${ type.slice(1) }`;
            if (hasProp.call(this.props, prop)) {
                if (this.props[prop] !== prevProps[prop]) {
                    this._removeEventListener(this.el, type, prevProps[prop]);
                    this._addEventListener(this.el, type, this.props[prop]);
                }
            } else if (prevProps[prop]) {
                this._removeEventListener(this.el, type, prevProps[prop]);
            }
        });
    },

    componentWillUnmout() {
        EVENTS.forEach(type => {
            if (shouldPolyfill) {
                el.removeEventListener(type, this.dispatchEvent);
            }

            const prop = `on${ type[0].toUpperCase() }${ type.slice(1) }`;
            if (hasProp.call(this.props, prop)) {
                this.el.removeEventListener(type, this.props[prop]);
            }
        });

        if (shouldPolyfill) {
            delete this.dispatchEvent;
            delete this.polyfill.setOpen;
            this.polyfill.destroy();
            ReactDOM.unmountComponentAtNode(this.container);
            delete this.container;
        }

        Dialog.__super__.componentWillUnmout.apply(this, arguments);
    },

    _addEventListener(el, type, handler) {
        if (!shouldPolyfill || typeof handler !== "function") {
            return;
        }

        Object.defineProperty(handler, this.hidden_prop, {
            configurable: true,
            enumerable: false,
            writable: true,
            value: evt => {
                evt.ref = this;
                handler.call(null, evt);
            }
        });

        el.addEventListener(type, handler[this.hidden_prop]);
    },

    _removeEventListener(el, type, handler) {
        if (!shouldPolyfill || typeof handler !== "function" || !hasProp.call(handler, this.hidden_prop)) {
            return;
        }

        el.removeEventListener(type, handler[this.hidden_prop]);
        delete handler[this.hidden_prop];
    },

    _dispatchEvent(currentTarget, evt) {
        const props = { ref: this, target: evt.target };
        COMMON_EVENT_PROPS.forEach(prop => {
            if (prop in evt) {
                props[prop] = evt[prop];
            }
        });
        const Ctor = evt.constructor;
        const event = new Ctor(evt.type, props);
        currentTarget.dispatchEvent(event);
    },

    _applyPolyfill(el) {
        const polyfill = dialogPolyfill.registerDialog(el);
        this.polyfill = polyfill;

        const {container} = this;
        const setOpen = polyfill.setOpen;
        polyfill.setOpen = function(value) {
            const {body, documentElement} = el.ownerDocument;
            if (value) {
                container.style[transformJSPropertyName] = "translate3d(0, 0, 0) scale(1)";
            }

            const width = `${ Math.max(body.scrollWidth, documentElement.scrollWidth) }px`;
            const height = `${ Math.max(body.scrollHeight, documentElement.scrollHeight) }px`;

            if (value) {
                [container, this.backdrop_, dialogPolyfill.dm.overlay].forEach(el => {
                    el.style.width = width;
                    el.style.height = height;
                });
            }

            setOpen.call(this, value);

            if (!value) {
                container.style[transformJSPropertyName] = "translate3d(0, 0, 0) scale(0)";
            }
        };

        // polyfill.setOpen = function(value) {
        //     setOpen.call(polyfill, value);

        //     const widthAttributes = ["width", "minWidth", "maxWidth"];
        //     const body = el.ownerDocument.body;

        //     if (!value) {
        //         let parentNode = el.parentNode;

        //         while (parentNode && parentNode !== body) {
        //             const transform = getMatchingCssStyle(parentNode, "transform");

        //             if (transform) {
        //                 if (parentNode.hasAttribute("data-original-zIndex")) {
        //                     const zIndex = parentNode.getAttribute("data-original-zIndex");
        //                     parentNode.removeAttribute("data-original-zIndex");
        //                     parentNode.style.zIndex = zIndex;
        //                 } else {
        //                     parentNode.style.zIndex = "";
        //                 }
        //             }

        //             parentNode = parentNode.parentNode;
        //         }

        //         // transform... creates a new context
        //         // position fixed/z-index are applied relatively to that context
        //         widthAttributes.forEach(prop => {
        //             if (el.hasAttribute(`data-original-${ prop }`)) {
        //                 value = el.getAttribute(`data-original-${ prop }`);
        //                 el.removeAttribute(`data-original-${ prop }`);
        //                 el.style[prop] = value;
        //             } else {
        //                 el.style[prop] = "";
        //             }
        //         });

        //         el.removeAttribute("data-polyfilled");
        //         return;
        //     }

        //     const polyfilled = el.hasAttribute("data-polyfilled");

        //     if (!polyfilled) {
        //         el.setAttribute("data-polyfilled", "1");
        //     }

        //     widthAttributes.forEach(prop => {
        //         if (el.hasAttribute(`data-original-${ prop }`)) {
        //             value = el.getAttribute(`data-original-${ prop }`);
        //         } else {
        //             value = getMatchingCssStyle(el, prop);
        //             if (!polyfilled && el.style[prop]) {
        //                 el.setAttribute(`data-original-${ prop }`, value);
        //             }
        //         }

        //         if (/^\d+(?:.\d+)%$/.test(value)) {
        //             value = parseFloat(value) * window.innerWidth / 100;
        //             el.style[prop] = `${ value }px`;
        //         }
        //     });

        //     let offsetTop = 0;
        //     let offsetLeft = 0;
        //     const zIndex = this.backdrop_.style.zIndex;
        //     let parentNode = el.parentNode;

        //     while (parentNode && parentNode !== body) {
        //         const transform = getMatchingCssStyle(parentNode, "transform");

        //         if (transform) {
        //             offsetLeft -= parentNode.offsetLeft;
        //             offsetTop -= parentNode.offsetTop;

        //             if (CSSMatrix) {
        //                 const matrix = new CSSMatrix(transform);
        //                 offsetLeft -= matrix.m41;
        //                 offsetTop -= matrix.m42;
        //             }
        //         }

        //         if (!polyfilled && parentNode.style) {
        //             parentNode.setAttribute("data-original-zIndex", parentNode.style.zIndex);
        //         }

        //         parentNode.style.zIndex = zIndex;
        //         parentNode = parentNode.parentNode;
        //     }

        //     el.style.position = "fixed";
        //     const windowHeight = window.innerHeight;
        //     const dialogHeight = el.clientHeight;
        //     el.style.top = `${ offsetTop + (windowHeight < dialogHeight ? 0 : windowHeight - dialogHeight) / 2 }px`;
        //     el.style.left = `${ offsetLeft }px`;
        // };
    },

    showModal(options) {
        const el = this.el;

        if (options && options.from) {
            const {target, clientX, clientY} = options.from;
            const tx = clientX - window.innerWidth / 2;
            const ty = clientY - window.innerHeight / 2;
            const sx = target.clientWidth / (el.clientWidth || window.innerWidth);
            const sy = target.clientHeight / (el.clientHeight || window.innerHeight);
            el.style[transitionJSPropertyName] = "initial";
            el.style.opacity = 0.5;
            this.transform = `translate3d( ${ tx }px, ${ ty }px, 0 ) scale( ${ sx }, ${ sy } )`;
            el.style[transformJSPropertyName] = this.transform;
        }

        el.showModal();

        if (options && options.from) {
            el.style[transitionJSPropertyName] = "";
            el.style[transformJSPropertyName] = "";
            el.style.opacity = 1;
        }

        if (this.props.onOpen) {
            this.props.onOpen();
        }
    },

    close(options) {
        const el = this.el;

        if (this.transform) {
            el.style.opacity = 0;
            el.style[transformJSPropertyName] = this.transform;
            this.transform = null;
            setTimeout(() => {
                el.close();
            }, 250);
        } else {
            el.close();
        }
    },

    render() {
        return shouldPolyfill ? <span /> : createDialog(this.props);
    }
});

Dialog.getBinding = binding => binding;

module.exports = Dialog;
