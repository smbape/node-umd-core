import _ from "%{amd: 'lodash', brunch: '!_', common: 'lodash', node: 'lodash'}";
import Backbone from "%{amd: 'backbone', brunch: '!Backbone', common: 'backbone', node: 'backbone'}";
import inherits from "../functions/inherits";
import BackboneCollectionSubsetPrototype from "./BackboneCollectionSubsetPrototype";

const {hasOwnProperty: hasProp} = Object.prototype;

const attrSplitter = /(?:\\(.)|\.)/g;

const byAttribute = (attrs, topOrder) => {
    // in my tests, eval comparator function is faster than scoped comparator function
    topOrder = topOrder < 0 || topOrder === true ? -1 : 1;

    if (typeof attrs === "string") {
        attrs = [attrs];
    }

    if (Array.isArray(attrs)) {
        attrs = _.map(attrs, (attr, index) => {
            return Array.isArray(attr) ? attr : [attr, topOrder];
        });
    } else if (_.isObject(attrs)) {
        attrs = _.map(attrs, (order, attr) => {
            return [attr, order < 0 ? -1 : 1];
        });
    } else {
        return () => true;
    }

    const blocks = [`
        "use strict";
        var res, left, right;

        if (a instanceof Backbone.Model) {
            a = a.attributes;
        }

        if (b instanceof Backbone.Model) {
            b = b.attributes;
        }
    `.trim().replace(/ {8}/mg, "")];

    attrs.forEach(([attr, order]) => {
        const parts = [];
        let lastIndex = 0;
        attrSplitter.lastIndex = lastIndex;

        let match;
        // eslint-disable-next-line no-cond-assign
        while (match = attrSplitter.exec(attr)) {
            if (match[0] === ".") {
                parts.push(attr.slice(lastIndex, match.index).replace(/\\/g, ""));
                lastIndex = attrSplitter.lastIndex;
            }
        }

        if (lastIndex < attr.length) {
            parts.push(attr.slice(lastIndex).replace(/\\/g, ""));
        }

        attr = parts.map(part => {
            return JSON.stringify(part);
        }).join("][");

        blocks.push(`
            left = a[${ attr }];
            right = b[${ attr }];

            if (left === right) {
                res = 0;
            } else if (left === undefined) {
                res = -1;
            } else if (right === undefined) {
                res = 1;
            } else {
                res = left > right ? ${ order } : left < right ? ${ -order } : 0;
            }

            if (res !== 0) {
                return res;
            }
        `.trim().replace(/ {12}/mg, ""));
    });

    blocks.push("return 0;");

    // eslint-disable-next-line no-new-func
    const fn = new Function("Backbone", "a", "b", blocks.join("\n\n"));
    return fn.bind(null, Backbone);
};

const reverse = compare => {
    if (compare.reverse && compare.original) {
        return compare.original;
    }

    const fn = (a, b) => {
        return -compare(a, b);
    };

    fn.reverse = true;
    fn.original = compare;
    fn.attribute = compare.attribute;

    return fn;
};

// http://stackoverflow.com/questions/14415408/last-index-of-multiple-keys-using-binary-search
// where value should be inserted in an ordered array using compare
const binarySearchInsert = (value, models, compare, options) => {
    const length = models.length;
    let low = 0;
    let high = length;

    if (low === high) {
        return low;
    }

    const overrides = options ? options.overrides : undefined;

    let mid, model, cmp;
    while (low !== high) {
        // used to be a faster way to do InfInt (low + high) / 2
        mid = (low + high) >>> 1;
        model = models[mid];

        if (overrides && overrides[model.cid]) {
            model = overrides[model.cid];
        }

        cmp = compare(model, value);
        if (cmp > 0) {
            high = mid;
        } else {
            low = mid + 1;
        }
    }

    let index = low;

    if (index < length) {
        // it must be the last occurence with same comparator
        model = models[index];
        if (overrides && overrides[model.cid]) {
            model = overrides[model.cid];
        }
        if (compare(model, value) <= 0) {
            return ++index;
        }
    }

    if (index > 1) {
        // it must be the last occurence with same comparator
        model = models[index - 1];
        if (overrides && overrides[model.cid]) {
            model = overrides[model.cid];
        }
        if (compare(model, value) > 0) {
            return --index;
        }
    }

    return index;
};

const binarySearch = (value, models, compare, options) => {
    let index = binarySearchInsert(value, models, compare, options);
    const overrides = options ? options.overrides : undefined;

    const indexes = index === 0 ? [index] : index === models.length ? [index - 1] : [index, index - 1];
    const indexesLen = indexes.length;

    for (let i = 0, model; i < indexesLen; i++) {
        index = indexes[i];
        model = models[index];

        if (overrides && overrides[model.cid]) {
            model = overrides[model.cid];
        }

        if (compare(model, value) === 0) {
            return index;
        }
    }

    return -1;
};

const _lookup = (attr, model) => {
    const props = attr.split(".");
    const propsLen = props.length;
    let value = model;

    for (let i = 0, prop; i < propsLen; i++) {
        prop = props[i];
        if (value instanceof Backbone.Model) {
            value = value.get(prop);
        } else if (_.isObject(value)) {
            value = value[prop];
        } else {
            value = undefined;
            break;
        }
    }
    return value;
};

const defaultSetOptions = {
    add: true,
    merge: true,
    remove: true
};

function BackboneCollection(models, options) {
    options = Object.assign({}, options);

    if (typeof options.comparator === "string") {
        options.comparator = byAttribute(options.comparator);
    }

    for (const opt in options) {
        if (hasProp.call(options, opt) && opt.charAt(0) !== "_" && opt in this) {
            this[opt] = options[opt];
        }
    }

    if (options.subset) {
        this.isSubset = true;
        this.matches = {};
    }

    if (typeof options.selector === "function") {
        this.selector = options.selector;
    }

    this._keymap = {};
    this._byIndex = {};

    const indexes = options.indexes || this.indexes;
    if (_.isObject(indexes)) {
        for (const name in indexes) {
            if (hasProp.call(indexes, name)) {
                this.addIndex(name, indexes[name]);
            }
        }
    }

    this._modelAttributes = new Backbone.Model(options.attributes);
    this._modelAttributes.on("change", this._handleModelAttributesChange, this);

    if (!options.subset) {
        this.on("change", this._onChange);
    }

    this._uid = _.uniqueId("BackboneCollection_");

    BackboneCollection.__super__.constructor.call(this, models, options);
}

inherits(BackboneCollection, Backbone.Collection);

Object.assign(BackboneCollection.prototype, {
    _handleModelAttributesChange(model, options) {
        // eslint-disable-next-line guard-for-in
        for (const attr in model.changed) {
            this.trigger(`change:${ attr }`, this, model.attributes[attr], options);
        }
        this.trigger("change", this, options);
    },

    unsetAttribute(name) {
        this._modelAttributes.unset(name);
    },

    getAttribute(name) {
        return this._modelAttributes.get(name);
    },

    setAttribute(...args) {
        this._modelAttributes.set(...args);
    },

    attrToJSON() {
        return this._modelAttributes.toJSON();
    },

    addIndex(indexName, attrs) {
        if (typeof attrs === "string") {
            attrs = [attrs];
        }

        if (!Array.isArray(attrs)) {
            return false;
        }

        this._keymap[indexName] = Object.assign({}, attrs);
        this._keymap[indexName].length = attrs.length;
        if (attrs.condition) {
            this._keymap[indexName].condition = attrs.condition;
        }
        this._byIndex[indexName] = {};

        const {models} = this;
        if (!models) {
            return true;
        }

        const options = {};
        const len = models.length;
        for (let i = 0; i < len; i++) {
            this._indexModel(models[i], indexName, options);
        }

        return true;
    },

    get(obj) {
        return this.byIndex(obj);
    },

    byIndex(model, indexName, options) {
        if (null === model || "object" !== typeof model) {
            return BackboneCollection.__super__.get.call(this, model);
        }

        let found;
        if (model instanceof Backbone.Model) {
            found = BackboneCollection.__super__.get.call(this, model);
            if (found) {
                return found;
            }
            model = model.toJSON();
        }

        const id = model[this.model.prototype.idAttribute];
        found = BackboneCollection.__super__.get.call(this, id);
        if (found) {
            return found;
        }

        if (!indexName) {
            // eslint-disable-next-line guard-for-in
            for (indexName in this._keymap) {
                found = this.byIndex(model, indexName, options);
                if (found) {
                    break;
                }
            }
            return found;
        }

        if (!hasProp.call(this._keymap, indexName)) {
            return undefined;
        }

        const partial = options ? options.partial : false;
        const ref = this._keymap[indexName];
        const len = ref.length;
        let obj = this._byIndex[indexName];

        for (let index = 0, value; index < len; index++) {
            value = _lookup(ref[index], model);
            if (typeof value === "undefined" || typeof obj[value] === "undefined") {
                if (partial && partial === index) {
                    return this._getPartialMatch(obj, index, ref);
                }
                return undefined;
            }
            obj = obj[value];
        }
        return obj;
    },

    _getPartialMatch(obj, index, ref) {
        const res = [];
        let count = ref.length - index;
        const stack = [[obj, count]];
        let item;

        const mapResult = key => {
            return obj[key];
        };

        const mapStack = key => {
            return [obj[key], count];
        };

        while (item = stack.pop()) { // eslint-disable-line no-cond-assign
            [obj, count] = item;

            if (count === 1) {
                res.push(...Object.keys(obj).map(mapResult));
            } else {
                count--;
                stack.push(...Object.keys(obj).map(mapStack));
            }
        }

        if (this.comparator) {
            res.sort(this.comparator);
        }

        return res;
    },

    _addReference(model, options) {
        BackboneCollection.__super__._addReference.apply(this, arguments);
        this._indexModel(model, null, options);
    },

    _indexModel(model, indexName, options) {
        if (!(model instanceof Backbone.Model)) {
            return;
        }

        if (!indexName) {
            // eslint-disable-next-line guard-for-in
            for (indexName in this._keymap) {
                this._indexModel(model, indexName, options);
            }
            return;
        }

        const attrs = this._keymap[indexName];
        if (typeof attrs.condition === "function" && !attrs.condition(model, indexName)) {
            return;
        }

        const chain = [];
        const attrsLen = attrs.length;
        let value;

        for (let i = 0; i < attrsLen; i++) {
            value = _lookup(attrs[i], model);
            if (value === undefined) {
                return;
            }
            chain.push(value);
        }

        let key = this._byIndex[indexName];
        const chainLen = chain.length;

        for (let index = 0; index < chainLen; index++) {
            value = chain[index];
            if (index === chainLen - 1) {
                break;
            }

            if (hasProp.call(key, value)) {
                key = key[value];
            } else {
                key = key[value] = {}; // eslint-disable-line no-multi-assign
            }
        }

        key[value] = model;
    },

    _removeReference(model, options) {
        this._removeIndex(model);
        BackboneCollection.__super__._removeReference.apply(this, arguments);
    },

    _removeIndex(model, indexName) {
        if (!(model instanceof Backbone.Model)) {
            return;
        }

        if (!indexName) {
            // eslint-disable-next-line guard-for-in
            for (indexName in this._keymap) {
                this._removeIndex(model, indexName);
            }
            return;
        }

        const attrs = this._keymap[indexName];
        const attrsLen = attrs.length;
        const valueChain = new Array(attrsLen);
        let value;

        for (let i = 0; i < attrsLen; i++) {
            value = _lookup(attrs[i], model);
            if (value === undefined) {
                return;
            }
            valueChain[i] = value;
        }

        let key = this._byIndex[indexName];
        const keyChain = new Array(attrsLen - 1);

        for (let i = 0; i < attrsLen; i++) {
            value = valueChain[i];
            if (!key || i === attrsLen - 1) {
                break;
            }
            keyChain[i] = [key, value];
            key = key[value];
        }

        if (key) {
            delete key[value];
            for (let i = attrsLen - 2, obj; i >= 0; i--) {
                [obj, key] = keyChain[i];
                if (Object.keys(obj[key]).length === 0) {
                    delete obj[key];
                }
            }
        }
    },

    _getClone(model) {
        let cloned = this.get(model);
        if (cloned) {
            cloned = new cloned.constructor(cloned.attributes);
            if (model instanceof Backbone.Model) {
                cloned.set(model.attributes);
            } else {
                cloned.set(model);
            }
        }
        return cloned;
    },

    _onChange(model, collection, options) {
        if (model !== this) {
            this._ensureEntegrity(model, options);
        }
    },

    _ensureEntegrity(model, options) {
        let index, match;

        // maintain filter
        if (this.selector && !(match = this.selector(model))) {
            if (this.isSubset) {
                delete this.matches[model.cid];
            }
            index = this.indexOf(model);
            this.remove(model, _.defaults({
                bubble: 0,
                sort: false
            }, options));

            return {
                remove: index
            };
        }

        if (!this.comparator) {
            // there is no order to maintain
            return undefined;
        }

        let at = this.insertIndexOf(model);
        index = this.indexOf(model);

        if (index !== -1 && at > index) {
            // removing model at index will cause insert index to decrease
            // i.e. if there is an insert at 2 the a remove at 0, the element that was at 2 before removal will be at 1 after removal
            at--;
        }

        if (at === index) {
            // order is already maintened
            return undefined;
        }

        if (this.isSubset) {
            delete this.matches[model.cid];
        }

        if (index !== -1) {
            this.remove(model, _.defaults({
                bubble: 0,
                sort: false
            }, options));
        }

        if (this.isSubset) {
            this.matches[model.cid] = match;
        }

        this.add(model, _.defaults({
            bubble: 0,
            sort: false,
            match
        }, options));

        return {
            remove: index,
            add: at,
            match
        };
    },

    insertIndexOf(model, options) {
        const size = this.length;
        if (!size) {
            return size;
        }

        let at;
        if (this.comparator) {
            const existing = this.get(model);
            at = binarySearchInsert(existing ? existing : model, this.models, this.comparator, options);
        } else {
            at = this.indexOf(model, options);
        }

        return at === -1 ? size : at;
    },

    indexOf(model, options) {
        const size = this.length;
        if (!size) {
            return -1;
        }

        const {comparator: compare} = this;
        if (!compare) {
            return BackboneCollection.__super__.indexOf.apply(this, arguments);
        }

        const existing = this.get(model);
        if (!existing) {
            return -1;
        }

        const {models} = this;

        let index = binarySearch(existing, models, compare, options);
        if (index !== -1 && models[index] === existing) {
            return index;
        }

        const {_previousAttributes: attributes} = model;

        const overrides = {};
        overrides[model.cid] = attributes;
        index = binarySearch(attributes, models, compare, _.defaults({
            overrides,
            model: existing
        }, options));

        const {cid} = existing;

        while (index > 0 && models[index].cid !== cid) {
            if (models[index - 1].cid === cid) {
                index--;
                break;
            }

            if (compare(attributes, models[index - 1]) !== 0) {
                // There is somthing wrong,
                // because I haven't prove that this path will never be taken
                // it is kept
                break;
            }

            index--;
        }

        return index;
    },

    contains(model, options) {
        return Boolean(this.get(model)) || this.indexOf(model, options) !== -1;
    },

    set(models, options) {
        if (!models) {
            return undefined;
        }

        if (!this.selector && !this.comparator) {
            return BackboneCollection.__super__.set.apply(this, arguments);
        }

        const singular = !Array.isArray(models);
        if (singular) {
            models = [models];
        }

        options = _.defaults({}, options, defaultSetOptions);
        const {merge, silent, add, remove} = options;

        const res = [];
        const modelsLen = models.length;
        const actions = [];
        const toRemove = remove ? this.clone() : undefined;

        const notifyAction = silent ? undefined : ([name, model, index, from, match]) => {
            model.trigger(name, model, this, _.defaults({
                index,
                from,
                match
            }, options));
        };

        for (let j = 0, model, existing, hasChanged, opts, match, at; j < modelsLen; j++) {
            model = models[j];
            existing = this.get(model);

            if (existing) {
                hasChanged = false;

                if (merge && model !== existing) {
                    let attrs = this._isModel(model) ? model.attributes : model;
                    if (options.parse) {
                        attrs = existing.parse(attrs, options);
                    }
                    existing.set(attrs, options);
                    hasChanged = !_.isEmpty(existing.changed);
                }

                if (hasChanged) {
                    opts = this._ensureEntegrity(existing, _.defaults({
                        silent: true
                    }, options));

                    if (opts) {
                        if (hasProp.call(opts, "add")) {
                            actions.push(["move", existing, opts.add, opts.remove, opts.match]);
                            res.push(existing);
                        } else if (hasProp.call(opts, "remove")) {
                            actions.push(["remove", existing, opts.remove]);
                        }
                    } else {
                        res.push(existing);
                    }
                } else {
                    res.push(existing);
                }

                continue;
            }

            if (!add) {
                continue;
            }

            model = this._prepareModel(model);
            if (!model) {
                continue;
            }

            // maintain filter
            if (this.selector && !(match = this.selector(model))) {
                continue;
            }

            at = this.length;

            // maintain order
            if (this.comparator && options.sort !== false) {
                at = this.insertIndexOf(model);
            }

            this._addReference(model, _.defaults({
                at
            }, options));
            this.models.splice(at, 0, model);
            this.length++;

            res.push(model);
            actions.push(["add", model, at, null, match]);
            if (this.isSubset) {
                this.matches[model.cid] = match;
            }
        }

        if (toRemove) {
            toRemove.remove(res);
            this._removeModels(toRemove.models, options);
        }

        if (!silent && actions.length) {
            actions.forEach(notifyAction);
            this.trigger("update", this, options);
        }

        return singular ? res[0] : res;
    },

    clone() {
        return new this.constructor(this.models, {
            model: this.model,
            comparator: this.comparator,
            selector: this.selector
        });
    },

    getSubSet(options = {}) {
        if (!options.comparator && !options.selector) {
            return this;
        }

        const Parent = this.constructor;

        const subset = new Parent(options.models === false ? [] : this.models, Object.assign({
            model: this.model,
            comparator: this.comparator,
            selector: this.selector,
            subset: true
        }, options));

        subset.__super__ = Parent.prototype;
        subset.parent = this;
        Object.assign(subset, BackboneCollectionSubsetPrototype);

        if (options.models !== false) {
            subset.attachEvents();
        }

        return subset;
    },

    _onModelEvent(event, model, collection, options) {
        if (this.destroyed) {
            return;
        }

        if ((event === "add" || event === "remove") && collection !== this) {
            return;
        }

        if (event === "destroy") {
            this.remove(model, options);
        } else if (event === "change") {
            const prevId = this.modelId(model.previousAttributes());
            const id = this.modelId(model.attributes);
            if (prevId !== id) {
                if (prevId !== null) {
                    delete this._byId[prevId];
                }
                if (id !== null) {
                    this._byId[id] = model;
                }
            }
        }

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

        if (event === "sync" || event === "request") {
            this.trigger(event, model, collection, this, options);
        } else {
            this.trigger(event, model, this, options);
        }
    },

    _removeModels(models, options) {
        const removed = [];
        const modelsLen = models.length;

        for (let i = 0, model, index, id; i < modelsLen; i++) {
            model = this.get(models[i]);
            if (!model) {
                continue;
            }

            index = this.indexOf(model);
            this.models.splice(index, 1);
            this.length--;

            // Remove references before triggering 'remove' event to prevent an
            // infinite loop. #3693
            delete this._byId[model.cid];
            this._removeIndex(model);

            id = this.modelId(model.attributes);
            if (id != null) {
                delete this._byId[id];
            }

            if (!options.silent) {
                options.index = index;
                model.trigger("remove", model, this, options);
            }

            removed.push(model);
            this._removeReference(model, options);
        }

        return removed;
    },

});

Object.assign(BackboneCollection, {
    byAttribute,
    byAttributes: byAttribute,
    reverse
});

module.exports = BackboneCollection;
