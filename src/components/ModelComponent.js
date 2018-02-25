import inherits from "../functions/inherits";
import $ from "%{amd: 'jquery', common: 'jquery', brunch: '!jQuery'}";
import _ from "%{amd: 'lodash', common: 'lodash', brunch: '!_', node: 'lodash'}";
import Backbone from "%{amd: 'backbone', common: 'backbone', brunch: '!Backbone', node: 'backbone'}";
import React from "%{ amd: 'react', common: '!React' }";
import ReactDOM from "%{ amd: 'react-dom', common: '!ReactDOM' }";

const randomString = () => Math.random().toString(36).slice(2);
const hasProp = Object.prototype.hasOwnProperty;
const expando = React.expando || (React.expando = randomString());

function ModelComponent() {
    this.destroy = this.destroy.bind(this);
    ModelComponent.__super__.constructor.apply(this, arguments);
    this.id = _.uniqueId(`${ this.constructor.name || "ModelComponent" }_`);
    this.inline = new Backbone.Model();
    this._refs = {};
    this._reffn = {};
    this.initialize();
}

inherits(ModelComponent, React.Component);

Object.assign(ModelComponent.prototype, {
    uid: `ModelComponent${ randomString() }`,

    setRef(name) {
        if ("string" !== typeof name || name.length === 0) {
            return undefined;
        }

        if (hasProp.call(this._reffn, name)) {
            return this._reffn[name];
        }

       this._reffn[name] = ref => {
            if (this._refs) {
                this._refs[name] = ref;
            }
        };

        return this._reffn[name];
    },

    getRef(name) {
        if (hasProp.call(this._refs, name)) {
            return this._refs[name];
        }
        return this.refs[name];
    },

    // eslint-disable-next-line no-empty-function
    initialize() {},

    // eslint-disable-next-line no-empty-function
    componentWillMount() {},

    componentDidMount() {
        this.el = ReactDOM.findDOMNode(this);
        this.$el = $(this.el);
        this.attachEvents.apply(this, this.getEventArgs());
    },

    // eslint-disable-next-line no-empty-function
    componentWillReceiveProps(nextProps) {},

    shouldComponentUpdate(nextProps, nextState) {
        this.shouldUpdate = this.shouldUpdate || !_.isEqual(this.state, nextState) || !_.isEqual(this.props, nextProps);
        this.shouldUpdateEvent = this.shouldUpdateEvent || this.shouldComponentUpdateEvent(nextProps, nextState);
        return this.shouldUpdate || this.shouldUpdateEvent;
    },

    shouldComponentUpdateEvent(nextProps, nextState) {
        const nextEventArgs = this[typeof this.getNewEventArgs === "function" ? "getNewEventArgs" : "getEventArgs"](nextProps, nextState);
        const prevEventArgs = this.getEventArgs();
        return !_.isEqual(nextEventArgs, prevEventArgs);
    },

    componentWillUpdate(nextProps, nextState) {
        if (this.shouldUpdateEvent) {
            const prevEventArgs = this.getEventArgs();
            prevEventArgs.push(...[nextProps, nextState]);
            this.detachEvents(...prevEventArgs);

            const nextEventArgs = this[typeof this.getNewEventArgs === "function" ? "getNewEventArgs" : "getEventArgs"](nextProps, nextState);
            nextEventArgs.push(...[nextProps, nextState]);
            this.attachEvents(...nextEventArgs);
        }

        this.shouldUpdate = false;
        this.shouldUpdateEvent = false;
    },

    componentDidUpdate(prevProps, prevState) {
        this._updating = false;
    },

    componentWillUnmount() {
        if (this._bindings) {
            this._bindings.forEach(binding => {
                binding._detach(binding);

                for (const key in binding) {
                    if (!hasProp.call(binding, key)) {
                        continue;
                    }
                    delete binding[key];
                }
            });
        }

        ["_previousAttributes", "attributes", "changed"].forEach(name => {
            const attributes = this.inline[name];

            for (const key in attributes) {
                if (!hasProp.call(attributes, key)) {
                    continue;
                }
                delete attributes[key];
            }
        });

        this.detachEvents.apply(this, this.getEventArgs());

        // destroy should occur at the end of render cycle
        // a method componentDidUnmount will be welcomed
        setTimeout(this.destroy, 0);
    },

    destroy() {
        for (const prop in this) {
            if (!hasProp.call(this, prop)) {
                continue;
            }

            if (prop === expando || prop === "id" || prop === "props" || prop === "refs" || prop === "_reactInternalInstance") {
                continue;
            }

            delete this[prop];
        }

        this.destroyed = true;
    },

    getDOMNode() {
        return this.el;
    },

    // eslint-disable-next-line no-empty-function
    getEventArgs() {},

    // eslint-disable-next-line no-empty-function
    attachEvents() {},

    // eslint-disable-next-line no-empty-function
    detachEvents() {},

    onModelChange() {
        const options = arguments[arguments.length - 1];

        if (options.bubble > 0) {
            // ignore bubbled events
            return;
        }

        this._updateOwner();
    },

    _updateView() {
        if (this._updating) {
            return;
        }

        this.shouldUpdate = true;

        if (this.el) {
            this._updating = true;
            const state = {};
            state[this.uid] = randomString();
            this.setState(state);
        }
    },

    _updateOwner() {
        this.shouldUpdate = true;
        if (this.el) {
            const state = {};
            state[this.uid] = randomString();

            const owner = this._reactInternalInstance._currentElement._owner;
            if (owner && owner._instance) {
                owner._instance.setState(state);
            } else {
                this.setState(state);
            }
        }
    },

    getFilter(query, isValue) {
        if (!isValue) {
            query = this.inline.get(query);
        }

        const type = typeof query;

        if (type === "function") {
            return query;
        }

        if (type === "string") {
            query = query.trim();

            if (query.length === 0) {
                return null;
            }

            if (!this.filterCache) {
                this.filterCache = {};
            }

            if (hasProp.call(this.filterCache, query)) {
                return this.filterCache[query];
            }

            const reg = new RegExp(query.replace(/([\\/^$.|?*+()[\]{}])/g, "\\$1"), "i");

            const fn = model => {
                const attrs = model instanceof Backbone.Model ? model.attributes : model;

                return Object.keys(attrs).some(key => {
                    return reg.test(attrs[key]);
                });
            };

            this.filterCache[query] = fn;

            return fn;
        }

        return null;
    },

    addClass(props, toAdd) {
        const classList = props.className ? props.className.trim().split(/\s+/g) : [];
        let hasChanged = false;

        if (Array.isArray(toAdd)) {
            toAdd.forEach(className => {
                if (classList.indexOf(className) === -1) {
                    hasChanged = true;
                    classList.push(className);
                }
            });
        } else if (classList.indexOf(toAdd) === -1) {
            hasChanged = true;
            classList.push(toAdd);
        }

        if (hasChanged) {
            props.className = classList.join(" ");
        }
    },

    removeClass(props, toRemove) {
        const classList = props.className ? props.className.trim().split(/\s+/g) : [];
        let hasChanged = false;
        let at;

        if (Array.isArray(toRemove)) {
            toRemove.forEach(className => {
                at = classList.indexOf(className);

                if (at !== -1) {
                    hasChanged = true;
                    classList.splice(at, 1);
                }
            });
        } else if ((at = classList.indexOf(toRemove)) !== -1) {
            hasChanged = true;
            classList.splice(at, 1);
        }

        if (hasChanged) {
            props.className = classList.join(" ");
        }
    }

});

module.exports = ModelComponent;
