deps = [
    '../common'
    '../models/BackboneCollection'
    './ReactModelView'
]

factory = ({_, Backbone}, BackboneCollection, ReactModelView)->

    byProperty = (property)->
        fn = (a, b)->
            if a instanceof Backbone.Model
                a = a.attributes
            if b instanceof Backbone.Model
                b = b.attributes

            if a[property] > b[property]
                1
            else if a[property] < b[property]
                -1
            else
                0

        fn.property = property
        fn

    reverse = (compare)->
        return compare.original if compare.reverse and compare.original

        fn = (a, b)-> -compare(a, b)

        fn.reverse = true
        fn.original = compare
        fn.property = compare.property

        fn

    class ReactCollectionView extends ReactModelView
        order: null
        comparator: null
        filter: null

        constructor: ->
            super

            if @model and not (@model instanceof BackboneCollection)
                throw new Error 'model must be an instance of BackboneCollection'

            @_viewAttributes = new Backbone.Model @attributes
            @originalModel = @model
            @setSubset {
                comparator: @comparator or @order
                filter: @filter
            }, {silent: true}

        setAttribute: ->
            @_viewAttributes.set.apply @_viewAttributes, arguments

        getAttribute: (attr)->
            @_viewAttributes.get attr

        componentWillReceiveProps: (nextProps)->
            if @setSubset {
                comparator: nextProps.order
                filter: nextProps.filter
            }, {silent: true, reverse: nextProps.reverse}
                @shouldUpdate = true
                delete @_childNodeList
            return

        setSubset: (config = {}, options = {})->
            {comparator, filter} = config
            @detachEvents()

            res = false

            switch typeof comparator
                when 'function'
                    if options.reverse
                        comparator = reverse comparator
                    if @model.comparator isnt comparator
                        res = true
                when 'string'
                    if @model.comparator?.property isnt comparator
                        if comparator.length is 0
                            comparator = null
                        else
                            comparator = byProperty(comparator)
                        res = true
                    else if options.reverse and not @model.comparator.reverse
                        comparator = reverse @model.comparator
                        res = true
                    else
                        # comparator didn't change
                        comparator = @model.comparator
                else
                    # unsupported comparator
                    comparator = null
                    res = true

            switch typeof filter
                when 'function'
                    if @model.selector isnt filter
                        res = true
                when 'string'
                    if @model.selector?.value isnt filter
                        if filter.length is 0
                            filter = null
                        else
                            filter = @getFilter filter, true
                        res = true
                    else
                        # filter didn't change
                        filter = @model.selector
                else
                    # unsupported comparator
                    filter = null
                    res = true

            if comparator is null and filter is null
                if @model isnt @originalModel
                    @model = @originalModel
                    res = true
                else
                    res = false
            else if res
                @model = @originalModel.getSubSet {comparator: comparator, selector: filter}

            @attachEvents()
            return res

        sort: (prop, options)->
            if @setSubset({comparator: prop}, options)
                if options.silent
                    @shouldUpdate = true
                else
                    @reRender()
                return true

        childNodeList: ->
            if @_childNodeList
                return @_childNodeList

            @_childNodeList = @model.models.map _.bind @childNode, @

        attachEvents: ->
            super

            if @model
                @model.on 'add', this.onAdd, this
                @model.on 'remove', this.onRemove, this
                @model.on 'move', this.onMove, this
                @model.on 'reset', this.onReset, this
                @model.on 'switch', this.onSwitch, this
            @_viewAttributes.on 'change', this.onModelChange, this

            @attched = true
            return

        detachEvents: ->
            @_viewAttributes.off 'change', this.onModelChange, this
            if @model
                @model.off 'switch', this.onSwitch, this
                @model.off 'reset', this.onReset, this
                @model.off 'move', this.onMove, this
                @model.off 'remove', this.onRemove, this
                @model.off 'add', this.onAdd, this

            super
            return

        onAdd: (model, collection, options)->
            if options?.bubble > 1
                # ignore bubbled events
                return

            index = options.index or @model.indexOf model
            if index is -1
                index = @model.models.length

            childNodeList = @childNodeList()
            childNode = @childNode model, index
            childNodeList.splice index, 0, childNode

            @_updateView()
            return

        onRemove: (model, collection, options)->
            if options?.bubble > 1
                # ignore bubbled events
                return

            index = options.index
            childNodeList = @childNodeList()

            childNode = childNodeList[index]
            # if not childNode or childNode.key isnt model.cid
            #     debugger
            childNodeList.splice(index, 1)

            @_updateView()
            return

        onMove: (model, collection, options)->
            if options?.bubble > 1
                # ignore bubbled events
                return

            {index, from} = options
            childNodeList = @childNodeList()
            childNode = childNodeList[from]
            childNodeList.splice from, 1
            childNodeList.splice index, 0, childNode
            @_updateView()
            return

        onReset: (collection, options)->
            if options?.bubble > 1
                # ignore bubbled events
                return

            @reRender()
            return

        onSwitch: (collection, options)->
            if options?.bubble > 1
                # ignore bubbled events
                return

            @reRender()
            return

        onModelChange: (model, collection, options)->
            options = collection if 'undefined' is typeof options
            if options?.bubble > 0
                # ignore bubbled events
                return

            if model is @model
                @_updateView()
            else if model is @_viewAttributes
                if sort = model.changed.sort
                    @sort sort.attribute, sort.value is 'desc'
                else
                    @_updateView()
            else
                index = @model.indexOf model
                childNodeList = @childNodeList()
                childNodeList[index] = @childNode model, index

                @_updateView()

            return

        reRender: ->
            delete @_childNodeList
            @_updateView()
            return
