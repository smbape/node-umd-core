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

class InputGroup extends AbstractModelComponent {
    uid = `InputGroup${ (String(Math.random())).replace(/\D/g, "") }`;

    static configs = {
        trisate: TRISTATE_CONFIG,
        radio: RADIO_CONFIG,
        checkbox: CHECKBOX_CONFIG
    };

    static getDerivedStateFromProps(props, state) {
        const name = props.name || uniqueId(`${ this.prototype.uid }_`);

        let type;
        if (props.type === "radio" || props.type === "tristate" || props.type === "checkbox") {
            type = props.type;
        } else {
            type = "checkbox";
        }

        return {
            name,
            type,
            setValue: this.configs[type].setValue(name)
        };
    }

    static getBinding(binding, config) {
        const bconf = this.configs[config.type];
        binding.get = bconf.get;
        return binding;
    }

    preinit(props) {
        this.handleChange = this.handleChange.bind(this);
    }

    componentDidMount() {
        super.componentDidMount(...arguments);
        this.state.setValue(this.props.value);
    }

    componentDidUpdate(prevProps, prevState) {
        super.componentDidUpdate(...arguments);
        this.state.setValue(this.props.value);
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

        ["type"].forEach(prop => {
            delete props[prop];
        });

        return React.createElement("div", props);
    }
}

module.exports = InputGroup;
