import React from "%{ amd: 'react', brunch: '!React', common: 'react' }";
import ReactModelView from "../views/ReactModelView";

class ModelListener extends ReactModelView {
    uid = `ModelListener${ (String(Math.random())).replace(/\D/g, "") }`;

    preinit(props) {
        super.preinit(props);
        if (props.init !== false) {
            this._children = props.onEvent.call(this);
        }
    }

    getEventArgs(props, state) {
        if (props == null) {
            props = this.props;
        }

        if (state == null) {
            state = this.state;
        }

        return [this.getModel(props, state), props.events, props.onEvent];
    }

    attachEvents(model, events, eventCallback) {
        if (model) {
            model.on(events, this._onModelEvent, this);
        }
    }

    detachEvents(model, events, eventCallback) {
        if (model) {
            model.off(events, this._onModelEvent, this);
        }
    }

    _onModelEvent() {
        this._children = this.props.onEvent.apply(this, arguments);
        this._updateView();
    }

    render() {
        if (this.props.bare) {
            return this._children || null;
        }

        const props = Object.assign({}, this.props);
        delete props.onEvent;
        return React.createElement(this.props.tagName || "span", props, this._children);
    }
}

module.exports = ModelListener;
