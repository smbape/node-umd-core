deps = [
    '../common'
    '../models/BackboneCollection'
    './ReactModelView'
]

freact = ({_, Backbone}, BackboneCollection, ReactModelView)->

    {byAttribute, reverse} = BackboneCollection

    class ReactCollectionView extends ReactModelView

        constructor: (props)->
            super
            @state = model: @getNewModel(props)

        shouldUpdateEvent: (nextProps, nextState)->
            shouldUpdate = super(nextProps, nextState)

            if shouldUpdate
                delete @_childNodeList

            shouldUpdate

        componentDidUpdate: (prevProps, prevState)->
            super

        getModel: (props = @props, state = @state)->
            state?.model

        getNewModel: (props)->
            {
                order: nextComparator,
                filter: nextFilter,
                reverse: nextReverse,
                model: nextModel
            } = props

            currentModel = @getModel()

            if not currentModel
                currentModel = nextModel
                isNextModel = true

            if not currentModel
                return

            {comparator: currentComparator, selector: currentFilter} = currentModel
            currentReverse = currentComparator.reverse

            switch typeof nextComparator
                when 'function'
                    if nextReverse
                        nextComparator = reverse nextComparator

                when 'string'
                    if isNextModel
                        if nextComparator.length is 0
                            nextComparator = null
                        else
                            nextComparator = byAttribute(nextComparator)

                    else if currentComparator?.attribute isnt nextComparator
                        if nextComparator.length is 0
                            nextComparator = null
                        else
                            nextComparator = byAttribute(nextComparator)

                    else if nextReverse and not currentReverse
                        nextComparator = reverse currentComparator

                    else
                        # comparator didn't change
                        nextComparator = currentComparator
                else
                    # unsupported comparator
                    nextComparator = null

            switch typeof nextFilter
                when 'function'
                    break
                when 'string'
                    if isNextModel
                        if nextFilter.length is 0
                            nextFilter = null
                        else
                            nextFilter = @getFilter nextFilter, true

                    if currentFilter?.value isnt nextFilter
                        if nextFilter.length is 0
                            nextFilter = null
                        else
                            nextFilter = @getFilter nextFilter, true

                    else
                        # filter didn't change
                        nextFilter = currentFilter
                else
                    # unsupported comparator
                    nextFilter = null

            if nextComparator is null and nextFilter is null
                currentModel = nextModel
            else if currentComparator isnt nextComparator or currentFilter isnt nextFilter
                currentModel = nextModel.getSubSet {comparator: nextComparator, selector: nextFilter}

            currentModel

        getEventArgs: (props = @props, state = @state)->
            [@getModel(props, state)]

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
                    @state.model = model
                    # @setState model: model

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
                childNodeList[index] = @props.childNode model, index

                @_updateView()

            return

        childNodeList: ->
            if @_childNodeList
                return @_childNodeList

            if collection = @getModel()
                @_childNodeList = collection.models.map _.bind @props.childNode, @

        onAdd: (model, collection, options)->
            if options?.bubble > 1
                # ignore bubbled events
                return

            index = options.index or @getModel().indexOf model
            if index is -1
                index = @model.models.length

            childNodeList = @childNodeList()
            childNode = @props.childNode model, index
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

        render:->
            React.createElement @props.tagName or 'div', @props, @childNodeList()

        reRender: ->
            delete @_childNodeList
            @_updateView()
            return
