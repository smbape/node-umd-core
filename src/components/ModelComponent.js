import $ from "%{amd: 'jquery', common: 'jquery', brunch: '!jQuery'}";
import {uniqueId} from "%{amd: 'lodash', common: 'lodash', brunch: '!_', node: 'lodash'}";
import Backbone from "%{amd: 'backbone', common: 'backbone', brunch: '!Backbone', node: 'backbone'}";
import React from "%{ amd: 'react', common: '!React' }";
import ReactDOM from "%{ amd: 'react-dom', common: '!ReactDOM' }";
import isEqual from "../../lib/fast-deep-equal";

const randomString = () => Math.random().toString(36).slice(2);
const hasProp = Object.prototype.hasOwnProperty;
const expando = React.expando || (React.expando = randomString());

class ModelComponent extends React.Component {
    uid = `ModelComponent${ randomString() }`;

    constructor(props) {
        super(...arguments);
        this.destroy = this.destroy.bind(this);
        this.id = uniqueId(`${ this.constructor.name || "ModelComponent" }_`);
        this.inline = new Backbone.Model();
        this._refs = {};
        this._reffn = {};
        this.preinit(props);
        this.initialize(props);
    }

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
    }

    getRef(name) {
        if (hasProp.call(this._refs, name)) {
            return this._refs[name];
        }
        return this.refs[name];
    }

    preinit(props) {
        // No default behaviour
    }

    initialize(props) {
        // No default behaviour
    }

    componentDidMount() {
        this.el = ReactDOM.findDOMNode(this);
        this.$el = $(this.el);
        this.attachEvents.apply(this, this.getEventArgs());
    }

    shouldComponentUpdate(nextProps, nextState) {
        this.shouldUpdate = this.shouldUpdate || !isEqual(this.state, nextState) || !isEqual(this.props, nextProps);
        this.shouldUpdateEvent = this.shouldUpdateEvent || this.shouldComponentUpdateEvent(nextProps, nextState);
        return this.shouldUpdate || this.shouldUpdateEvent;
    }

    shouldComponentUpdateEvent(nextProps, nextState) {
        const method = typeof this.getNewEventArgs === "function" ? "getNewEventArgs" : "getEventArgs";
        const nextEventArgs = this[method](nextProps, nextState);
        const prevEventArgs = this.getEventArgs(this.props, this.state);
        return !isEqual(nextEventArgs, prevEventArgs);
    }

    getSnapshotBeforeUpdate(prevProps, prevState) {
        if (this.shouldUpdateEvent) {
            const {props: nextProps, state: nextState} = this;
            const prevEventArgs = this.getEventArgs(prevProps, prevState);
            prevEventArgs.push(nextProps, nextState);
            this.detachEvents(...prevEventArgs);
        }

        return null;
    }

    componentDidUpdate(prevProps, prevState) {
        if (this.shouldUpdateEvent) {
            const {props: nextProps, state: nextState} = this;
            const method = typeof this.getNewEventArgs === "function" ? "getNewEventArgs" : "getEventArgs";
            const nextEventArgs = this[method](nextProps, nextState);
            nextEventArgs.push(nextProps, nextState);
            this.attachEvents(...nextEventArgs);
        }

        this.shouldUpdate = false;
        this.shouldUpdateEvent = false;
        this._updating = false;
    }

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
    }

    destroy() {
        for (const prop in this) {
            if (!hasProp.call(this, prop)) {
                continue;
            }

            if (prop === expando || prop === "id" || prop === "props" || prop === "refs" || prop === "_reactInternalInstance" || prop === "_reactInternalFiber") {
                continue;
            }

            delete this[prop];
        }

        this.destroyed = true;
    }

    getDOMNode() {
        return this.el;
    }

    getEventArgs() {
        // No default behaviour
    }

    attachEvents() {
        // No default behaviour
    }

    detachEvents() {
        // No default behaviour
    }

    onModelChange() {
        const options = arguments[arguments.length - 1];

        if (options.bubble > 0) {
            // ignore bubbled events
            return;
        }

        this._updateOwner();
    }

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
    }

    _updateOwner() {
        this.shouldUpdate = true;
        if (this.el) {
            const state = {};
            state[this.uid] = randomString();

            const owner = this._reactInternalInstance ? this._reactInternalInstance._currentElement._owner : {_instance: this._reactInternalFiber.nextEffect.stateNode};
            if (owner && owner._instance instanceof React.Component) {
                owner._instance.setState(state);
            } else {
                this.setState(state);
            }
        }
    }

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

            this.filterCache[query] = model => {
                const attrs = model instanceof Backbone.Model ? model.attributes : model;

                return Object.keys(attrs).some(key => {
                    return reg.test(attrs[key]);
                });
            };

            return this.filterCache[query];
        }

        return null;
    }

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
    }

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
}

module.exports = ModelComponent;
