import inherits from "../functions/inherits";
import React from "%{ amd: 'react', common: '!React' }";
import AbstractModelComponent from "./AbstractModelComponent";
import InputText from "./InputText";

function InputWithError() {
    InputWithError.__super__.constructor.apply(this, arguments);
}

inherits(InputWithError, AbstractModelComponent);

Object.assign(InputWithError.prototype, {
    uid: `InputWithError${ (String(Math.random())).replace(/\D/g, "") }`,

    _onVStateChange() {
        const {spModel: [model, attr]} = this.props;

        if (model.invalidAttrs && model.invalidAttrs[attr]) {
            this.className = "input--invalid";
            this.isValid = false;
        } else {
            this.className = "";
            this.isValid = true;
        }

        this._updateView();
    },

    getEventArgs(props, state) {
        if (props == null) {
            props = this.props;
        }

        if (state == null) {
            state = this.state;
        }

        const {spModel: [model, attr], deferred} = props;

        if (deferred) {
            return [model];
        }
        return [model, attr];
    },

    attachEvents(model, attr) {
        const events = attr ? `vstate:${ attr }` : "vstate";
        model.on(events, this._onVStateChange, this);
    },

    detachEvents(model, attr) {
        const events = attr ? `vstate:${ attr }` : "vstate";
        model.off(events, this._onVStateChange, this);
    },

    render() {
        const props = Object.assign({}, this.props);

        const {spModel: [model, attr], children, deferred} = props;

        delete props.children;
        delete props.deferred;

        const {className} = this;

        if (className) {
            if (props.className) {
                props.className += ` ${ className }`;
            } else {
                props.className = className;
            }
        }

        const args = [InputText, props];

        if (Array.isArray(children)) {
            args.push(...children);
        } else {
            args.push(children);
        }

        let errors;
        if ((!deferred || this.isValid === false) && model.invalidAttrs && model.invalidAttrs[attr]) {
            errors = <div spRepeat="(message, index) in model.invalidAttrs[attr]" className="error-message" key={ index }>
                { message }
            </div>;
        }

        args.push(<div className="error-messages">
                { errors }
            </div>);

        return React.createElement(...args);
    }
});

InputWithError.getBinding = false;

module.exports = InputWithError;
