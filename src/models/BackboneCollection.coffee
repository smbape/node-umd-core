deps = [
    '../common'
]

factory = ({ _, Backbone, $ })->
    hasProp = Object::hasOwnProperty
    slice = Array::slice

    compareAttr = (attr, order)->
        """
            left = a[#{JSON.stringify(attr)}];
            right = b[#{JSON.stringify(attr)}];
            res = left > right ? #{order} : left < right ? #{-order} : 0;
        """

    byAttribute = byAttributes = (attrs, order)->
        # way faster comparator function
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
            attrs = _.map attrs, (attr, order)->
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
            blocks.push """
            left = a[#{JSON.stringify(attr)}];
            right = b[#{JSON.stringify(attr)}];

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

        ### jshint evil: true ###
        return new Function('a', 'b', blocks.join('\n\n'))
        ### jshint evil: false ###

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
                if opt.charAt(0) isnt '_' and opt of @
                    @[opt] = options[opt]

            if options.subset
                @isSubset = true
                @matches = {}

            collection = @

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

            @_uid = _.uniqueId 'BackboneCollection_'
            super(models, options)

        unsetAttribute: (name)->
            @_modelAttributes.unset name
            return
        getAttribute: (name)->
            @_modelAttributes.get name
        setAttribute: ->
            @_modelAttributes.set.call @_modelAttributes, arguments
            return
        attrToJSON: ->
            @_modelAttributes.toJSON()

        addIndex: (name, attrs)->
            if 'string' is typeof attrs
                attrs = [attrs]

            if Array.isArray attrs
                @_keymap[name] = attrs.slice()
                @_keys[name] = {}

                if @models
                    for model in @models
                        @_indexModel model, name

                return true

            return false

        get: (obj)->
            @byIndex obj

        byIndex: (model, indexName)->
            if null is model or 'object' isnt typeof model
                return BackboneCollection.__super__.get.call @, model

            if model instanceof Backbone.Model
                found = BackboneCollection.__super__.get.call @, model
                return found if found
                model = model.toJSON()

            id = model[@model::idAttribute]
            found = BackboneCollection.__super__.get.call @, id
            return found if found

            if not indexName
                for indexName of @_keymap
                    found = @byIndex model, indexName
                    break if found
                return found

            return if not hasProp.call @_keymap, indexName

            ref = @_keymap[indexName]
            key = @_keys[indexName]
            for attr, index in ref
                value = _lookup attr, model
                key = key[value]
                if 'undefined' is typeof key
                    break

            key

        _addReference: (model, options)->
            super
            @_indexModel model
            return

        _indexModel: (model, name)->
            if not (model instanceof Backbone.Model)
                return

            if not name
                for name of @_keymap
                    @_indexModel model, name
                return

            attrs = @_keymap[name]
            if typeof attrs.condition is "function" and not attrs.condition(model, name)
                return

            chain = []
            for attr in attrs
                value = _lookup attr, model
                if value is undefined
                    return
                chain.push value

            key = @_keys[name]

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
            @_removeIndex model
            super
            return

        _removeIndex: (model, name)->
            if model instanceof Backbone.Model
                if not name
                    for name of @_keymap
                        @_removeIndex model, name
                    return

                # @_keys[name][prop1][prop2] = model
                attrs = @_keymap[name]
                chain = []
                for attr in attrs
                    # value = model.get attr
                    value = _lookup attr, model
                    if value is undefined
                        return
                    chain.push value

                key = @_keys[name]

                length = chain.length
                for value, index in chain
                    if not key or index is length - 1
                        break
                    key = key[value]

                delete key[value] if key

            return

        _getClone: (model)->
            _model = @get model
            if _model
                _model = new _model.constructor _model.attributes
                if model instanceof Backbone.Model
                    _model.set model.attributes
                else
                    _model.set model
            _model

        _onChange: (model, collection, options)->
            if model isnt @
                @_ensureEntegrity model, options
            return

        _ensureEntegrity: (model, options)->
            # maintain filter
            if @selector and not (match = @selector model)
                if @isSubset
                    delete @matches[model.cid]
                index = @indexOf model
                @remove model, _.defaults {bubble: 0, sort: false}, options
                return {remove: index}

            # maintain order
            if @comparator
                at = @insertIndexOf model
                index = @indexOf model

                if index isnt -1
                    if at > index
                        # remove index will cause insert index to decrease
                        at--

                if at isnt index
                    if @isSubset
                        delete @matches[model.cid]

                    if index isnt -1
                        @remove model, _.defaults {bubble: 0, sort: false}, options

                    if @isSubset
                        @matches[model.cid] = match
                    @add model, _.defaults {bubble: 0, sort: false, match}, options
                    return {remove: index, add: at, match}

            return

        insertIndexOf: (model, options)->
            size = @length
            return size if not size

            if compare = @comparator
                if _model = @get model
                    model = _model

                models = @models

                at = binarySearchInsert model, models, compare, options
            else
                at = @indexOf model, options

            if at is -1 then size else at

        indexOf: (model, options)->
            size = @length
            return -1 if not size

            if compare = @comparator
                models = @models

                if _model = @get model
                    index = binarySearch _model, models, compare, options
                    if index isnt -1 and models[index] is _model
                        return index

                    overrides = {}
                    overrides[model.cid] = model._previousAttributes
                    index = binarySearch model._previousAttributes, models, compare, _.defaults({overrides, model: _model}, options)
                    return index

                # index = binarySearch model, models, @comparator, options
                # return index
                return -1
            else
                super

        contains: (model, options)->
            !!@get(model) or -1 isnt @indexOf model, options

        set: (models, options)->
            return if not models

            if not @selector and not @comparator
                return super

            options = _.defaults({}, options, setOptions);
            {merge, reset, silent, add, remove} = options

            res = []
            singular = !_.isArray(models)
            models = if singular then [models] else models
            actions = []

            if remove
                toRemove = @clone()

            for model in models
                if existing = @get model
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

                if not model = @_prepareModel model, opts
                    continue

                # maintain filter
                if @selector and not (match = @selector model)
                    continue

                at = @length

                # maintain order
                if @comparator and options.sort isnt false
                    at = @insertIndexOf model

                @_addReference model, _.defaults({at}, options)
                @models.splice at, 0, model
                @length++

                res.push model
                actions.push ['add', model, at, null, match]
                if @isSubset
                    @matches[model.cid] = match

            if toRemove
                toRemove.remove res
                @_removeModels toRemove.models, options

            if not silent and actions.length
                for [name, model, index, from, match] in actions
                    model.trigger name, model, @, _.defaults {index, from, match}, options

                @trigger 'update', @, options

            return if singular then res[0] else res

        clone: ->
            new @constructor @models,
                model: @model
                comparator: @comparator
                selector: @selector

        getSubSet: (options = {})->
            if not options.comparator and not options.selector
                return @

            if options.models is false
                models = []
            else
                models = @models

            subSet = new @constructor models, _.extend {
                model: @model
                comparator: @comparator
                selector: @selector
                subset: true
            }, options
            proto = @constructor.prototype

            for method in ['add', 'remove', 'reset']
                do (method)->
                    subSet[method] = (models, options)->
                        if not options?.sub
                            throw new Error method + ' is not allowed on a subSet'
                        proto[method].call @, models, options
                    return

            # subSet.add = (models, options)->
            #     if not options?.reset
            #         throw new Error 'add is not allowed on a subSet'

            #     proto.add.call @, models, options

            subSet.parent = @

            subSet.populate = ->
                proto.reset.call @, @parent.models, _.extend({sub: true, silent: true}, options)
                return

            subSet.attachEvents = ->
                @parent.on 'change', @._onChange = (model, collection, options)->
                    if not @destroyed
                        if not options
                            options = collection

                        if model is @parent
                            attributes = model.changed
                            @set attributes, options
                        else if options.bubble is 1
                            # maintain filter
                            if not @parent.contains(model)
                                if @contains(model)
                                    proto.remove.call @, model
                            else if @selector and not @selector model
                                proto.remove.call @, model

                            else if @contains(model)
                                # avoid circular event change
                                #   set -> _ensureEntegrity -> add -> set -> _ensureIntegrity -> add -> set
                                # @set model, _.defaults {bubble: 0, sub: true}, options

                                silent = options.silent
                                match = @selector and @selector model

                                # maintain order
                                if @comparator
                                    compare = @comparator
                                    from = @indexOf model

                                    if from isnt 0
                                        # check if current model is at correct index
                                        overrides = compare(@models[from - 1], model) > 0

                                    if not overrides and from isnt @length - 1
                                        # check if current model is at correct index
                                        overrides = compare(model, @models[from + 1]) > 0

                                    if not overrides
                                        return

                                    overrides = {}
                                    overrides[model.cid] = model._previousAttributes
                                    index = @insertIndexOf model, _.defaults({overrides}, options)

                                    if from < index
                                        index--

                                    if from is index
                                        return

                                    expectedModels = @models.slice()

                                    expectedModels.splice(from, 1)
                                    @remove model, _.defaults {bubble: 0, sub: true, silent: true}, options

                                    # if not _.isEqual(expectedModels, @models)
                                    #     debugger

                                    expectedModels.splice(index, 0, model)
                                    @add model, _.defaults {bubble: 0, match, sub: true, silent: true}, options

                                    # if not _.isEqual(expectedModels, @models)
                                    #     debugger

                                    if not silent
                                        model.trigger 'move', model, @, _.defaults {index, from, match, bubble: 0}, options

                            else
                                proto.add.call @, model
                    return
                , @

                @parent.on 'add', @._onAdd = (model, collection, options)->
                    if not @destroyed and collection is @parent
                        proto.add.call @, model, _.defaults {bubble: 0, sort: true}, options
                    return
                , @

                @parent.on 'remove', @._onRemove = (model, collection, options)->
                    if not @destroyed and collection is @parent
                        proto.remove.call @, model, _.defaults {bubble: 0}, options
                    return
                , @

                @parent.on 'reset', @._onReset = (collection, options)->
                    if not @destroyed and collection is @parent
                        proto.reset.call @, collection.models, _.defaults {bubble: 0, sub: true}, options
                    return
                , @

                return

            subSet.detachEvents = ->
                parent = @parent
                parent.off 'change', @_onChange, @
                parent.off 'add', @_onAdd, @
                parent.off 'remove', @_onRemove, @
                parent.off 'reset', @_onReset, @
                return

            subSet.destroy = ->
                @detachEvents()

                for own prop of @
                    if prop isnt '_uid'
                        delete @[prop]

                # may be destroyed was executed during an event handling
                # therefore, callbacks will still be processed
                # @destroyed helps skipping callback if needed
                @destroyed = true
                return
            
            if options.models isnt false
                subSet.attachEvents()

            subSet

        _onModelEvent: (event, model, collection, options) ->
            if @destroyed
                return

            if event in ['add', 'remove'] and collection isnt @
                return

            if event is 'destroy'
                @remove model, options

            else if event is 'change'
                prevId = @modelId(model.previousAttributes())
                id = @modelId(model.attributes)
                if prevId isnt id
                    if prevId isnt null
                        delete @_byId[prevId]
                    if id isnt null
                        @_byId[id] = model

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

    _.extend BackboneCollection, {byAttribute, byAttributes, reverse}

    BackboneCollection
