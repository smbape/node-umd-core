import inherits from "../functions/inherits";
import React from "%{ amd: 'react', common: '!React' }";
import AbstractModelComponent from "./AbstractModelComponent";
import dialogPolyfill from "../../lib/dialog-polyfill";
import getMatchingCssStyle from "../functions/getMatchingCssStyle";

const testElementStyle = document.createElement("div").style;
const transformJSPropertyName = "transform" in testElementStyle ? "transform" : "webkitTransform";
const transitionJSPropertyName = "transition" in testElementStyle ? "transition" : "webkitTransition";
const CSSMatrix = window.WebKitCSSMatrix;

function Dialog() {
    this.handleChange = this.handleChange.bind(this);
    Dialog.__super__.constructor.apply(this, arguments);
}

inherits(Dialog, AbstractModelComponent);

Object.assign(Dialog.prototype, {

    componentDidMount() {
        Dialog.__super__.componentDidMount.apply(this, arguments);

        const el = this.el;

        if (el.tagName === "DIALOG" && !el.showModal) {
            this._applyPolyfill(el);
        }

        if (this.props.onCancel) {
            el.addEventListener("cancel", this.props.onCancel, true);
        }

        if (this.props.open) {
            el.showModal();
        }
    },

    _applyPolyfill(el) {
        const polyfill = dialogPolyfill.registerDialog(el);
        this.polyfill = polyfill;

        const setOpen = polyfill.setOpen;

        polyfill.setOpen = function(value) {
            setOpen.call(polyfill, value);

            const widthAttributes = ["width", "minWidth", "maxWidth"];
            const body = el.ownerDocument.body;

            if (!value) {
                let parentNode = el.parentNode;

                while (parentNode && parentNode !== body) {
                    const transform = getMatchingCssStyle(parentNode, "transform");

                    if (transform) {
                        if (parentNode.hasAttribute("data-original-zIndex")) {
                            const zIndex = parentNode.getAttribute("data-original-zIndex");
                            parentNode.removeAttribute("data-original-zIndex");
                            parentNode.style.zIndex = zIndex;
                        } else {
                            parentNode.style.zIndex = "";
                        }
                    }

                    parentNode = parentNode.parentNode;
                }

                // transform... creates a new context
                // position fixed/z-index are applied relatively to that context
                widthAttributes.forEach(prop => {
                    if (el.hasAttribute(`data-original-${ prop }`)) {
                        value = el.getAttribute(`data-original-${ prop }`);
                        el.removeAttribute(`data-original-${ prop }`);
                        el.style[prop] = value;
                    } else {
                        el.style[prop] = "";
                    }
                });

                el.removeAttribute("data-polyfilled");
                return;
            }

            const polyfilled = el.hasAttribute("data-polyfilled");

            if (!polyfilled) {
                el.setAttribute("data-polyfilled", "1");
            }

            widthAttributes.forEach(prop => {
                if (el.hasAttribute(`data-original-${ prop }`)) {
                    value = el.getAttribute(`data-original-${ prop }`);
                } else {
                    value = getMatchingCssStyle(el, prop);
                    if (!polyfilled && el.style[prop]) {
                        el.setAttribute(`data-original-${ prop }`, value);
                    }
                }

                if (/^\d+(?:.\d+)%$/.test(value)) {
                    value = parseFloat(value) * window.innerWidth / 100;
                    el.style[prop] = `${ value }px`;
                }
            });

            let offsetTop = 0;
            let offsetLeft = 0;
            const zIndex = this.backdrop_.style.zIndex;
            let parentNode = el.parentNode;

            while (parentNode && parentNode !== body) {
                const transform = getMatchingCssStyle(parentNode, "transform");

                if (transform) {
                    offsetLeft -= parentNode.offsetLeft;
                    offsetTop -= parentNode.offsetTop;

                    if (CSSMatrix) {
                        const matrix = new CSSMatrix(transform);
                        offsetLeft -= matrix.m41;
                        offsetTop -= matrix.m42;
                    }
                }

                if (!polyfilled && parentNode.style) {
                    parentNode.setAttribute("data-original-zIndex", parentNode.style.zIndex);
                }

                parentNode.style.zIndex = zIndex;
                parentNode = parentNode.parentNode;
            }

            el.style.position = "fixed";
            const windowHeight = window.innerHeight;
            const dialogHeight = el.clientHeight;
            el.style.top = `${ offsetTop + (windowHeight < dialogHeight ? 0 : windowHeight - dialogHeight) / 2 }px`;
            el.style.left = `${ offsetLeft }px`;
        };
    },

    componentWillUnmout() {
        if (this.props.onCancel) {
            this.el.removeEventListener("cancel", this.props.onCancel, true);
        }

        if (this.polyfill) {
            delete this.polyfill.setOpen;
            this.polyfill.destroy();
        }

        Dialog.__super__.componentWillUnmout.apply(this, arguments);
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

    handleChange(evt) {
        evt.ref = this;
        const onChange = this.props.onChange;
        if ("function" === typeof onChange) {
            onChange(...arguments);
        }
    },

    render() {
        const props = Object.assign({}, this.props);
        const children = props.children;

        props.onChange = this.handleChange;

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

        this.addClass(props, "mdl-dialog");
        return React.createElement(...args);
    }
});

Dialog.getBinding = binding => binding;

module.exports = Dialog;
