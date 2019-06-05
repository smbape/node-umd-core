/* eslint no-shadow: ["error", { "allow": ["Element"] }] */

import React from "%{ amd: 'react', brunch: '!React', common: 'react' }";
import ReactDOM from "%{ amd: 'react-dom', brunch: '!ReactDOM', common: 'react-dom' }";
import Backbone from "%{amd: 'backbone', brunch: '!Backbone', common: 'backbone', node: 'backbone'}";
import AbstractModelComponent from "../components/AbstractModelComponent";
import inherits from "../functions/inherits";

const {hasOwnProperty: hasProp} = Object.prototype;

const emptyObject = obj => {
    for (const prop in obj) {
        if (hasProp.call(obj, prop)) {
            delete obj[prop];
        }
    }
};

function ReactModelView(props) {
    ReactModelView.__super__.constructor.apply(this, arguments);
    this._options = Object.assign({}, props);
    if (this.props.mediator) {
        this.props.mediator.trigger("instance", this);
    }
}

inherits(ReactModelView, AbstractModelComponent);

Object.assign(ReactModelView.prototype, {
    uid: `ReactModelView${ (`${ Math.random() }`).replace(/\D/g, "") }`,

    getModel(props, state) {
        if (typeof props === "undefined") {
            props = this.props;
        }
        if (typeof state === "undefined") {
            state = this.state;
        }
        return props.model;
    },

    componentDidMount() {
        ReactModelView.__super__.componentDidMount.apply(this, arguments);
        if (this.props.mediator) {
            this.props.mediator.trigger("mount", this);
        }
    },

    getEventArgs(props, state) {
        if (typeof props === "undefined") {
            props = this.props;
        }
        if (typeof state === "undefined") {
            state = this.state;
        }
        return [this.getModel(props, state)];
    },

    attachEvents(model, attr) {
        if (model) {
            model.on("change", this.onModelChange, this);
        }
    },

    detachEvents(model, attr) {
        if (model) {
            model.off("change", this.onModelChange, this);
        }
    },

    onModelChange() {
        const options = arguments[arguments.length - 1];
        if (options.bubble > 0) {
            // ignore bubbled events
            return;
        }
        this._updateView();
    },

    destroy() {
        if (this.destroyed) {
            return;
        }

        const {container, mediator} = this._options;

        if (container) {
            ReactDOM.unmountComponentAtNode(container);
        }

        if (mediator) {
            mediator.trigger("destroy", this);
        }

        emptyObject(this);
        this.destroyed = true;
    }
});

class Element {
    constructor(Component, props) {
        const mediator = Object.assign({}, Backbone.Events);
        this.props = Object.assign({
            mediator
        }, props);

        const {container} = this.props;
        if (!container) {
            throw new Error("container must be defined");
        }

        this._internal = React.createElement(Component, this.props);
    }

    render(done) {
        const element = this;
        const {container, mediator} = this.props;
        if (typeof done === "function") {
            mediator.once("mount", () => {
                setTimeout(() => {
                    done(null, element);
                }, 0);
            });
        }

        mediator.once("instance", component => {
            element._component = component;
        });

        mediator.once("destroy", () => {
            mediator.off("mount");
            emptyObject(element);
            emptyObject(mediator);
        });

        ReactDOM.render(element._internal, container);
    }

    destroy() {
        if (this._component) {
            this._component.destroy();
            this._component = null;
        }
    }
}

ReactModelView.createElement = function(props) {
    return new Element(this, props);
};

module.exports = ReactModelView;
