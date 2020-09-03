import React from "%{ amd: 'react', brunch: '!React', common: 'react' }";
import _ from "%{amd: 'lodash', brunch: '!_', common: 'lodash', node: 'lodash'}";
import Backbone from "%{amd: 'backbone', brunch: '!Backbone', common: 'backbone', node: 'backbone'}";
import * as DOMUtil from "../util/DOMUtil";
import { loadScript } from "../util/LoaderUtil";
import AbstractModelComponent from "./AbstractModelComponent";

const {map} = _;
const hasProp = Object.prototype.hasOwnProperty;
const emitter = Object.assign({}, Backbone.Events);

let loading = false;
let loaded = false;

function deleteValue(value, stack, only) {
    if (DOMUtil.isNodeOrElement(value)) {
        DOMUtil.discard(value);
        return;
    }

    const type = typeof value;

    if (value !== null && (type === "object" || type === "function")) {
        const len = stack.length;

        for (let i = 0; i < len; i++) {
            if (stack[i] === value) {
                return;
            }
        }

        stack.push(value);
        deepDelete(value, stack, only);
        stack.pop(value);
    }
}

function deepDelete(obj, stack, only) {
    const type = typeof obj;

    if (obj === window || obj === null || (type !== "object" && type !== "function")) {
        return false;
    }

    if (Array.isArray(obj)) {
        const len = obj.length;

        for (let i = 0; i < len; i++) {
            deleteValue(obj[i], stack, only);
        }

        if (only(obj)) {
            obj.length = 0;
        }
    } else {
        let value;
        for (const key in obj) {
            if (!hasProp.call(obj, key)) {
                continue;
            }

            value = obj[key];
            deleteValue(value, stack, only);
            if (only(value, key)) {
                delete obj[key];
            }
        }
    }

    return true;
}

class Recaptcha extends AbstractModelComponent {
    uid = `Recaptcha${ (String(Math.random())).replace(/\D/g, "") }`;

    static init() {
        const app = require("application");

        if (!app) {
            return;
        }

        if (loading) {
            return;
        }

        const lng = app.get("language");
        app.on("change:language", Recaptcha.reset, Recaptcha);

        loading = true;
        loaded = false;

        const callbackId = `onloadCallback_${ Date.now() }`;

        window[callbackId] = function() {
            loading = false;
            loaded = true;
            emitter.trigger("ready");
        };

        loadScript(`https://www.google.com/recaptcha/api.js?onload=${ callbackId }&render=explicit&hl=${ lng }`, {
            async: true,
            defer: true
        });
    }

    static reset() {
        const app = require("application");
        if (!app) {
            return;
        }

        loading = false;
        loaded = false;

        app.off("change:language", Recaptcha.reset, Recaptcha);

        Recaptcha.init();
    }

    static getBinding(_binding) {
        _binding.get = function(binding) {
            return binding._ref instanceof Recaptcha ? window.grecaptcha.getResponse(binding._ref.widgetId) : undefined;
        };

        return _binding;
    }

    componentDidMount() {
        super.componentDidMount(...arguments);
        this.initWidget();
    }

    componentWillUnmount() {
        emitter.off("ready", this._initWidget, this);

        // avoid DOM Leak
        // dirty function while waiting for a proper destroy method from google
        const el = this.el;

        const only = (value, key) => {
            return DOMUtil.isNodeOrElement(value);
        };

        if (window.___grecaptcha_cfg) {
            map(window.___grecaptcha_cfg.clients, (widget, index) => {
                for (const key in widget) {
                    if (!hasProp.call(widget, key)) {
                        continue;
                    }

                    const value = widget[key];
                    if (value === el) {
                        deepDelete(widget, [], only);
                    }
                }
            });
        }

        super.componentWillUnmount(...arguments);
    }

    initWidget() {
        if (loaded) {
            this._initWidget();
        } else {
            emitter.once("ready", this._initWidget, this);
            Recaptcha.init();
        }
    }

    _initWidget() {
        if (this.el) {
            const options = _.pick(this.props, ["sitekey", "theme", "type", "size", "tabindex", "expired-callback"]);
            const onChange = this.props.onChange;

            if ("function" === typeof onChange) {
                options.callback = response => {
                    onChange({
                        ref: this
                    }, response);
                };
            }

            this.widgetId = window.grecaptcha.render(this.el, options);
        }
    }

    render() {
        return <span className="clearfix" />;
    }
}

module.exports = Recaptcha;
