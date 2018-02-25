`
import _ from "%{amd: 'lodash', common: 'lodash', brunch: '!_', node: 'lodash'}";
import Backbone from "%{amd: 'backbone', common: 'backbone', brunch: '!Backbone', node: 'backbone'}";
`

hasProp = Object::hasOwnProperty
slice = Array::slice
push = Array::push

attrSplitter = /(?:\\(.)|\.)/g

byAttribute = byAttributes = (attrs, order)->
    # eval comparator function is faster than scoped comparator function
    order = if order < 0 or order is true then -1 else 1

    if 'string' is typeof attrs
        attrs = [attrs]

    if Array.isArray attrs
        attrs = _.map attrs, (attr, index)->
            if Array.isArray attr
                attr
            else
                [attr, order]
    else if _.isObject attrs
        attrs = _.map attrs, (order, attr)->
            [attr, if order < 0 then -1 else 1]
    else
        return -> true

    blocks = ["""
        "use strict";
        var res, left, right;

        if (a instanceof Backbone.Model) {
            a = a.attributes;
        }

        if (b instanceof Backbone.Model) {
            b = b.attributes;
        }
    """]

    for [attr, order] in attrs
        parts = []
        attrSplitter.lastIndex = 0
        lastIndex = attrSplitter.lastIndex

        while match = attrSplitter.exec(attr)
            if match[0] is "."
                parts.push attr.slice(lastIndex, match.index).replace(/\\/g, "")
                lastIndex = attrSplitter.lastIndex

        if lastIndex < attr.length
            parts.push attr.slice(lastIndex).replace(/\\/g, "")

        attr = parts.map((attr)-> JSON.stringify(attr)).join("][")

        blocks.push """
            left = a[#{ attr }];
            right = b[#{ attr }];

            if (left === right) {
                res = 0;
            } else if (left === undefined) {
                res = -1;
            } else if (right === undefined) {
                res = 1;
            } else {
                res = left > right ? #{order} : left < right ? #{-order} : 0;
            }

            if (res !== 0) {
                return res;
            }
        """

    blocks.push "return res;"

    fn = new Function('Backbone', 'a', 'b', blocks.join('\n\n'))
    return fn.bind(null, Backbone)

reverse = (compare)->
    return compare.original if compare.reverse and compare.original

    fn = (a, b)-> -compare(a, b)

    fn.reverse = true
    fn.original = compare
    fn.attribute = compare.attribute

    fn

# http://stackoverflow.com/questions/14415408/last-index-of-multiple-keys-using-binary-search
# where value should be inserted in an ordered array using compare
binarySearchInsert = (value, models, compare, options)->
    length = high = models.length
    low = 0

    if low is high
        return low

    if options
        { overrides } = options

    while low isnt high
        # known faster way to do InfInt (low + high) / 2
        mid = (low + high) >>> 1
        model = models[mid]
        if overrides and overrides[model.cid]
            model = overrides[model.cid]

        cmp = compare(model, value)

        if cmp > 0
            high = mid
        else
            low = mid + 1

    index = low

    if index < length
        # it must be the last occurence with same comparator
        model = models[index]
        if overrides and overrides[model.cid]
            model = overrides[model.cid]
        if compare(model, value) <= 0
            return ++index

    if index > 1
        # it must be the last occurence with same comparator
        model = models[index - 1]
        if overrides and overrides[model.cid]
            model = overrides[model.cid]
        if compare(model, value) > 0
            return --index

    return index

binarySearch = (value, models, compare, options)->
    index = binarySearchInsert(value, models, compare, options)

    { overrides } = options if options
    if index is 0
        indexes = [ index ]
    else if index is models.length
        indexes = [ index - 1 ]
    else
        indexes = [ index, index - 1 ]

    for index in indexes
        model = models[index]

        if overrides and overrides[model.cid]
            model = overrides[model.cid]

        if compare(model, value) is 0
            return index

    return -1

linearSearch = (value, array, compare, index)->
    if index is array.length
        --index
    mid = index

    while value isnt array[index] and (mid-- > 0) and compare(array[index], array[mid]) is 0
        index = mid
    return index

_lookup = (attr, model)->
    attr = attr.split '.'
    value = model
    for prop in attr
        if value instanceof Backbone.Model
            value = value.get prop
        else if _.isObject value
            value = value[prop]
        else
            value = undefined
            break
    value

setOptions = {add: true, merge: true, remove: true}

class BackboneCollection extends Backbone.Collection
    constructor: (models, options = {})->
        options = Object.assign {}, options
        if 'string' is typeof options.comparator
            options.comparator = byAttribute options.comparator

        for own opt of options
            if opt.charAt(0) isnt '_' and opt of this
                this[opt] = options[opt]

        if options.subset
            this.isSubset = true
            this.matches = {}

        collection = this

        if 'function' is typeof options.selector
            collection.selector = options.selector

        collection._keymap = {}
        collection._byIndex = {}

        indexes = options.indexes or collection.indexes
        if _.isObject indexes
            for name, attrs of indexes
                collection.addIndex name, attrs

        collection._modelAttributes = new Backbone.Model options.attributes

        # TODO : destroy method
        collection._modelAttributes.on 'change', (model, options)->
            for attr of model.changed
                collection.trigger 'change:' + attr, collection, model.attributes[attr], options
            collection.trigger 'change', collection, options
            return

        if not options.subset
            collection.on 'change', this._onChange

        this._uid = _.uniqueId 'BackboneCollection_'
        super(models, options)

    unsetAttribute: (name)->
        this._modelAttributes.unset name
        return
    getAttribute: (name)->
        this._modelAttributes.get name
    setAttribute: ->
        this._modelAttributes.set.call this._modelAttributes, arguments
        return
    attrToJSON: ->
        this._modelAttributes.toJSON()

    addIndex: (indexName, attrs)->
        if 'string' is typeof attrs
            attrs = [attrs]

        if Array.isArray attrs
            this._keymap[indexName] = Object.assign {}, attrs
            this._keymap[indexName].length = attrs.length
            if attrs.condition
                this._keymap[indexName].condition = attrs.condition
            this._byIndex[indexName] = {}

            if this.models
                options = {}
                for model in this.models
                    this._indexModel model, indexName, options

            return true

        return false

    get: (obj)->
        this.byIndex obj

    byIndex: (model, indexName, options)->
        if null is model or 'object' isnt typeof model
            return BackboneCollection.__super__.get.call this, model

        if model instanceof Backbone.Model
            found = BackboneCollection.__super__.get.call this, model
            return found if found
            model = model.toJSON()

        id = model[this.model::idAttribute]
        found = BackboneCollection.__super__.get.call this, id
        return found if found

        if not indexName
            for indexName of this._keymap
                found = this.byIndex model, indexName, options
                break if found
            return found

        return if not hasProp.call this._keymap, indexName
        partial = options and options.partial

        ref = this._keymap[indexName]
        obj = this._byIndex[indexName]
        for attr, index in ref
            value = _lookup attr, model

            if typeof value is "undefined" or typeof obj[value] is "undefined"
                if partial and partial is index
                    return this._getMatchingPartial(obj, index, ref)
                return

            obj = obj[value]
        obj

    _getMatchingPartial: (obj, index, ref)->
        res = []

        count = ref.length - index
        stack = [[obj, count]]
        while item = stack.pop()
            [obj, count] = item
            if count is 1
                push.apply res, Object.keys(obj).map (key)-> obj[key]
            else
                count--
                push.apply stack, Object.keys(obj).map (key)-> [ obj[key], count ]

        if this.comparator
            res.sort(this.comparator)

        return res

    _addReference: (model, options)->
        super
        this._indexModel model, null, options
        return

    _indexModel: (model, indexName, options)->
        if not (model instanceof Backbone.Model)
            return

        if not indexName
            for indexName of this._keymap
                this._indexModel model, indexName, options
            return

        attrs = this._keymap[indexName]
        if typeof attrs.condition is "function" and not attrs.condition(model, indexName)
            return

        chain = []
        for attr in attrs
            value = _lookup attr, model
            if value is undefined
                return
            chain.push value

        key = this._byIndex[indexName]

        length = chain.length
        for value, index in chain
            if index is length - 1
                break
            if hasProp.call key, value
                key = key[value]
            else
                key = key[value] = {}

        key[value] = model

        return

    _removeReference: (model, options)->
        this._removeIndex model
        super
        return

    _removeIndex: (model, indexName)->
        if model instanceof Backbone.Model
            if not indexName
                for indexName of this._keymap
                    this._removeIndex model, indexName
                return

            attrs = this._keymap[indexName]
            len = attrs.length

            valueChain = new Array(len)
            for attr, i in attrs
                # value = model.get attr
                value = _lookup attr, model
                if value is undefined
                    return
                valueChain[i] = value

            key = this._byIndex[indexName]

            keyChain = new Array(len - 1)

            for value, i in valueChain
                if not key or i is len - 1
                    break
                keyChain[i] = [ key, value ]
                key = key[value]

            if key
                delete key[value]
                for i in [(len - 2)..0] by -1
                    [ obj, key ] = keyChain[i]
                    if Object.keys(obj[key]).length is 0
                        delete obj[key]

        return

    _getClone: (model)->
        _model = this.get model
        if _model
            _model = new _model.constructor _model.attributes
            if model instanceof Backbone.Model
                _model.set model.attributes
            else
                _model.set model
        _model

    _onChange: (model, collection, options)->
        if model isnt this
            this._ensureEntegrity model, options
        return

    _ensureEntegrity: (model, options)->
        # maintain filter
        if this.selector and not (match = this.selector model)
            if this.isSubset
                delete this.matches[model.cid]
            index = this.indexOf model
            this.remove model, _.defaults {bubble: 0, sort: false}, options
            return {remove: index}

        # maintain order
        if this.comparator
            at = this.insertIndexOf model
            index = this.indexOf model

            if index isnt -1
                if at > index
                    # remove index will cause insert index to decrease
                    at--

            if at isnt index
                if this.isSubset
                    delete this.matches[model.cid]

                if index isnt -1
                    this.remove model, _.defaults {bubble: 0, sort: false}, options

                if this.isSubset
                    this.matches[model.cid] = match
                this.add model, _.defaults {bubble: 0, sort: false, match}, options
                return {remove: index, add: at, match}

        return

    insertIndexOf: (model, options)->
        size = this.length
        return size if not size

        if compare = this.comparator
            if _model = this.get model
                model = _model

            models = this.models

            at = binarySearchInsert model, models, compare, options
        else
            at = this.indexOf model, options

        if at is -1 then size else at

    indexOf: (model, options)->
        size = this.length
        return -1 if not size

        if compare = this.comparator
            models = this.models

            if _model = this.get model
                index = binarySearch _model, models, compare, options
                if index isnt -1 and models[index] is _model
                    return index

                overrides = {}
                overrides[model.cid] = model._previousAttributes
                index = binarySearch model._previousAttributes, models, compare, _.defaults({overrides, model: _model}, options)
                return index

            # index = binarySearch model, models, this.comparator, options
            # return index
            return -1
        else
            super

    contains: (model, options)->
        Boolean(this.get(model)) or -1 isnt this.indexOf model, options

    set: (models, options)->
        return if not models

        if not this.selector and not this.comparator
            return super

        options = _.defaults({}, options, setOptions);
        {merge, reset, silent, add, remove} = options

        res = []
        singular = !Array.isArray(models)
        models = if singular then [models] else models
        actions = []

        if remove
            toRemove = this.clone()

        for model in models
            if existing = this.get model
                hasChanged = false

                if merge and model isnt existing
                    attrs = if this._isModel(model) then model.attributes else model
                    if options.parse
                        attrs = existing.parse(attrs, options)
                    existing.set attrs, options

                    hasChanged = not _.isEmpty existing.changed

                if hasChanged
                    opts = this._ensureEntegrity existing, _.defaults {silent: true}, options

                    if opts
                        if hasProp.call opts, 'add'
                            actions.push ['move', existing, opts.add, opts.remove, opts.match]
                            res.push existing

                        else if hasProp.call opts, 'remove'
                            actions.push ['remove', existing, opts.remove]
                    else
                        res.push existing
                else
                    res.push existing

                continue

            continue if not add

            if not model = this._prepareModel model, opts
                continue

            # maintain filter
            if this.selector and not (match = this.selector model)
                continue

            at = this.length

            # maintain order
            if this.comparator and options.sort isnt false
                at = this.insertIndexOf model

            this._addReference model, _.defaults({at}, options)
            this.models.splice at, 0, model
            this.length++

            res.push model
            actions.push ['add', model, at, null, match]
            if this.isSubset
                this.matches[model.cid] = match

        if toRemove
            toRemove.remove res
            this._removeModels toRemove.models, options

        if not silent and actions.length
            for [name, model, index, from, match] in actions
                model.trigger name, model, this, _.defaults {index, from, match}, options

            this.trigger 'update', this, options

        return if singular then res[0] else res

    clone: ->
        new this.constructor this.models,
            model: this.model
            comparator: this.comparator
            selector: this.selector

    getSubSet: (options = {})->
        if not options.comparator and not options.selector
            return this

        if options.models is false
            models = []
        else
            models = this.models

        subSet = new this.constructor models, Object.assign {
            model: this.model
            comparator: this.comparator
            selector: this.selector
            subset: true
        }, options
        proto = this.constructor.prototype

        for method in ['add', 'remove', 'reset']
            do (method)->
                subSet[method] = (models, options)->
                    if not options?.sub
                        throw new Error method + ' is not allowed on a subSet'
                    proto[method].call this, models, options
                return

        subSet.parent = this

        subSet.populate = ->
            proto.reset.call this, this.parent.models, Object.assign({sub: true, silent: true}, options)
            return

        subSet.attachEvents = ->
            this.parent.on 'change', this._onChange = (model, collection, options)->
                if not this.destroyed
                    if not options
                        options = collection

                    if model is this.parent
                        attributes = model.changed
                        this.set attributes, options
                    else if options.bubble is 1
                        # maintain filter
                        if not this.parent.contains(model)
                            if this.contains(model)
                                proto.remove.call this, model
                        else if this.selector and not this.selector model
                            proto.remove.call this, model

                        else if this.contains(model)
                            # avoid circular event change
                            #   set -> _ensureEntegrity -> add -> set -> _ensureIntegrity -> add -> set
                            # this.set model, _.defaults {bubble: 0, sub: true}, options

                            silent = options.silent
                            match = this.selector and this.selector model

                            # maintain order
                            if this.comparator
                                compare = this.comparator
                                from = this.indexOf model

                                if from isnt 0
                                    # check if current model is at correct index
                                    overrides = compare(this.models[from - 1], model) > 0

                                if not overrides and from isnt this.length - 1
                                    # check if current model is at correct index
                                    overrides = compare(model, this.models[from + 1]) > 0

                                if not overrides
                                    return

                                overrides = {}
                                overrides[model.cid] = model._previousAttributes
                                index = this.insertIndexOf model, _.defaults({overrides}, options)

                                if from < index
                                    index--

                                if from is index
                                    return

                                expectedModels = this.models.slice()

                                expectedModels.splice(from, 1)
                                this.remove model, _.defaults {bubble: 0, sub: true, silent: true}, options

                                expectedModels.splice(index, 0, model)
                                this.add model, _.defaults {bubble: 0, match, sub: true, silent: true}, options

                                if not silent
                                    model.trigger 'move', model, this, _.defaults {index, from, match, bubble: 0}, options

                        else
                            proto.add.call this, model
                return
            , this

            this.parent.on 'add', this._onAdd = (model, collection, options)->
                if not this.destroyed and collection is this.parent
                    proto.add.call this, model, _.defaults {bubble: 0, sort: true}, options
                return
            , this

            this.parent.on 'remove', this._onRemove = (model, collection, options)->
                if not this.destroyed and collection is this.parent
                    proto.remove.call this, model, _.defaults {bubble: 0}, options
                return
            , this

            this.parent.on 'reset', this._onReset = (collection, options)->
                if not this.destroyed and collection is this.parent
                    proto.reset.call this, collection.models, _.defaults {bubble: 0, sub: true}, options
                return
            , this

            return

        subSet.detachEvents = ->
            parent = this.parent
            parent.off 'change', this._onChange, this
            parent.off 'add', this._onAdd, this
            parent.off 'remove', this._onRemove, this
            parent.off 'reset', this._onReset, this
            return

        subSet.destroy = ->
            this.detachEvents()

            for own prop of this
                if prop isnt '_uid'
                    delete this[prop]

            # may be destroyed was executed during an event handling
            # therefore, callbacks will still be processed
            # this.destroyed helps skipping callback if needed
            this.destroyed = true
            return
        
        if options.models isnt false
            subSet.attachEvents()

        subSet

    _onModelEvent: (event, model, collection, options) ->
        if this.destroyed
            return

        if event in ['add', 'remove'] and collection isnt this
            return

        if event is 'destroy'
            this.remove model, options

        else if event is 'change'
            prevId = this.modelId(model.previousAttributes())
            id = this.modelId(model.attributes)
            if prevId isnt id
                if prevId isnt null
                    delete this._byId[prevId]
                if id isnt null
                    this._byId[id] = model

        if arguments.length is 3
            options = Object.assign {bubble: 1}, collection
        else
            options = arguments[arguments.length - 1]
            options = Object.assign {bubble: 0}, options
            ++options.bubble

        if event in ['sync', 'request']
            this.trigger event, model, collection, this, options
        else
            this.trigger event, model, this, options

        return

    _removeModels: (models, options)->
        removed = []

        i = 0
        len = models.length

        while i < len
            model = this.get(models[i])
            if !model
                i++
                continue

            index = this.indexOf(model)
            this.models.splice index, 1
            this.length--

            # Remove references before triggering 'remove' event to prevent an
            # infinite loop. #3693
            delete this._byId[model.cid]
            this._removeIndex(model)

            id = this.modelId(model.attributes)
            if id not in [ null, undefined ]
                delete this._byId[id]

            if !options.silent
                options.index = index
                model.trigger 'remove', model, this, options

            removed.push model
            this._removeReference model, options
            i++
        return removed

Object.assign BackboneCollection, {byAttribute, byAttributes, reverse}

module.exports = BackboneCollection
