import _ from "%{amd: 'lodash', common: 'lodash', brunch: '!_', node: 'lodash'}";
import makeTwoWayBinbing from "../makeTwoWayBinbing";
import componentHandler from "!componentHandler";
import React from "%{ amd: 'react', common: '!React' }";
import AbstractModelComponent from "./ModelComponent";
import MdlComponent from "./MdlComponent";

const {MDL_CLASSES_REG} = MdlComponent;
const {slice} = Array.prototype;

const createElement = React.createElement;

React.createElement = function(type, config) {
    const args = slice.call(arguments);

    if (componentHandler && config && !config.mdlIgnore && "string" === typeof type && MDL_CLASSES_REG.test(config.className)) {
        config = _.defaults({
            tagName: type,
            mdlIgnore: true
        }, config);

        type = MdlComponent;

        args[0] = type;
        args[1] = config;
    }

    if (config && "string" === typeof type) {
        const _config = Object.assign({}, config);
        args[1] = _config;

        delete _config.binding;
        delete _config.mdlIgnore;
        delete _config.spModel;
        delete _config.tagName;
    }

    const element = createElement.apply(React, args);
    makeTwoWayBinbing(element, type, config);
    return element;
};

module.exports = AbstractModelComponent;
