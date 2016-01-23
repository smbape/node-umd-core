deps = [
    '../common'
    '../GenericUtil'
]

factory = ({_, Backbone}, GenericUtil)->

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

            collection._options = _.extend {strict: true}, options

            collection._keymap = {}
            collection._keys = {}

            indexes = options.indexes or collection.indexes
            if _.isObject indexes
                for name, attrs of indexes
                    collection.addIndex name, attrs

            if collection._options.strict
                collection.on 'change', (model, options)->
                    if model isnt this
                        # maintain filter
                        if this.selector and not this.selector model
                            this.remove model
                            return

                        # maintain order
                        if this.comparator
                            at = GenericUtil.comparators.binaryIndex model, this.models, this.comparator
                            index = this.indexOf model
                            if at isnt index
                                this.remove model
                                this.add model
                    return

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

            return if not this._keymap.hasOwnProperty indexName

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
                    if key.hasOwnProperty value
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

        add: (models, options = {})->
            if options.merge
                if Array.isArray models
                    for model, index in models
                        _model = this._getClone model
                        models[index] = _model if _model
                else
                    _model = this._getClone models
                    models = _model if _model

            # maintain filter
            if this.selector
                models = _.filter models, this.selector

            super models, options

        getSubSet: (options)->
            options = _.extend {}, this._options, options
            subSet = new this.constructor this.models, options

            subSet.parent = this

            this.on 'change', (model, options)->
                if model is subSet.parent
                    attributes = model.changed
                    subSet.set attributes, options
                return

            this.on 'add', (model)->
                subSet.add model
                return

            this.on 'remove', (model)->
                subSet.remove model
                return

            this.on 'reset', (models, options)->
                subSet.reset models, _.extend {proxy: true}, options
                return

            reset = subSet.reset
            subSet.reset = (models, options = {})->
                if options.proxy
                    reset.apply @, arguments
                return

            subSet
