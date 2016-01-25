deps = [
    '../common'
    '../GenericUtil'
]

factory = ({_, Backbone}, GenericUtil)->
    hasOwn = {}.hasOwnProperty

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

    class BackboneCollection extends Backbone.Collection
        constructor: (models, options = {})->

            proto = @constructor.prototype

            for own opt of options
                if opt.charAt(0) isnt '_'
                    currProto = proto
                    while currProto and not hasOwn.call(currProto, opt)
                        currProto = currProto.prototype

                    if currProto
                        @[opt] = options[opt]

            super

            collection = this

            collection._modelAttributes = new Backbone.Model options.attributes

            # TODO : destroy method
            collection._modelAttributes.on 'change', (model, options)->
                for attr of model.changed
                    collection.trigger 'change:' + attr, collection, model.attributes[attr], options
                collection.trigger 'change', collection, options
                return

            if 'function' is typeof options.selector
                collection.selector = options.selector

            collection._options = _.clone options

            collection._keymap = {}
            collection._keys = {}

            indexes = options.indexes or collection.indexes
            if _.isObject indexes
                for name, attrs of indexes
                    collection.addIndex name, attrs

            collection.on 'change', @_onChange

        unsetAttribute: (name)->
            this._modelAttributes.unset name
            this
        getAttribute: (name)->
            this._modelAttributes.get name
        setAttribute: (name, value)->
            switch arguments.length
                when 0
                    this._modelAttributes.set.call this._modelAttributes
                when 1
                    this._modelAttributes.set.call this._modelAttributes, arguments[0]
                else
                    this._modelAttributes.set.call this._modelAttributes, arguments[0], arguments[1]

            this
        attrToJSON: ->
            this._modelAttributes.toJSON()

        addIndex: (name, attrs)->
            if 'string' is typeof attrs
                attrs = [attrs]

            if Array.isArray attrs
                this._keymap[name] = attrs.slice()
                this._keys[name] = {}
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

                for value, index in chain
                    if index is chain.length - 1
                        break
                    if hasOwn key, value
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

                for value, index in chain
                    if not key or index is chain.length - 1
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
            if this.selector and not this.selector model
                index = this.indexOf model
                this.remove model, options
                return {remove: index}

            # maintain order
            if this.comparator
                at = GenericUtil.comparators.binaryIndex model, this.models, this.comparator
                index = this.indexOf model
                if at isnt index
                    at = this.models.length if at is -1
                    this.remove model, _.defaults {sort: false}, options
                    this.add model, _.defaults {sort: false}, options
                    return {remove: index, add: at}

            return

        add: (models, options = {})->
            return if not models

            res = []
            singular = !_.isArray(models)
            models = if singular then [models] else models
            actions = []
            {merge, silent} = options

            for model in models
                
                # if model exists
                # filter and order is already preserved
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
                            if hasOwn.call opts, 'remove'
                                actions.push ['remove', existing, opts.remove]

                            if hasOwn.call opts, 'add'
                                actions.push ['add', existing, opts.add]
                                res.push existing

                        continue
                    else
                        res.push existing
                        continue

                opts = _.defaults {sort: false, silent: true}, options

                if not model = this._prepareModel model, opts
                    continue

                # maintain filter
                if this.selector and not this.selector model
                    continue

                # maintain order
                if this.comparator
                    at = GenericUtil.comparators.binaryIndex model, this.models, this.comparator
                    opts.at = if at is -1 then this.models.length else at
                else
                    opts.at = this.models.length

                model = super model, opts
                res.push model
                actions.push ['add', model, opts.at]

            if not silent and actions.length
                for [name, model, index] in actions
                    model.trigger name, model, this, _.defaults {index}, options

                this.trigger 'update', this, options

            return if singular then res[0] else res

        getSubSet: (options)->
            options = _.extend {}, this._options, options
            subSet = new this.constructor this.models, options
            proto = this.constructor.prototype

            for method in ['add', 'remove', 'reset', 'move']
                do (method)->
                    subSet[method] = -> throw new Error method + ' is not allowed on a subSet'

            subSet.parent = this

            this.on 'change', (model, options)->
                if model is subSet.parent
                    attributes = model.changed
                    subSet.set attributes, options
                return

            this.on 'add', (model, options)->
                proto.add.call subSet, model
                return

            this.on 'remove', (model, options)->
                proto.remove.call subSet, model
                return

            this.on 'reset', (collection, options)->
                if collection is subSet.parent
                    proto.reset.call subSet, collection.models, options
                return

            subSet
