import inherits from "../functions/inherits";
import React from "%{ amd: 'react', common: '!React' }";
import ReactModelView from "../views/ReactModelView";

function ModelListener() {
    ModelListener.__super__.constructor.apply(this, arguments);
}

inherits(ModelListener, ReactModelView);

Object.assign(ModelListener.prototype, {

    componentWillMount() {
        if (this.props.init !== false) {
            const callback = this.props.onEvent;
            this._children = callback.call(this);
        }

        ModelListener.__super__.componentWillMount.apply(this, arguments);
    },

    getEventArgs(props, state) {
        if (props == null) {
            props = this.props;
        }

        if (state == null) {
            state = this.state;
        }

        return [this.getModel(props, state), props.events, props.onEvent];
    },

    attachEvents(model, events, eventCallback) {
        if (model) {
            model.on(events, this._onModelEvent, this);
        }
    },

    detachEvents(model, events, eventCallback) {
        if (model) {
            model.off(events, this._onModelEvent, this);
        }
    },

    _onModelEvent() {
        const callback = this.props.onEvent;
        this._children = callback.apply(this, arguments);
        this._updateView();
    },

    render() {
        if (this.props.bare) {
            return this._children || null;
        }
        return React.createElement(this.props.tagName || "span", this.props, this._children);
    },

});

module.exports = ModelListener;
