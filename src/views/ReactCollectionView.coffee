deps = [
    '../common'
    '../models/BackboneCollection'
    './ReactModelView'
]

factory = ({_, Backbone}, BackboneCollection, ReactModelView)->

    {byAttribute, reverse} = BackboneCollection

    class ReactCollectionView extends ReactModelView

        constructor: (props)->
            super
            if model = @getNewModel(props)
                this.state = {model}

        shouldComponentUpdate: (nextProps, nextState)->
            shouldUpdate = super(nextProps, nextState)

            if shouldUpdate
                delete @_childNodeList

            shouldUpdate

        getModel: (props = @props, state = @state)->
            state?.model

        getNewModel: (props)->
            {order: comparator, filter, reverse: isReverse} = props
            original = @props.model
            model = @getModel()
            if not model
                model = original
                isOriginal = true

            res = false

            switch typeof comparator
                when 'function'
                    if isReverse
                        comparator = reverse comparator

                    if not isOriginal and model.comparator isnt comparator
                        res = true
                when 'string'
                    if isOriginal
                        if comparator.length is 0
                            comparator = null
                        else
                            comparator = byAttribute(comparator)

                    else if model.comparator?.attribute isnt comparator
                        if comparator.length is 0
                            comparator = null
                        else
                            comparator = byAttribute(comparator)
                        res = true

                    else if isReverse and not model.comparator.reverse
                        comparator = reverse model.comparator
                        res = true

                    else
                        # comparator didn't change
                        comparator = model.comparator
                else
                    # unsupported comparator
                    comparator = null
                    res = true

            switch typeof filter
                when 'function'
                    if not isOriginal and model.selector isnt filter
                        res = true
                when 'string'
                    if isOriginal
                        if filter.length is 0
                            filter = null
                        else
                            filter = @getFilter filter, true

                    if model.selector?.value isnt filter
                        if filter.length is 0
                            filter = null
                        else
                            filter = @getFilter filter, true
                        res = true

                    else
                        # filter didn't change
                        filter = model.selector
                else
                    # unsupported comparator
                    filter = null
                    res = true

            if comparator is null and filter is null
                model = original
            else if res
                model = original.getSubSet {comparator: comparator, selector: filter}

            model

        getNewEventArgs: (props = @props, state = @state)->
            [@getNewModel(props, state)]

        attachEvents: (model)->
            super
            if model
                model.on 'add', this.onAdd, this
                model.on 'remove', this.onRemove, this
                model.on 'move', this.onMove, this
                model.on 'reset', this.onReset, this
                model.on 'switch', this.onSwitch, this

                if @state.model isnt model
                    @setState model: model

            return

        detachEvents: (model)->
            if model
                model.off 'switch', this.onSwitch, this
                model.off 'reset', this.onReset, this
                model.off 'move', this.onMove, this
                model.off 'remove', this.onRemove, this
                model.off 'add', this.onAdd, this
            super

            return

        onModelChange: (model, collection, options)->
            options = collection if 'undefined' is typeof options
            if options?.bubble > 1
                # ignore bubbled events
                return

            collection = @getModel()
            if model is collection
                @_updateView()
            else
                index = collection.indexOf model
                childNodeList = @childNodeList()
                childNodeList[index] = @childNode model, index

                @_updateView()

            return

        childNodeList: ->
            if @_childNodeList
                return @_childNodeList

            @_childNodeList = @getModel().models.map _.bind @childNode, @

        onAdd: (model, collection, options)->
            if options?.bubble > 1
                # ignore bubbled events
                return

            index = options.index or @getModel().indexOf model
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

        reRender: ->
            delete @_childNodeList
            @_updateView()
            return
