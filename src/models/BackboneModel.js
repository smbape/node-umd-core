import Backbone from "%{amd: 'backbone', brunch: '!Backbone', common: 'backbone', node: 'backbone'}";
import inherits from "../functions/inherits";
import _isEqual from "../../lib/fast-deep-equal";

const hasProp = Object.prototype.hasOwnProperty;

function BackboneModel() {
    return BackboneModel.__super__.constructor.apply(this, arguments);
}

inherits(BackboneModel, Backbone.Model);

Object.assign(BackboneModel.prototype, {
    // Set a hash of model attributes on the object, firing `"change"`. This is
    // the core primitive operation of a model, updating the data and notifying
    // anyone who needs to know about the change in state. The heart of the beast.
    set(key, val, options) {
        if (key == null) {
            return this;
        }

        // Handle both `"key", value` and `{key: value}` -style arguments.
        let attrs;
        if (typeof key === "object") {
            attrs = key;
            options = val;
        } else {
            (attrs = {})[key] = val;
        }

        if (options == null) {
            options = {};
        }

        // Run validation.
        if (!this._validate(attrs, options)) {
            return false;
        }

        // Extract attributes and options.
        const isEqual = options.isEqual || _isEqual;
        const unset = options.unset;
        const silent = options.silent;
        const changes = [];
        const changing = this._changing;
        this._changing = true;

        if (!changing) {
            this._previousAttributes = Object.assign({}, this.attributes);
            this.changed = {};
        }

        const properties = this.properties;
        const current = this.attributes;
        const changed = this.changed;
        const prev = this._previousAttributes;
        let hasChanged = false;
        let isProperty = false;
        let currentVal;

        // For each `set` attribute, update or delete the current value.
        // eslint-disable-next-line guard-for-in
        for (const attr in attrs) {
            val = attrs[attr];
            isProperty = properties && hasProp.call(properties, attr) && typeof properties[attr] === "function";
            currentVal = current[attr];

            if (isProperty && val != null && !(val instanceof properties[attr])) {
                if (currentVal) {
                    if (currentVal instanceof Backbone.Collection) {
                        currentVal.reset(val, options);
                        val = currentVal;
                    } else if (currentVal instanceof Backbone.Model) {
                        currentVal.set(val, options);
                        val = currentVal;
                    } else {
                        val = new properties[attr](val, options);
                    }
                } else {
                    val = new properties[attr](val, options);
                }
            }

            hasChanged = false;
            if (!isEqual(currentVal, val)) {
                hasChanged = true;
                changes.push(attr);
            }

            if (!isEqual(prev[attr], val)) {
                changed[attr] = val;
            } else {
                delete changed[attr];
            }

            if (hasChanged) {
                if (unset) {
                    this._removeAttribute(attr, isProperty, options);
                } else {
                    this._setAttribute(attr, val, isProperty, options);
                }
            }
        }

        // Update the `id`.
        if (this.idAttribute in attrs) {
            this.id = this.get(this.idAttribute);
        }

        // Trigger all relevant attribute changes.
        if (!silent) {
            if (changes.length) {
                this._pending = options;
            }
            for (let i = 0; i < changes.length; i++) {
                this.trigger(`change:${ changes[i] }`, this, current[changes[i]], options);
            }
        }

        // You might be wondering why there's a `while` loop here. Changes can
        // be recursively nested within `"change"` events.
        if (changing) {
            return this;
        }

        if (!silent) {
            while (this._pending) {
                options = this._pending;
                this._pending = false;
                this.trigger("change", this, options);
            }
        }

        this._pending = false;
        this._changing = false;
        return this;
    },

    get(attr, defaultVal) {
        let val = this._getAttribute(attr);
        if (val == null) {
            val = defaultVal;
            this.set(attr, val);
        }
        return val;
    },

    _getAttribute(attr) {
        return this.attributes[attr];
    },

    _setAttribute(attr, val, isProperty, options) {
        const current = this.attributes;
        current[attr] = val;
        if (isProperty && current[attr] != null) {
            this._addReference(current[attr], options);
        }
    },

    _removeAttribute(attr, isProperty, options) {
        const current = this.attributes;
        if (isProperty && current[attr] != null) {
            this._removeReference(current[attr], options);
        }
        delete current[attr];
    },

    // Internal method to create a model's ties to a parent model.
    _addReference(model, options) {
        model.on("all", this._onModelEvent, this);
    },

    // Internal method to sever a model's ties to a parent model.
    _removeReference(model, options) {
        model.off("all", this._onModelEvent, this);
    },

    _onModelEvent(event, model, collection, options) {
        if (arguments.length === 3) {
            options = Object.assign({
                bubble: 1
            }, collection);
        } else {
            options = arguments[arguments.length - 1];
            options = Object.assign({
                bubble: 0
            }, options);
            ++options.bubble;
        }

        if (arguments.length >= 4) {
            this.trigger(event, model, collection, this, options);
        } else {
            this.trigger(event, model, this, options);
        }
    }
});

module.exports = BackboneModel;
