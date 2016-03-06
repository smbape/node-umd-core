deps = [
    '../common'
]

factory = ({_, Backbone})->
    hasOwn = {}.hasOwnProperty
    slice = [].slice

    compareAttr = (a, b, attr, order)->
        if a instanceof Backbone.Model
            a = a.attributes
        if b instanceof Backbone.Model
            b = b.attributes

        if a[attr] > b[attr]
            order
        else if a[attr] < b[attr]
            -order
        else
            0

    byAttribute = (attr, order)->
        order = if order < 0 then -1 else 1
        fn = (a, b)->
            compareAttr a, b, attr, order

        fn.attribute = attr
        fn

    byAttributes = (attributes, order)->
        order = if order < 0 then -1 else 1
        if _.isArray attributes
            attributes = _.map attributes, (attr, index)->
                if _.isArray attr
                    attr
                else
                    [attr, order]
        else if _.isObject attributes
            attributes = _.map attributes, (attr, order)->
                [attr, if order < 0 then -1 else 1]
        else
            return -> true

        (a, b)->
            for [attr, order] in attributes
                if 0 isnt (res = compareAttr(a, b, attr, order))
                    return res

            0

    reverse = (compare)->
        return compare.original if compare.reverse and compare.original

        fn = (a, b)-> -compare(a, b)

        fn.reverse = true
        fn.original = compare
        fn.attribute = compare.attribute

        fn

    binaryIndex = (value, array, compare, fromIndex = 0, indexOf)->
        if fromIndex < 0
            high = array.length
            low = high - fromIndex
        else
            high = array.length
            low = fromIndex

        while low < high
            mid = (low + high) >> 1
            if 0 > compare array[mid], value
                low = mid + 1
            else
                high = mid

        if indexOf
            if array[low] is value then low else -1
        else
            low

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

    uid = 'BackboneCollection' + ('' + Math.random()).replace(/\D/g, '') + '_'

    class BackboneCollection extends Backbone.Collection
        constructor: (models, options = {})->

            options = _.clone options
            if 'string' is typeof options.comparator
                options.comparator = byAttribute options.comparator
            proto = @constructor.prototype

            for own opt of options
                if opt.charAt(0) isnt '_'
                    currProto = proto
                    while currProto and not hasOwn.call(currProto, opt)
                        currProto = currProto.constructor?.__super__

                    if currProto
                        @[opt] = options[opt]

            if options.subset
                @isSubset = true
                @matches = {}

            collection = this

            if 'function' is typeof options.selector
                collection.selector = options.selector

            collection._keymap = {}
            collection._keys = {}

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
                collection.on 'change', @_onChange

            @_uid = _.uniqueId uid
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

        addIndex: (name, attrs)->
            if 'string' is typeof attrs
                attrs = [attrs]

            if Array.isArray attrs
                this._keymap[name] = attrs.slice()
                this._keys[name] = {}

                if this.models
                    for model in this.models
                        this._indexModel model, name

                return true

            return false

        get: (obj)->
            this.byIndex obj

        byIndex: (model, indexName)->
            if null is model or 'object' isnt typeof model
                return BackboneCollection.__super__.get.call @, model

            if model instanceof Backbone.Model
                found = BackboneCollection.__super__.get.call @, model
                return found if found
                model = model.toJSON()

            id = model[this.model::idAttribute]
            found = BackboneCollection.__super__.get.call @, id
            return found if found

            if not indexName
                for indexName of this._keymap
                    found = this.byIndex model, indexName
                    break if found
                return found

            return if not hasOwn.call this._keymap, indexName

            ref = this._keymap[indexName]
            key = this._keys[indexName]
            for attr, index in ref
                value = _lookup attr, model
                key = key[value]
                if 'undefined' is typeof key
                    break

            key

        _addReference: (model, options)->
            super
            this._indexModel model
            return

        _indexModel: (model, name)->
            if model instanceof Backbone.Model
                if not name
                    for name of this._keymap
                        this._indexModel model, name
                    return

                attrs = this._keymap[name]
                chain = []
                for attr in attrs
                    value = _lookup attr, model
                    if 'undefined' is typeof value
                        return
                    chain.push value

                key = this._keys[name]

                length = chain.length
                for value, index in chain
                    if index is length - 1
                        break
                    if hasOwn.call key, value
                        key = key[value]
                    else
                        key = key[value] = {}

                key[value] = model

            return

        _removeReference: (model, options)->
            super
            this._removeIndex model
            return

        _removeIndex: (model, name)->
            if model instanceof Backbone.Model
                if not name
                    for name of this._keymap
                        this._removeIndex model, name
                    return

                # this._keys[name][prop1][prop2] = model
                attrs = this._keymap[name]
                chain = []
                for attr in attrs
                    # value = model.get attr
                    value = _lookup attr, model
                    if 'undefined' is typeof value
                        return
                    chain.push value

                key = this._keys[name]

                length = chain.length
                for value, index in chain
                    if not key or index is length - 1
                        break
                    key = key[value]

                delete key[value] if key

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

        _onChange: (model, options)->
            if model isnt this
                @_ensureEntegrity model, options
            return

        _ensureEntegrity: (model, options)->
            # maintain filter
            if this.selector and not (match = this.selector model)
                if @isSubset
                    delete @matches[model.cid]
                index = this.indexOf model
                this.remove model, _.defaults {bubble: 0, sort: false}, options
                return {remove: index}

            # maintain order
            if this.comparator
                at = binaryIndex model, this.models, this.comparator
                index = this.indexOf model
                if at isnt index
                    at = this.length if at is -1

                    if @isSubset
                        delete @matches[model.cid]
                    this.remove model, _.defaults {bubble: 0, sort: false}, options

                    if @isSubset
                        @matches[model.cid] = match
                    this.add model, _.defaults {bubble: 0, sort: false, match}, options
                    return {remove: index, add: at, match}

            return

        indexOf: (model, options)->
            if this.comparator
                return binaryIndex model, this.models, this.comparator, 0, true
            else
                super

        contains: (model, options)->
            -1 isnt @indexOf model, options

        add: (models, options = {})->
            return if not models

            res = []
            singular = !_.isArray(models)
            models = if singular then [models] else models
            actions = []
            {merge, reset, silent} = options

            for model in models
                if existing = this.get model
                    hasChanged = false

                    if merge and model isnt existing
                        attrs = if @_isModel(model) then model.attributes else model
                        if options.parse
                            attrs = existing.parse(attrs, options)
                        existing.set attrs, options
                        hasChanged = not _.isEmpty existing.changed

                    if hasChanged
                        opts = @_ensureEntegrity existing, _.defaults {silent: true}, options

                        if opts
                            if hasOwn.call opts, 'add'
                                actions.push ['move', existing, opts.add, opts.remove, opts.match]
                                res.push existing

                            else if hasOwn.call opts, 'remove'
                                actions.push ['remove', existing, opts.remove]
                        else
                            res.push existing
                        continue
                    else
                        res.push existing
                        continue

                opts = _.defaults {sort: false, silent: true}, options

                if not model = this._prepareModel model, opts
                    continue

                # maintain filter
                if this.selector and not (match = this.selector model)
                    continue

                # maintain order
                if this.comparator
                    at = binaryIndex model, this.models, this.comparator
                    opts.at = if at is -1 then this.length else at
                else
                    opts.at = this.length

                model = super model, opts
                res.push model
                actions.push ['add', model, opts.at, null, match]
                if @isSubset
                    @matches[model.cid] = match

            if not silent and actions.length
                for [name, model, index, from, match] in actions
                    model.trigger name, model, this, _.defaults {index, from, match}, options

                this.trigger 'update', this, options

            return if singular then res[0] else res

        clone: ->
            new this.constructor this.models,
                model: @model
                comparator: @comparator
                selector: @selector

        getSubSet: (options = {})->
            if not options.comparator and not options.selector
                return @

            subSet = new this.constructor this.models, _.extend {
                model: @model
                comparator: @comparator
                selector: @selector
                subset: true
            }, options
            proto = this.constructor.prototype

            for method in ['remove', 'reset', 'move']
                do (method)->
                    subSet[method] = -> throw new Error method + ' is not allowed on a subSet'
                    return

            subSet.add = (models, options)->
                if not options?.reset
                    throw new Error 'add is not allowed on a subSet'

                proto.add.call @, models, options
            subSet.parent = this

            this.on 'change', subSet._onChange = (model, options)->
                if not @destroyed
                    if model is @parent
                        attributes = model.changed
                        @set attributes, options
                    else if options.bubble is 1
                        # maintain filter and order
                        if not @parent.contains(model)
                            if @contains(model)
                                proto.remove.call @, model
                        else if @selector and not @selector model
                            proto.remove.call @, model
                        else
                            proto.add.call @, model
                return
            , subSet

            this.on 'add', subSet._onAdd = (model, collection, options)->
                if not @destroyed and collection is @parent
                    proto.add.call @, model
                return
            , subSet

            this.on 'remove', subSet._onRemove = (model, collection, options)->
                if not @destroyed and collection is @parent
                    proto.remove.call @, model
                return
            , subSet

            this.on 'reset', subSet._onReset = (collection, options)->
                if not @destroyed and collection is @parent
                    proto.reset.call @, collection.models, _.defaults {reset: true}, options
                return
            , subSet

            subSet.destroy = ->
                parent = @parent
                parent.off 'change', @_onChange, @
                parent.off 'add', @_onAdd, @
                parent.off 'remove', @_onRemove, @
                parent.off 'reset', @_onReset, @

                for own prop of @
                    delete @[prop]

                # may be destroyed was executed during an event handling
                # therefore, callbacks will still be processed
                # this.destroyed helps skipping callback if needed
                @destroyed = true
                return

            subSet

        _onModelEvent: (event, model, collection, options) ->
            if (event is 'add' or event is 'remove') and collection isnt this
                return
            if event is 'destroy'
                @remove model, options
            if event is 'change'
                prevId = @modelId(model.previousAttributes())
                id = @modelId(model.attributes)
                if prevId != id
                    if prevId != null
                        delete @_byId[prevId]
                    if id != null
                        @_byId[id] = model

            if 'undefined' is typeof options
                options = _.extend {}, collection
                if options.bubble
                    ++options.bubble
                else
                    (options.bubble = 1)
                @trigger event, model, options
            else
                options = _.extend {}, options
                if options.bubble
                    ++options.bubble
                else
                    (options.bubble = 1)
                @trigger event, model, collection, options
            return

    _.extend BackboneCollection, {byAttribute, byAttributes, reverse}

    BackboneCollection
