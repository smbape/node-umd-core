deps = [
    '../common'
]

factory = ({ _, Backbone, $ })->
    hasProp = Object::hasOwnProperty
    slice = Array::slice

    attrSplitter = /(?:\\(.)|\.)/g

    byAttribute = byAttributes = (attrs, order)->
        # eval comparator function is faster than scoped comparator function
        order = if order < 0 or order is true then -1 else 1

        if 'string' is typeof attrs
            attrs = [attrs]

        if _.isArray attrs
            attrs = _.map attrs, (attr, index)->
                if _.isArray attr
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

        # will the loop exit with the correct solution?
        # 
        # known information:
        #   length: array length
        #   
        #   // compare preserve order
        #   known-compare-1: compare(a, b) > 0 <=> compare(b, a) < 0
        #   known-compare-2: compare(a, b) = 0 <=> compare(b, a) = 0
        #   known-compare-3: compare(a, b) >= 0 and compare(b, c) >= 0 => compare(a, c) >= 0
        #   known-compare-4: compare(a, b) > 0 and compare(b, c) >= 0 => compare(a, c) > 0
        #   known-compare-5: compare(a, b) >= 0 and compare(b, c) > 0 => compare(a, c) > 0
        #   known-compare-6: compare(a, b) <= 0 and compare(b, c) <= 0 => compare(a, c) <= 0
        #   known-compare-7: compare(a, b) < 0 and compare(b, c) <= 0 => compare(a, c) < 0
        #   known-compare-8: compare(a, b) <= 0 and compare(b, c) < 0 => compare(a, c) < 0
        #   
        #   // array is sorted using compare
        #   for any i1 <= i2 in array indexes, if i1 <= i2
        #       known-array-1: compare(array[i1], array[i2]) <= 0
        #       known-array-2: compare(array[i2], array[i1]) >= 0
        # 
        #   before 'while low isnt high'
        #       for any i in array indexes
        #           known-before-loop-1: low <= i
        #           => known-before-loop-2: compare(array[low], array[i]) <= 0 // known-before-loop-1 and known-array-1
        # 
        #   within loop before 'if cmp > 0'
        #       known-in-loop-1: low <= mid < high
        #       
        #       it is true for step0
        #           high = array.length
        #           low = 0
        #           low isnt high => low < high
        #           
        #       let's suppose it is true for stepn
        #       at stepn + 1
        #           low < high
        #           low + high < 2 * high
        #           mid = (low + high) / 2 < high
        #           
        #           low < high
        #           2 * low < low + high
        #           low < (low + high) / 2
        #           
        #           if low = 2l and high = 2h
        #               low < (low + high) / 2 = l + h
        #               Inf((low + high) / 2) = l + h
        #               low < Inf((low + high) / 2)
        #           else if low = 2l and high = 2h + 1
        #               low < (low + high) / 2 = l + h + 0.5
        #               Inf((low + high) / 2) = l + h
        #               
        #               low < high
        #               <=> 2l < 2h + 1
        #               => l <= h // Integer rule
        #               => 2l <= l + h
        #               <=> low <= l + h
        #               <=> low <=Inf((low + high) / 2)
        #           else if low = 2l + 1 and high = 2h
        #               low < (low + high) / 2 = l + h + 0.5
        #               Inf((low + high) / 2) = l + h
        #               
        #               low < high
        #               <=> 2l + 1 < 2h
        #               => 2l < 2h
        #               <=> l < h
        #               <=> 2l < l + h
        #               <=> 2l + 1 <= l + h // Integer rule
        #               <=> low <= Inf((low + high) / 2)
        # 
        #   within loop 
        #       known-in-loop-2: 0 <= low, high <= len
        #       
        #       it is true for step0
        #           high = array.length
        #           low = 0
        #           low isnt high => low < high
        #           
        #       let's suppose it is true for stepn
        #           if cmp > 0
        #               high = mid
        #               // high-stepn+1 = mid < high-stepn <= len // known-in-loop-1
        #               // 0 <= low-stepn = low-stepn+1
        #           else
        #               low = mid + 1
        #               // 0 <= low-stepn <= mid < mid + 1 = low-stepn+1 // known-in-loop-1
        #               // high-stepn+1 = high-stepn <= len
        # 
        # demonstration:
        #   all cases:
        #       length === 0
        #       compare(value, array[0]) < 0
        #       compare(array[length - 1], value) < 0
        #       all others
        #   
        #   case: length === 0
        #       low = hight = 0
        #       => return 0
        #       => OK
        #   
        #   case: compare(value, array[0]) < 0
        #       => for any i in array bound
        #           compare(array[0], array[i]) <= 0 // known-array-1 i1=0, i2=i
        #           compare(value, array[i]) < 0 // known-compare-7 a=value, b=array[0], c=array[i]
        #           compare(array[i], value) > 0 // known-compare-1
        #       => within loop, cmp is always > 0
        #       => high will always decrease
        #           before 'if cmp > 0', low <= mid < high // known-in-loop-1
        #           before new loop step, high = mid due to cmp > 0
        #           mid < high
        #           newHigh < high
        #           => high will always decrease
        #       => ultimately high = 0
        #       => exit loop with low = high = 0
        #       => return 0
        #       => OK
        #       
        #   case: compare(array[length - 1], value) < 0
        #       => for any i in array bound
        #           compare(array[i], array[length - 1]) <= 0 // known-array-1 i1=i, i2=length - 1
        #           compare(array[i], value) < 0 // known-compare-7 a=array[i], b=array[length - 1], c=value
        #       => within loop, cmp is always < 0
        #       => low will always increase
        #           before 'if cmp > 0', low <= mid < high // known-in-loop-1
        #           before new loop step, low = mid + 1 due to cmp < 0
        #           low <= mid < mid + 1
        #           low < newLow
        #           => low will always increase
        #       => ultimately low = len
        #       => exit loop with low = high = len
        #       => return len
        #       => OK
        #   
        #   case: others
        #       known-case-others1: compare(array[0], value) < 0 // not case compare(value, array[0]) < 0
        #       known-case-others2: compare(value, array[length - 1]) < 0 // not case compare(array[length - 1], value) < 0
        #       known-case-others3: length > 1
        #           if length is 1
        #               compare(array[0], value) < 0 // known-case-others1
        #               compare(value, array[0]) < 0 // known-case-others2
        #               => contradiction
        #       known-case-others3: compare(array[low], value) <= 0 except for exit loop value
        #           demonstration:
        #               compare(array[0], value) < 0 // known-case-others1
        #               compare(array[0], array[1]) <= 0 // known-array-1
        #               compare(value, array[length - 1]) < 0 // known-case-others2
        #               compare(array[1], array[length - 1]) <= 0 // known-array-1
        #               
        #               at step0, compare(array[low], value) <= 0
        #               let's suppose compare(array[low], value) <= 0 except for exit loop value at stepn
        #                   when low change
        #                   cmp = compare(array[mid], value)
        #                   cmp <= 0
        #                   
        #                   low-stepn+1 = mid + 1
        #                   if compare(array[low-stepn+1], value) > 0
        #                       <=> compare(array[mid + 1], value) > 0
        #                       compare(array[mid + 1], value) > 0
        #                       compare(value, array[low-stepn+1]) < 0
        #                       
        #                       at any step low <= mid // known-in-loop-1
        #                       low can remain unchanged between steps or increase // nextLow = mid + 1 > mid >= prevLow
        #                       => low-stepn+1 <= low-of-all-next-steps <= mid-of-all-next-steps
        #                       
        #                       compare(array[low-stepn+1], array[mid-of-all-next-steps]) <= 0 // known-array-1
        #                       => compare(value, array[mid-of-all-next-steps]) < 0
        #                           compare(value, array[low-stepn+1]) < 0
        #                           compare(array[low-stepn+1], array[mid-of-all-next-steps]) <= 0
        #                       <=> compare(array[mid-of-all-next-steps], value) > 0 // known-compare-1
        #                       
        #                       => all next steps cmp > 0
        #                       => low never changes
        #                       => exit loop value will be 
        #       
        #       the correct index verifies:
        #           if index < length
        #               compare(value, array[index]) < 0
        #               <=> compare(array[index], value) > 0
        #           if index > 1
        #               compare(array[index - 1], value) <= 0
        #               <=> compare(value, array[index - 1]) => 0
        # 
        #       + let's suppose we exit
        #           => low === high after 'if cmp > 0 ... else ...'
        #           before 'if cmp > 0', low <= mid < high // known-in-loop-1
        #               cmp = compare(array[mid], value)
        #               if cmp > 0
        #                   
        #                   high = mid
        #                   we are exiting => low === high = mid
        #                   compare(array[low], value) > 0 // first condition OK
        #                   
        #                   if low - 1 within array bounds
        #                       if compare(array[low - 1], value) > 0
        #                           low = low - 1 // first condition still OK
        #                       
        #                       compare(array[0], value) < 0
        #                       compare(value, array[length - 1]) < 0
        #                       // toutes les valeurs prises par low, en dehors de celle de sortie vérifient compare(array[low], value) <= 0
        #                       
        #                       => compare(array[low - 1], value) <= 0
        #               else
        #                   compare(array[mid], value) <= 0
        #                   compare(array[mid + 1], value) > 0
        #                   => all next cmp > 0
        #                   => low never changes
        #                   => exit value if exit
        #                   
        #                   low = mid + 1 => mid + 1 = low === high
        #                   
        #                   compare(array[mid], value) <= 0
        #                   <=> compare(array[low - 1], value) <= 0 // second condition OK
        #                   
        #                   if low within array bounds
        #                       => compare(array[low], value) > 0

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
            options = _.clone options
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

        addIndex: (name, attrs)->
            if 'string' is typeof attrs
                attrs = [attrs]

            if Array.isArray attrs
                this._keymap[name] = _.clone attrs
                if attrs.condition
                    this._keymap[name].condition = attrs.condition
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
                    found = this.byIndex model, indexName
                    break if found
                return found

            return if not hasProp.call this._keymap, indexName

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
            if not (model instanceof Backbone.Model)
                return

            if not name
                for name of this._keymap
                    this._indexModel model, name
                return

            attrs = this._keymap[name]
            if typeof attrs.condition is "function" and not attrs.condition(model, name)
                return

            chain = []
            for attr in attrs
                value = _lookup attr, model
                if value is undefined
                    return
                chain.push value

            key = this._keys[name]

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

        _removeIndex: (model, name)->
            if model instanceof Backbone.Model
                if not name
                    for name of this._keymap
                        this._removeIndex model, name
                    return

                # this._keys[name][prop1][prop2] = model
                attrs = this._keymap[name]
                len = attrs.length

                valueChain = new Array(len)
                for attr, i in attrs
                    # value = model.get attr
                    value = _lookup attr, model
                    if value is undefined
                        return
                    valueChain[i] = value

                key = this._keys[name]


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
            !!this.get(model) or -1 isnt this.indexOf model, options

        set: (models, options)->
            return if not models

            if not this.selector and not this.comparator
                return super

            options = _.defaults({}, options, setOptions);
            {merge, reset, silent, add, remove} = options

            res = []
            singular = !_.isArray(models)
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

            subSet = new this.constructor models, _.extend {
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

            # subSet.add = (models, options)->
            #     if not options?.reset
            #         throw new Error 'add is not allowed on a subSet'

            #     proto.add.call this, models, options

            subSet.parent = this

            subSet.populate = ->
                proto.reset.call this, this.parent.models, _.extend({sub: true, silent: true}, options)
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
                options = _.extend {bubble: 1}, collection
            else
                options = arguments[arguments.length - 1]
                options = _.extend {bubble: 0}, options
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

    _.extend BackboneCollection, {byAttribute, byAttributes, reverse}

    BackboneCollection
