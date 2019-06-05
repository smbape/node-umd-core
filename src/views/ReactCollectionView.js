import React from "%{ amd: 'react', brunch: '!React', common: 'react' }";
import BackboneCollection from "../models/BackboneCollection";
import ReactModelView from "./ReactModelView";

const {byAttribute, reverse} = BackboneCollection;

class ReactCollectionView extends ReactModelView {
    constructor() {
        super(...arguments);
        this.state = {
            model: this.getNewModel(arguments[0]),
            pending: []
        };
    }

    shouldComponentUpdateEvent(nextProps, nextState) {
        const shouldComponentUpdateEvent = super.shouldComponentUpdateEvent(nextProps, nextState);
        if (shouldComponentUpdateEvent) {
            delete this._childNodeList;
        }
        return shouldComponentUpdateEvent;
    }

    getModel(props, state = this.state) {
        return state ? state.model : undefined;
    }

    getNewModel(props) {
        const {
            reverse: nextReverse,
            model: nextModel
        } = props;

        let {
            order: nextComparator,
            filter: nextFilter
        } = props;

        if (!nextModel) {
            return nextModel;
        }

        let currentModel = this.getModel();
        let currentComparator, currentFilter, currentReverse;

        if (currentModel) {
            currentComparator = currentModel.comparator;
            currentFilter = currentModel.selector;
            currentReverse = currentComparator ? currentComparator.reverse : undefined;
        }

        if (typeof nextComparator === "undefined") {
            // use the default comparator
            nextComparator = nextModel.comparator || null;
        }

        if (typeof nextComparator === "string") {
            if (nextComparator.length === 0) {
                nextComparator = null;
            } else if (currentComparator && currentComparator.attribute === nextComparator && nextReverse === currentReverse) {
                // Reuse existing comparator
                nextComparator = currentComparator || null;
            }
        }

        if (typeof nextFilter === "undefined") {
            // use the default filter
            nextFilter = nextModel.selector;
        }

        if (typeof nextFilter === "string") {
            if (nextFilter.length === 0) {
                nextFilter = null;
            } else if (currentFilter && currentFilter.value === nextFilter) {
                // Reuse existing filter
                nextFilter = currentFilter;
            }
        }

        if (!currentComparator) {
            currentComparator = null;
        }

        if (!currentFilter) {
            currentFilter = null;
        }

        if (!nextComparator) {
            nextComparator = null;
        }

        if (!nextFilter) {
            nextFilter = null;
        }

        // If model, comparator, reverse or filter changed
        // recompute the displayed model
        if (!currentModel || nextModel !== this.props.model || nextComparator !== currentComparator || nextReverse !== currentReverse || nextFilter !== currentFilter) {
            if (typeof nextComparator === "string") {
                nextComparator = byAttribute(nextComparator, nextReverse ? -1 : 1);
            } else if (nextReverse) {
                nextComparator = reverse(nextComparator);
            }

            if (typeof nextFilter === "string") {
                nextFilter = this.getFilter(nextFilter, true);
            }

            if (nextComparator || nextFilter) {
                currentModel = nextModel.getSubSet({
                    comparator: nextComparator,
                    selector: nextFilter,
                    models: false
                });
                currentModel.isSubset = true;
            } else {
                currentModel = nextModel;
            }
        }

        return currentModel;
    }

    getEventArgs(props = this.props, state = this.state) {
        return [this.getModel(props, state)];
    }

    getNewEventArgs(props = this.props, state = this.state) {
        return [this.getNewModel(props, state)];
    }

    attachEvents(collection, nextProps, nextState) {
        super.attachEvents(collection, nextProps, nextState);
        if (collection) {
            collection.on("add", this.onAdd, this);
            collection.on("remove", this.onRemove, this);
            collection.on("move", this.onMove, this);
            collection.on("reset", this.onReset, this);
            collection.on("switch", this.onSwitch, this);
            if (this.state.model !== collection) {
                this.state.model = collection;
                if (nextState) {
                    nextState.model = collection;
                }
            }
        }
    }

    detachEvents(collection, nextProps, nextState) {
        if (collection) {
            collection.off("switch", this.onSwitch, this);
            collection.off("reset", this.onReset, this);
            collection.off("move", this.onMove, this);
            collection.off("remove", this.onRemove, this);
            collection.off("add", this.onAdd, this);
            if (collection.isSubset) {
                collection.destroy();
                this.state.model = undefined;
                if (nextState) {
                    nextState.model = undefined;
                }
            }
        }
        super.detachEvents(collection, nextProps, nextState);
    }

    childNodeList() {
        if (this._childNodeList) {
            return this._childNodeList;
        }

        const collection = this.getModel();
        if (!collection) {
            return [];
        }

        if (collection.isSubset) {
            collection.detachEvents();
            collection.populate();
            collection.attachEvents();
        }

        const {models} = collection;
        let {limit, offset} = this.props;

        if (limit > 0) {
            if (offset > 0) {
                limit += offset;
            } else {
                offset = 0;
            }
            if (limit > models.length) {
                limit = models.length;
            }
        } else {
            limit = models.length;
            offset = 0;
        }

        let index = 0;
        this._childNodeList = [];

        for (let i = offset, model; i < limit; i++) {
            model = models[i];
            this._childNodeList[index] = this.props.childNode(model, index, collection, {});
            index++;
        }

        return this._childNodeList;
    }

    // eslint-disable-next-line consistent-return
    onModelChange(model, collection, options) {
        if (typeof options === "undefined") {
            options = collection;
        }

        if (this.destroyed || options && options.bubble > 1) {
            // ignore bubbled events
            return false;
        }

        collection = this.getModel();

        if (model === collection) {
            this._updateView();
        } else {
            const index = collection.indexOf(model);
            this.state.pending.push(["change", model, index, collection, options]);
            this._updateView();
        }

        return true;
    }

    // eslint-disable-next-line consistent-return
    onAdd(model, collection, options) {
        if (this.destroyed || options && options.bubble > 1) {
            // ignore bubbled events
            return false;
        }

        let index = options.index || collection.indexOf(model);
        if (index === -1) {
            index = collection.length;
        }

        this.state.pending.push(["add", model, index, collection, options]);
        if (!options.silentView) {
            this._updateView();
        }

        return true;
    }

    // eslint-disable-next-line consistent-return
    onRemove(model, collection, options) {
        if (this.destroyed || options && options.bubble > 1) {
            // ignore bubbled events
            return false;
        }

        const index = options.index;
        this.state.pending.push(["remove", index]);
        if (!options.silentView) {
            this._updateView();
        }

        return true;
    }

    // eslint-disable-next-line consistent-return
    onMove(model, collection, options) {
        if (this.destroyed || options && options.bubble > 1) {
            // ignore bubbled events
            return false;
        }

        const {from, index} = options;
        this.state.pending.push(["move", from, index]);
        if (!options.silentView) {
            this._updateView();
        }

        return true;
    }

    // eslint-disable-next-line consistent-return
    onReset(collection, options) {
        if (this.destroyed || options && options.bubble > 1) {
            // ignore bubbled events
            return false;
        }

        this.reRender();
        return true;
    }

    // eslint-disable-next-line consistent-return
    onSwitch(collection, options) {
        if (this.destroyed || options && options.bubble > 1) {
            // ignore bubbled events
            return false;
        }

        this.reRender();
        return true;
    }

    getChildNodeList() {
        let childNodeList = this.childNodeList();
        const hasUpdate = this.state.pending.length;

        this.state.pending.forEach(args => {
            let model, index, collection, options, childNode, from;

            switch (args[0]) {
                case "change":
                    [, model, index, collection, options] = args;
                    childNodeList[index] = this.props.childNode(model, index, collection, options);
                    break;
                case "add":
                    [, model, index, collection, options] = args;
                    childNode = this.props.childNode(model, index, collection, options);
                    childNodeList.splice(index, 0, childNode);
                    break;
                case "remove":
                    [, index] = args;
                    childNode = childNodeList[index];
                    childNodeList.splice(index, 1);
                    break;
                case "move":
                    [, from, index] = args;
                    childNodeList.splice(from, 1);
                    childNodeList.splice(index, 0, childNode);
                    break;
                default:
                    // Ignore
            }
        });

        if (hasUpdate) {
            this.state.pending.length = 0;
            childNodeList = childNodeList.slice();
        }

        return childNodeList;
    }

    _getProps() {
        const props = Object.assign({}, this.props);
        ["order", "filter", "reverse", "model", "childNode", "limit", "offset"].forEach(key => {
            delete props[key];
        });
        return props;
    }

    render() {
        const props = this._getProps();

        const children = props.children;
        delete props.children;

        const childNodeList = this.getChildNodeList();

        const tagName = props.tagName || "div";
        delete props.tagName;

        if (childNodeList && childNodeList.length > 0) {
            return React.createElement(tagName, props, childNodeList);
        }

        const args = [tagName, props, undefined];
        if (Array.isArray(children)) {
            args.push(...children);
        } else {
            args.push(children);
        }

        return React.createElement(...args);
    }

    reRender() {
        delete this._childNodeList;
        this._updateView();
    }
}

module.exports = ReactCollectionView;
