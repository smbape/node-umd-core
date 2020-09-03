import React from "%{ amd: 'react', brunch: '!React', common: 'react' }";
import $ from "%{amd: 'jquery', brunch: '!jQuery', common: 'jquery'}";
import componentHandler from "!componentHandler";
import AbstractModelComponent from "./ModelComponent";

const MDL_CLASSES = [
    "mdl-js-button",
    "mdl-js-checkbox",
    "mdl-js-icon-toggle",
    "mdl-js-menu",
    "mdl-js-progress",
    "mdl-js-radio",
    "mdl-js-slider",
    "mdl-js-snackbar",
    "mdl-js-spinner",
    "mdl-js-switch",
    "mdl-js-tabs",
    "mdl-js-textfield",
    "mdl-tooltip",
    "mdl-js-layout",
    "mdl-js-data-table",
    "mdl-js-ripple-effect"
];

const MDL_CLASSES_REG = new RegExp(`(?:^|\\s)(?:${ MDL_CLASSES.join("|") })(?:\\s|$)`);

class MdlComponent extends AbstractModelComponent {
    uid = `MdlComponent${ (String(Math.random())).replace(/\D/g, "") }`;

    static MDL_CLASSES = MDL_CLASSES;
    static MDL_CLASSES_REG = MDL_CLASSES_REG;

    static getBinding(_binding, config) {
        if (config.tagName === "input" && config.type === "checkbox") {
            _binding.get = function(binding, evt) {
                return $(evt.target).prop("checked");
            };
        } else {
            _binding.get = function(binding, evt) {
                return $(evt.target).val();
            };
        }
        return _binding;
    }

    preinit() {
        this.handleChange = this.handleChange.bind(this);
    }

    componentDidMount() {
        super.componentDidMount(...arguments);
        this.upgradeElements(this.el);
    }

    componentWillUnmount() {
        this.downgradeElements(this.el);
        super.componentWillUnmount(...arguments);
    }

    upgradeElements(el) {
        if (el.hasAttribute("data-mdl-delegate-upgrade")) {
            return;
        }

        if (el.getAttribute("data-upgraded") === null && MDL_CLASSES_REG.test(el.className)) {
            componentHandler.upgradeElement(el);
        }

        const children = el.children;
        const len = children ? children.length : 0;

        for (let i = 0, child; i < len; i++) {
            child = children[i];
            this.upgradeElements(child);
        }
    }

    downgradeElements(el) {
        if (el.hasAttribute("data-mdl-delegate-upgrade")) {
            return;
        }

        const children = el.children;
        const len = children ? children.length : 0;

        for (let i = 0, child; i < len; i++) {
            child = children[i];
            this.downgradeElements(child);
        }

        if (MDL_CLASSES_REG.test(el.className) && el.getAttribute("data-upgraded") !== null) {
            componentHandler.downgradeElements([el]);
        }
    }

    handleChange(evt) {
        evt.ref = this;
        const {onChange} = this.props;
        if (typeof onChange === "function") {
            onChange.apply(null, arguments);
        }
    }

    render() {
        const props = Object.assign({}, this.props);
        props.onChange = this.handleChange;
        const tagName = props.tagName || "span";
        delete props.tagName;
        return React.createElement(tagName, props);
    }
}

module.exports = MdlComponent;
