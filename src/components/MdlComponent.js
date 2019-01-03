import inherits from "../functions/inherits";
import AbstractModelComponent from "./ModelComponent";
import $ from "%{amd: 'jquery', common: 'jquery', brunch: '!jQuery'}";
import React from "%{ amd: 'react', common: '!React' }";
import componentHandler from "!componentHandler";

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

function MdlComponent() {
    this.handleChange = this.handleChange.bind(this);
    return MdlComponent.__super__.constructor.apply(this, arguments);
}

inherits(MdlComponent, AbstractModelComponent);

MdlComponent.prototype.componentDidMount = function() {
    MdlComponent.__super__.componentDidMount.apply(this, arguments);
    this.upgradeElements(this.el);
};

MdlComponent.prototype.componentWillUnmount = function() {
    this.downgradeElements(this.el);
    MdlComponent.__super__.componentWillUnmount.apply(this, arguments);
};

MdlComponent.prototype.upgradeElements = function(el) {
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
};

MdlComponent.prototype.downgradeElements = function(el) {
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
};

MdlComponent.prototype.handleChange = function(evt) {
    evt.ref = this;
    const onChange = this.props.onChange;
    if ("function" === typeof onChange) {
        onChange(...arguments);
    }
};

MdlComponent.prototype.render = function() {
    const props = Object.assign({}, this.props);
    props.onChange = this.handleChange;
    const tagName = props.tagName || "span";
    delete props.tagName;
    return React.createElement(tagName, props);
};

MdlComponent.getBinding = function(_binding, config) {
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
};

MdlComponent.MDL_CLASSES = MDL_CLASSES;
MdlComponent.MDL_CLASSES_REG = MDL_CLASSES_REG;

module.exports = MdlComponent;
