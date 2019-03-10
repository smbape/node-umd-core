import _ from "%{amd: 'lodash', brunch: '!_', common: 'lodash', node: 'lodash'}";

const {hasOwnProperty: hasProp} = Object.prototype;

const BackboneCollectionSubsetPrototype = {
    attachEvents() {
        this.parent.on("change", this._onChange, this);
        this.parent.on("add", this._onAdd, this);
        this.parent.on("remove", this._onRemove, this);
        this.parent.on("reset", this._onReset, this);
    },

    detachEvents() {
        this.parent.off("change", this._onChange, this);
        this.parent.off("add", this._onAdd, this);
        this.parent.off("remove", this._onRemove, this);
        this.parent.off("reset", this._onReset, this);
    },

    populate(options) {
        this.__super__.reset.call(this, this.parent.models, Object.assign({
            sub: true,
            silent: true
        }, options));
    },

    destroy() {
        this.detachEvents();
        for (const prop in this) {
            if (prop !== "_uid" && hasProp.call(this, prop)) {
                delete this[prop];
            }
        }

        // may be destroyed was executed during an event handling
        // therefore, callbacks will still be processed
        // this.destroyed helps skipping callback if needed
        this.destroyed = true;
    },

    _onChange(model, collection, options) {
        if (this.destroyed) {
            return;
        }

        if (options === undefined) {
            options = collection;
        }

        if (model === this.parent) {
            this.set(model.changed, options);
            return;
        }

        if (options.bubble !== 1) {
            // only handle events bubbled from parent
            return;
        }

        // maintain filter
        if (!this.parent.contains(model)) {
            if (this.contains(model)) {
                this.__super__.remove.call(this, model);
            }
            return;
        }

        // maintain filter
        if (this.selector && !this.selector(model)) {
            this.__super__.remove.call(this, model);
            return;
        }

        if (!this.contains(model)) {
            this.__super__.add.call(this, model);
            return;
        }

        // avoid circular event change
        //   set -> _ensureEntegrity -> add -> set -> _ensureIntegrity -> add -> set
        // this.set model, _.defaults {bubble: 0, sub: true}, options

        // maintain order
        const {comparator} = this;
        if (!comparator) {
            return;
        }

        const {silent} = options;
        const match = this.selector && this.selector(model);
        const from = this.indexOf(model);
        let mustSort = false;

        if (from !== 0) {
            mustSort = comparator(this.models[from - 1], model) > 0;
        }

        if (!mustSort && from !== this.length - 1) {
            mustSort = comparator(model, this.models[from + 1]) > 0;
        }

        if (!mustSort) {
            return;
        }

        const overrides = {};
        overrides[model.cid] = model._previousAttributes;
        let index = this.insertIndexOf(model, _.defaults({
            overrides
        }, options));

        if (from < index) {
            // inserting at 2 then removing at 0 will cause the element at 2 to be at 1 after removal
            index--;
        }

        if (from === index) {
            // element is at the correct index
            return;
        }

        const expectedModels = this.models.slice();

        expectedModels.splice(from, 1);
        this.remove(model, _.defaults({
            bubble: 0,
            sub: true,
            silent: true
        }, options));

        expectedModels.splice(index, 0, model);
        this.add(model, _.defaults({
            bubble: 0,
            match,
            sub: true,
            silent: true
        }, options));

        if (!silent) {
            model.trigger("move", model, this, _.defaults({
                index,
                from,
                match,
                bubble: 0
            }, options));
        }
    },

    _onAdd(model, collection, options) {
        if (!this.destroyed && collection === this.parent) {
            this.__super__.add.call(this, model, _.defaults({
                bubble: 0,
                sort: true
            }, options));
        }
    },

    _onRemove(model, collection, options) {
        if (!this.destroyed && collection === this.parent) {
            this.__super__.remove.call(this, model, _.defaults({
                bubble: 0
            }, options));
        }
    },

    _onReset(collection, options) {
        if (!this.destroyed && collection === this.parent) {
            this.__super__.reset.call(this, collection.models, _.defaults({
                bubble: 0,
                sub: true
            }, options));
        }
    },
};

["add", "remove", "reset"].forEach(method => {
    BackboneCollectionSubsetPrototype[method] = function(models, options) {
        if (!options || !options.sub) {
            throw new Error(`${ method } is not allowed on a subset`);
        }
        return this.__super__[method].call(this, models, options);
    };
});

module.exports = BackboneCollectionSubsetPrototype;
