deps = [
    '../common'
    '../models/BackboneCollection'
    './ReactModelView'
    '../GenericUtil'
]

factory = ({_, Backbone}, BackboneCollection, ReactModelView, GenericUtil)->

    class ReactCollectionView extends ReactModelView
        comparator: null

        constructor: ->
            super

            if @model and not (@model instanceof BackboneCollection)
                throw new Error 'model must be an instance of BackboneCollection'

            @_viewAttributes = new Backbone.Model @attributes
            @setComparator @comparator, {silent: true}
            @originalModel = @model

        setAttribute: ->
            @_viewAttributes.set.apply @_viewAttributes, arguments

        getAttribute: (attr)->
            @_viewAttributes.get attr

        setComparator: (comparator, options = {})->
            @detachEvents() if not options.silent

            if 'function' is typeof comparator
                @_model = @model if not @_model
                @model = @_model.getSubSet comparator: comparator
                res = true
            else if not comparator and @_model
                @model = @_model
                delete @_model
                res = true
            else
                res = false

            @attachEvents() if not options.silent
            return res

        sort: (comparator, reverse)->
            if 'string' is typeof comparator
                comparator = GenericUtil.comparators.PropertyComarator comparator

            if arguments.length is 1 and 'boolean' is typeof comparator
                reverse = comparator
                comparator = @model.comparator

            if reverse
                comparator = GenericUtil.comparators.reverse comparator

            if @setComparator(comparator)
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
