deps = [
    '../common'
    '../models/BackboneCollection'
    './ReactModelView'
    '../GenericUtil'
]

factory = ({_, Backbone}, BackboneCollection, ReactModelView, GenericUtil)->

    class ReactCollectionView extends ReactModelView

        constructor: ->
            super

            if @model and not (@model instanceof BackboneCollection)
                throw new Error 'model must be an instance of BackboneCollection'

            @_viewAttributes = new Backbone.Model @attributes
            @setComparator @props.comparator, {silent: true}

        setAttribute: ->
            switch arguments.length
                when 1
                    @_viewAttributes.set arguments[0]
                when 2
                    @_viewAttributes.set arguments[0], arguments[1]
                else
                    @_viewAttributes.set arguments[0], arguments[1], arguments[2]

        getAttribute: (attr)->
            @_viewAttributes.get attr

        setComparator: (comparator, options = {})->
            @detachEvents() if not options.silent

            if 'function' is typeof comparator
                @props._model = @props.model if not @props._model
                @props.model = @props._model.getSubSet comparator: comparator
                res = true
            else if not comparator and @props._model
                @props.model = @props._model
                delete @props._model
                res = true
            else
                res = false

            @attachEvents() if not options.silent

            res

        sort: (comparator, reverse)->
            if 'string' is typeof comparator
                comparator = GenericUtil.comparators.PropertyComarator comparator

            if arguments.length is 1 and 'boolean' is typeof comparator
                reverse = comparator
                comparator = @props.model.comparator

            if reverse
                comparator = GenericUtil.comparators.reverse comparator

            if @setComparator(comparator)
                @reRender()
                return true

        childNodeList: ->
            if @_childNodeList
                return @_childNodeList

            @_childNodeList = @props.model.models.map _.bind @childNode, @

        attachEvents: ->
            super

            if @props.model
                @props.model.on 'add', this.onAdd, this
                @props.model.on 'remove', this.onRemove, this
                @props.model.on 'move', this.onMove, this
                @props.model.on 'reset', this.onReset, this
                @props.model.on 'switch', this.onSwitch, this
            @_viewAttributes.on 'change', this.onModelChange, this

            @attched = true
            return

        detachEvents: ->
            @_viewAttributes.off 'change', this.onModelChange, this
            if @props.model
                @props.model.off 'switch', this.onSwitch, this
                @props.model.off 'reset', this.onReset, this
                @props.model.off 'move', this.onMove, this
                @props.model.off 'remove', this.onRemove, this
                @props.model.off 'add', this.onAdd, this

            super
            return

        onAdd: (model, collection, options)->
            options = arguments[arguments.length - 1]
            if options.bubble > 1
                # ignore bubbled events
                return

            index = options.index or @props.model.indexOf model
            if index is -1
                index = @props.model.models.length

            childNodeList = @childNodeList()
            childNode = @childNode model, index
            childNodeList.splice index, 0, childNode

            @_updateView()
            # @props.checkIntegrity()
            return

        onRemove: (model, collection, options)->
            options = arguments[arguments.length - 1]
            if options.bubble > 1
                # ignore bubbled events
                return

            index = options.index
            childNodeList = @childNodeList()

            childNode = childNodeList[index]
            # if not childNode or childNode.key isnt model.cid
            #     debugger
            childNodeList.splice(index, 1)

            @_updateView()
            # @props.checkIntegrity()
            return

        onMove: (model, collection, options)->
            options = arguments[arguments.length - 1]
            if options.bubble > 1
                # ignore bubbled events
                return

            {index, from} = options
            childNodeList = @childNodeList()
            childNode = childNodeList[from]
            childNodeList.splice from, 1
            childNodeList.splice index, 0, childNode
            @_updateView()
            # @props.checkIntegrity()
            return

        onReset: (collection, options)->
            options = arguments[arguments.length - 1]
            if options.bubble > 1
                # ignore bubbled events
                return

            @reRender()
            return

        onSwitch: (collection, options)->
            options = arguments[arguments.length - 1]
            if options.bubble > 1
                # ignore bubbled events
                return

            @reRender()
            return

        onModelChange: (model)->
            options = arguments[arguments.length - 1]
            if options.bubble > 0
                # ignore bubbled events
                return

            if model is @props.model
                @_updateView()
            else if model is @_viewAttributes
                if sort = model.changed.sort
                    @sort sort.attribute, sort.value is 'desc'
                else
                    @_updateView()
            else
                index = @props.model.indexOf model
                childNodeList = @childNodeList()
                childNodeList[index] = @childNode model, index

                @_updateView()

            # @props.checkIntegrity()
            return

        reRender: ->
            delete @_childNodeList
            @_updateView()
            return
