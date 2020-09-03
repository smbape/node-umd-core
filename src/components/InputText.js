import deepCloneElement from "../functions/deepCloneElement";
import mergeFunctions from "../functions/mergeFunctions";
import _ from "%{amd: 'lodash', common: 'lodash', brunch: '!_', node: 'lodash'}";
import React from "%{ amd: 'react', common: '!React' }";
import AbstractModelComponent from "./AbstractModelComponent";

const {defaults} = _;

const getLength = value => {
    if (value) {
        return value.length;
    }
    return 0;
};

class InputText extends AbstractModelComponent {
    uid = `InputText${ (String(Math.random())).replace(/\D/g, "") }`;

    static getInputValue(input) {
        switch (input.nodeName) {
            case "INPUT":
                if (input.type === "checkbox") {
                    return input.checked;
                }
                return input.value;
            case "TEXTAREA":
            case "SELECT":
            case "OPTION":
            case "BUTTON":
            case "DATALIST":
            case "OUTPUT":
                return input.value;
            default:
                return input.innerHTML;
        }
    }

    // 2 way binbing is done on input, not on this component
    static getBinding(_binding, config) {
        const Constructor = this;

        _binding.get = binding => {
            return binding._ref instanceof Constructor ? Constructor.getInputValue(binding._ref.getInput()) : undefined;
        };

        return _binding;
    }

    preinit(props) {
        this._updateClass = this._updateClass.bind(this);
        this.onBlur = this.onBlur.bind(this);
        this.onFocus = this.onFocus.bind(this);
        this.handleChange = this.handleChange.bind(this);
    }

    initialize(props) {
        this.classList = ["input"];
        if (props.binding != null) {
            props.binding.instance = this;
        }
    }

    componentDidMount() {
        super.componentDidMount();
        this._updateClass();
    }

    componentDidUpdate(prevProps, prevState) {
        super.componentDidUpdate(prevProps, prevState);
        this._updateClass();
    }

    handleChange(evt, ...args) {
        const {onChange} = this.props;
        if (typeof onChange === "function") {
            evt.ref = this;
            onChange(evt, ...args);
        }
    }

    onFocus(evt) {
        this._addClass("input--focused", this.$el, this.classList);
    }

    onBlur(evt) {
        this._removeClass("input--focused", this.$el, this.classList);
    }

    getInput() {
        const input = this.refs.input;
        return typeof input.getInput === "function" ? input.getInput() : input;
    }

    _updateClass() {
        const el = this.getInput();

        if (/^\s*$/.test(InputText.getInputValue(el))) {
            this._removeClass("input--has-value", this.$el, this.classList);
        } else {
            this._addClass("input--has-value", this.$el, this.classList);
        }
    }

    _addClass(className, $el, classList) {
        if (classList.indexOf(className) === -1) {
            classList.push(className);
        }
        return $el.addClass(className);
    }

    _removeClass(className, $el, classList) {
        const index = classList.indexOf(className);
        if (~(index)) {
            classList.splice(index, 1);
        }
        return $el.removeClass(className);
    }

    render() {
        const props = Object.assign({}, this.props);
        const id = props.id || this.id;

        const {children, spModel, style, disabled, onFocus, onBlur} = props;
        let {className, input} = props;
        const {handleChange: onChange} = this;

        ["children", "className", "spModel", "input", "style", "disabled", "onFocus", "onBlur", "onChange"].forEach(prop => {
            delete props[prop];
        });

        if (className) {
            className = `${ this.classList.join(" ") } ${ className }`;
        } else {
            className = this.classList.join(" ");
        }

        const wrapperProps = {
            disabled,
            className,
            style
        };

        let onInputBlur, onInputFocus, onInputChange, type, inputProps, inputChildren;

        if (React.isValidElement(input)) {
            onInputBlur = input.props.onBlur;
            onInputFocus = input.props.onFocus;
            onInputChange = input.props.onChange;

            input = deepCloneElement(input, defaults({
                ref: "input",
                onFocus: mergeFunctions(this.onFocus, onFocus, onInputFocus),
                onBlur: mergeFunctions(this.onBlur, onBlur, onInputBlur),
                onChange: mergeFunctions(this._updateClass, onChange, onInputChange)
            }, input.props, {
                id,
                className: "input__field",
                spModel: null,
                label: null
            }, props));
        } else if (Array.isArray(input)) {
            [type, inputProps, inputChildren] = input;

            onInputBlur = inputProps.onBlur;
            onInputFocus = inputProps.onFocus;
            onInputChange = inputProps.onChange;

            inputProps = defaults({
                ref: "input",
                onFocus: mergeFunctions(this.onFocus, onFocus, onInputFocus),
                onBlur: mergeFunctions(this.onBlur, onBlur, onInputBlur),
                onChange: mergeFunctions(this._updateClass, onChange, onInputChange)
            }, inputProps, {
                id,
                className: "input__field",
                spModel: null,
                label: null
            }, props);

            const args = [type, inputProps];

            if (Array.isArray(inputChildren)) {
                args.push(...inputChildren);
            } else {
                args.push(inputChildren);
            }

            input = React.createElement(...args);
        } else {
            let inputType;

            switch (typeof input) {
                case "string":
                    type = input;
                    inputType = "text";
                    break;
                case "function":
                    type = input;
                    break;
                default:
                    type = "input";
                    inputType = "text";
            }

            inputProps = defaults({
                ref: "input",
                onFocus: mergeFunctions(this.onFocus, onFocus, onInputFocus),
                onBlur: mergeFunctions(this.onBlur, onBlur, onInputBlur),
                onChange: mergeFunctions(this._updateClass, onChange, onInputChange),
                id,
                className: "input__field",
                spModel: null,
                label: null
            }, props, {
                type: inputType
            });

            delete inputProps.charCount;
            input = React.createElement(type, inputProps);
        }

        let label;
        if (props.label) {
            label = (<label className={ "input__label" } htmlFor={ id }>
                <span className={ "input__label-content" }>{ props.label }</span>
            </label>);
        }

        const args = ["span", wrapperProps, input];

        if (props.charCount) {
            args.push(<div className="char-count">
                 { getLength(spModel[0].get(spModel[1])) }/
                 { props.charCount }
             </div>);
        } else {
            args.push(undefined);
        }

        args.push(<span className="input__bar" />);

        if (label) {
            args.push(label);
        } else {
            args.push(undefined);
        }

        if (Array.isArray(children)) {
            args.push(...children);
        } else {
            args.push(children);
        }

        return React.createElement(...args);
    }
}

module.exports = InputText;
