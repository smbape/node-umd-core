import React from "%{ amd: 'react', common: '!React' }";
import _ from "%{amd: 'lodash', common: 'lodash', brunch: '!_', node: 'lodash'}";
import AbstractModelComponent from "./AbstractModelComponent";

const hasProp = Object.prototype.hasOwnProperty;
const {filter: _filter} = _;

const compareAttr = function(attr, coeff, a, b) {
    if (a[attr] > b[attr]) {
        return coeff;
    } else if (a[attr] < b[attr]) {
        return -coeff;
    }
    return 0;
};

const byAttribute = function(attr, reverse) {
    return compareAttr.bind(null, attr, reverse ? -1 : 1);
};

class ArrayComponent extends AbstractModelComponent {
    uid = `ArrayComponent${ (String(Math.random())).replace(/\D/g, "") }`;

    static getBinding(_binding) {
        _binding.get = binding => {
            return binding._ref instanceof ArrayComponent ? binding._ref.el : undefined;
        };
        return _binding;
    }

    preinit() {
        this.handleChange = this.handleChange.bind(this);
    }

    getFilter(query) {
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

            const regexp = new RegExp(query.replace(/([\\/^$.|?*+()[\]{}])/g, "\\$1"), "i");

            this.filterCache[query] = attributes => {
                for (const prop in attributes) {
                    if (!hasProp.call(attributes, prop)) {
                        continue;
                    }


                    if (regexp.test(attributes[prop])) {
                        return true;
                    }
                }

                return false;
            };

            return this.filterCache[query];
        }

        return null;
    }

    getComparator(comparator, reverse) {
        switch (typeof comparator) {
            case "string":
                return byAttribute(comparator, reverse);
            case "function":
                return comparator;
            default:
                return null;
        }
    }

    getSnapshotBeforeUpdate = null;

    componentDidUpdate(prevProps, prevState) {
        this.shouldUpdate = false;
        this.shouldUpdateEvent = false;
        this._updating = false;
        this.prevProps = Object.assign({}, this.props);
        this.prevState = Object.assign({}, this.state);
    }

    _updateNodeList(nextProps, nextState, prevProps, prevState) {
        const {
            collection: prevCollection,
            filter: prevFilter,
            order: prevOrder,
            reverse: prevReverse,
            limit: prevLimit,
            offset: prevOffset,
            childNode: prevChildNode
        } = this._getConfig(prevProps, prevState);

        const {
            collection: nextCollection,
            filter: nextFilter,
            order: nextOrder,
            reverse: nextReverse,
            limit: nextLimit,
            offset: nextOffset,
            childNode: nextChildNode
        } = this._getConfig(nextProps, nextState);

        if (prevCollection !== nextCollection) {
            delete this._childNodeList;
        } else if (prevFilter !== nextFilter && this.getFilter(prevFilter) !== this.getFilter(nextFilter)) {
            delete this._childNodeList;
        } else if (prevOrder !== nextOrder && this.getComparator(prevOrder, prevReverse) !== this.getComparator(nextOrder, nextReverse)) {
            const ordered = this._setOrderedArray(this._filtered, nextOrder, nextReverse);
            this._setNodeList(ordered, nextLimit, nextOffset, nextChildNode);
        } else if (prevReverse !== nextReverse) {
            const ordered = this._ordered.reverse();
            this._ordered = ordered;
            this._setNodeList(ordered, nextLimit, nextOffset, nextChildNode);
        } else if (prevLimit !== nextLimit || prevOffset !== nextOffset || prevChildNode !== nextChildNode) {
            this._setNodeList(this._ordered, nextLimit, nextOffset, nextChildNode);
        }
    }

    _getConfig(props, state) {
        const {
            collection,
            filter,
            order,
            reverse,
            limit,
            offset,
            childNode
        } = props || {};

        return {
            collection,
            filter,
            order,
            reverse: Boolean(reverse),
            limit,
            offset,
            childNode
        };
    }

    _setOrderedArray(filtered, order, reverse) {
        const comparator = this.getComparator(order, reverse);
        this._ordered = filtered.slice();

        if (comparator) {
            this._ordered.sort(comparator);
        }

        return this._ordered;
    }

    _setNodeList(ordered, limit, start, childNode) {
        const len = ordered.length;
        let end;

        if (limit > 0) {
            if (!(start > 0)) {
                start = 0;
            }
            end = limit + start;
            if (end > len) {
                end = len;
            }
        } else {
            start = 0;
            end = len;
        }

        const list = [];
        this._childNodeList = list;

        for (let i = start, index = 0; i < end; i++, index++) {
            const model = ordered[i];
            list[index] = childNode(model, index, ordered);
        }

        return list;
    }

    _getChildNodeList() {
        if (this._childNodeList) {
            return this._childNodeList;
        }

        this._childNodeList = [];

        const {collection, filter, order, reverse, limit, offset, childNode} = this._getConfig(this.props, this.state);

        if (!collection) {
            return this._childNodeList;
        }

        this._filtered = _filter(collection, this.getFilter(filter));
        const ordered = this._setOrderedArray(this._filtered, order, reverse);
        return this._setNodeList(ordered, limit, offset, childNode);
    }

    _getProps() {
        const props = Object.assign({}, this.props);

        ["collection", "filter", "order", "reverse", "limit", "offset", "childNode"].forEach(key => {
            delete props[key];
        });

        return props;
    }

    handleChange(evt) {
        evt.ref = this;
        const {onChange} = this.props;
        if (typeof onChange === "function") {
            onChange.apply(null, arguments);
        }
    }

    render() {
        this._updateNodeList(this.props, this.state, this.prevProps, this.prevState);

        const props = this._getProps();
        props.onChange = this.handleChange;
        const children = props.children;

        delete props.children;

        const childNodeList = this._getChildNodeList();
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
}

module.exports = ArrayComponent;
