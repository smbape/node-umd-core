deps = [
    '../common'
    '../models/BackboneCollection'
    './ReactModelView'
]

freact = ({_, Backbone}, BackboneCollection, ReactModelView)->

    hasOwn = {}.hasOwnProperty

    {byAttribute, reverse} = BackboneCollection

    class ReactCollectionView extends ReactModelView

        constructor: (props)->
            super
            @state = model: @getNewModel(props)

        shouldComponentUpdateEvent: (nextProps, nextState)->
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

            if not nextModel
                return nextModel

            currentModel = @getModel()

            if currentModel
                {comparator: currentComparator, selector: currentFilter} = currentModel
                currentReverse = currentComparator?.reverse

            if typeof nextComparator is 'undefined'
                # use default comparator
                nextComparator = nextModel.comparator or null

            if typeof nextComparator is 'string'
                if nextComparator.length is 0
                    nextComparator = null
                else if currentComparator
                    if currentComparator.attribute is nextComparator and nextReverse is currentReverse
                        # comparator didn't change
                        nextComparator = currentComparator or null

            if typeof nextFilter is 'undefined'
                # use default filter
                nextFilter = nextModel.selector

            if typeof nextFilter is 'string'
                if nextFilter.length is 0
                    nextFilter = null
                else if currentFilter
                    if currentFilter.value is nextFilter
                        # filter didn't change
                        nextFilter = currentFilter

            if not currentComparator
               currentComparator = null

            if not currentFilter
               currentFilter = null

            if not nextComparator
                nextComparator = null

            if not nextFilter
                nextFilter = null

            if not currentModel or nextModel isnt @props.model or nextComparator isnt currentComparator or nextReverse isnt currentReverse or nextFilter isnt currentFilter
                if 'string' is typeof nextComparator
                    nextComparator = @byAttribute nextComparator

                if nextReverse
                    nextComparator = reverse nextComparator

                if 'string' is typeof nextFilter
                    nextFilter = @getFilter nextFilter, true

                if nextComparator or nextFilter
                    currentModel = nextModel.getSubSet {comparator: nextComparator, selector: nextFilter}
                    currentModel.stateSubSet = true
                else
                    currentModel = nextModel

            currentModel

        getEventArgs: (props = @props, state = @state)->
            [@getModel(props, state)]

        getNewEventArgs: (props = @props, state = @state)->
            [@getNewModel(props, state)]

        attachEvents: (collection)->
            super
            if collection
                collection.on 'add', this.onAdd, this
                collection.on 'remove', this.onRemove, this
                collection.on 'move', this.onMove, this
                collection.on 'reset', this.onReset, this
                collection.on 'switch', this.onSwitch, this

                if @state.model isnt collection
                    @state.model = collection
                    # @setState model: model

            return

        detachEvents: (collection)->
            if collection
                collection.off 'switch', this.onSwitch, this
                collection.off 'reset', this.onReset, this
                collection.off 'move', this.onMove, this
                collection.off 'remove', this.onRemove, this
                collection.off 'add', this.onAdd, this
                if collection.stateSubSet
                    collection.destroy()
                    @state.model = undefined
            super

            return

        onModelChange: (model, collection, options)->
            options = collection if 'undefined' is typeof options
            if options?.bubble > 1
                # ignore bubbled events
                return false

            collection = @getModel()
            if model is collection
                @_updateView()
            else
                index = collection.indexOf model
                childNodeList = @childNodeList()
                childNodeList[index] = @props.childNode model, index, collection, options

                @_updateView()

            return

        childNodeList: ->
            if @_childNodeList
                return @_childNodeList

            if collection = @getModel()
                @_childNodeList = collection.models.map (model, index)=>
                    @props.childNode model, index, collection, {}

        onAdd: (model, collection, options)->
            if @destroyed or options?.bubble > 1
                # ignore bubbled events
                return false

            index = options.index or collection.indexOf model
            if index is -1
                index = collection.length

            childNodeList = @childNodeList()
            childNode = @props.childNode model, index, collection, options
            childNodeList.splice index, 0, childNode

            @_updateView()
            return

        onRemove: (model, collection, options)->
            if @destroyed or options?.bubble > 1
                # ignore bubbled events
                return false

            index = options.index
            childNodeList = @childNodeList()

            childNode = childNodeList[index]
            childNodeList.splice(index, 1)

            @_updateView()
            return

        onMove: (model, collection, options)->
            if @destroyed or options?.bubble > 1
                # ignore bubbled events
                return false

            {index, from} = options
            childNodeList = @childNodeList()
            childNode = childNodeList[from]
            childNodeList.splice from, 1
            childNodeList.splice index, 0, childNode
            @_updateView()
            return

        onReset: (collection, options)->
            if @destroyed or options?.bubble > 1
                # ignore bubbled events
                return false

            @reRender()
            return

        onSwitch: (collection, options)->
            if @destroyed or options?.bubble > 1
                # ignore bubbled events
                return false

            @reRender()
            return

        render:->
            props = _.clone @props

            children  = props.children
            delete props.children

            childNodeList = @childNodeList()

            tagName = props.tagName or 'div'
            delete props.tagName

            if childNodeList and childNodeList.length > 0
                React.createElement tagName, props, childNodeList
            else
                args = [tagName, props, undefined]
                if _.isArray children
                    args.push.apply args, children
                else
                    args.push children

                React.createElement.apply React, args

        reRender: ->
            delete @_childNodeList
            @_updateView()
            return
