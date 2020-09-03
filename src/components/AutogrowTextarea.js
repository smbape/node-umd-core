import mergeFunctions from "../functions/mergeFunctions";
import _ from "%{amd: 'lodash', common: 'lodash', brunch: '!_', node: 'lodash'}";
import React from "%{ amd: 'react', common: '!React' }";
import AbstractModelComponent from "./AbstractModelComponent";

const {escape: _escape} = _;

class AutogrowTextarea extends AbstractModelComponent {
    uid = `AutogrowTextarea${ (String(Math.random())).replace(/\D/g, "") }`;

    preinit() {
        this._updateHeight = this._updateHeight.bind(this);
    }

    getInput() {
        return this.getRef("input");
    }

    _updateHeight() {
        this.refs.textareaSize.innerHTML = `${ _escape(this.getRef("input").value) }\n`;
    }

    componentDidMount() {
        super.componentDidMount(...arguments);
        this._updateHeight();
    }

    componentDidUpdate(prevProps, prevState) {
        super.componentDidUpdate(prevProps, prevState);
        this._updateHeight();
    }

    render() {
        let onInput;

        if (this.props.spModel) {
            onInput = this.props.onInput;
        } else {
            onInput = mergeFunctions(this._updateHeight, this.props.onInput);
        }

        const props = Object.assign({}, this.props, {
            ref: this.setRef("input"),
            onInput
        });

        return (<div className="textarea-container">
              { React.createElement("textarea", props) }
              <div ref="textareaSize" className="textarea-size" />
          </div>);
    }
}

module.exports = AutogrowTextarea;
