import inherits from "../functions/inherits";
import $ from "%{amd: 'jquery', common: 'jquery', brunch: '!jQuery'}";
import _ from "%{amd: 'lodash', common: 'lodash', brunch: '!_', node: 'lodash'}";
import React from "%{ amd: 'react', common: '!React' }";
import AbstractModelComponent from "./AbstractModelComponent";

const {uniqueId} = _;
const {map} = Array.prototype;

const TRISTATE_CONFIG = {
    get(binding) {
        const value = $(binding._node).find("input[type=radio]:checked").val();

        switch (value) {
            case "1":
            case "true":
            case "on":
            case "yes":
            case "t":
                return true;
            case "0":
            case "false":
            case "off":
            case "no":
            case "f":
                return false;
            default:
                return null;
        }
    },

    setValue(name) {
        return function(value) {
            let checked = false;

            // eslint-disable-next-line no-invalid-this
            this.$el.find("input[type=radio]").each((index, element) => {
                element.setAttribute("name", name);
                if (checked) {
                    return;
                }

                switch (element.value) {
                    case "1":
                    case "true":
                    case "on":
                    case "yes":
                    case "t":
                        checked = value === true;
                        break;
                    case "0":
                    case "false":
                    case "off":
                    case "no":
                    case "f":
                        checked = value === false;
                        break;
                    default:
                        checked = value == null;
                }

                element.checked = checked;
            });
        };
    }
};

const RADIO_CONFIG = {
    get(binding) {
        return $(binding._node).find("input[type=radio]:checked").val();
    },

    setValue(name) {
        return function(value) {
            let selected = false;

            // eslint-disable-next-line no-invalid-this
            this.$el.find("input[type=radio]").each((index, element) => {
                element.setAttribute("name", name);
                if (!selected && element.value === value) {
                    selected = true;
                    element.checked = true;
                }
            });
        };
    }
};

const CHECKBOX_CONFIG = {
    get(binding) {
        return map.call($(binding._node).find("input[type=checkbox]:checked"), element => {
            return element.value;
        });
    },

    setValue(name) {
        return function(value) {
            // eslint-disable-next-line no-invalid-this
            const component = this;

            if (Array.isArray(component.props.value)) {
                value = component.props.value.map(element => {
                    return "" + element;
                });

                component.$el.find("input[type=\"checkbox\"]").each((index, element) => {
                    element.setAttribute("name", name);

                    if (value.indexOf(element.value) !== -1) {
                        element.checked = true;
                    } else {
                        element.checked = false;
                    }
                });
            } else {
                component.$el.find("input[type=\"checkbox\"]").each((index, element) => {
                    element.setAttribute("name", name);

                    if (element.value === value) {
                        element.checked = true;
                    }
                });
            }
        };
    }
};

function InputGroup() {
    this.handleChange = this.handleChange.bind(this);
    InputGroup.__super__.constructor.apply(this, arguments);
}

inherits(InputGroup, AbstractModelComponent);

Object.assign(InputGroup.prototype, {
    uid: `InputGroup${ (String(Math.random())).replace(/\D/g, "") }`,
    configs: {
        trisate: TRISTATE_CONFIG,
        radio: RADIO_CONFIG,
        checkbox: CHECKBOX_CONFIG
    },

    initialize() {
        const props = this.props;
        const name = props.name || uniqueId(`${ this.uid }_`);

        let type;
        if (props.type === "radio" || props.type === "tristate" || props.type === "checkbox") {
            type = props.type;
        } else {
            type = "checkbox";
        }

        this.setValue = this.configs[type].setValue(name);
        this.state = {
            name,
            type
        };
    },

    componentWillUpdate(nextProps, nextState) {
        InputGroup.__super__.componentWillUpdate.apply(this, arguments);
        if (this.props.name !== nextProps.name) {
            nextState.name = nextProps.name || this.state.name;
        }
    },

    componentDidMount() {
        InputGroup.__super__.componentDidMount.apply(this, arguments);
        this.setValue(this.props.value);
    },

    componentDidUpdate(prevProps, prevState) {
        InputGroup.__super__.componentDidUpdate.apply(this, arguments);
        this.setValue(this.props.value);
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
        props.onChange = this.handleChange;

        ["type"].forEach(prop => {
            delete props[prop];
        });

        return React.createElement("div", props);
    }

});

InputGroup.getBinding = function(binding, config) {
    const bconf = this.prototype.configs[config.type];
    binding.get = bconf.get;
    return binding;
};

module.exports = InputGroup;
