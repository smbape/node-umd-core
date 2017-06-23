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
            @state = {
                model: @getNewModel(props)
                pending: []
            }

        shouldComponentUpdateEvent: (nextProps, nextState)->
            shouldUpdate = super(nextProps, nextState)

            if shouldUpdate
                delete @_childNodeList

            shouldUpdate

        getModel: (props = @props, state = @state)->
            state?.model

        getNewModel: (props)->
            {
                order: nextComparator,
                filter: nextFilter,
                reverse: nextReverse,
                model: nextModel
                limit: nextLimit
                offset: nextOffset
            } = props

            if not nextModel
                return nextModel

            currentModel = @getModel()

            if currentModel
                {
                    comparator: currentComparator
                    selector: currentFilter
                } = currentModel
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
                    nextComparator = byAttribute nextComparator, if nextReverse then -1 else 1

                else if nextReverse
                    nextComparator = reverse nextComparator

                if 'string' is typeof nextFilter
                    nextFilter = @getFilter nextFilter, true

                if nextComparator or nextFilter
                    currentModel = nextModel.getSubSet {comparator: nextComparator, selector: nextFilter, models: false}
                    currentModel.isSubset = true
                else
                    currentModel = nextModel

            currentModel

        getEventArgs: (props = @props, state = @state)->
            [@getModel(props, state)]

        getNewEventArgs: (props = @props, state = @state)->
            [@getNewModel(props, state)]

        attachEvents: (collection, nextProps, nextState)->
            super
            if collection
                collection.on 'add', this.onAdd, this
                collection.on 'remove', this.onRemove, this
                collection.on 'move', this.onMove, this
                collection.on 'reset', this.onReset, this
                collection.on 'switch', this.onSwitch, this

                if @state.model isnt collection
                    @state.model = collection
                    nextState.model = collection if nextState

            return

        detachEvents: (collection, nextProps, nextState)->
            if collection
                collection.off 'switch', this.onSwitch, this
                collection.off 'reset', this.onReset, this
                collection.off 'move', this.onMove, this
                collection.off 'remove', this.onRemove, this
                collection.off 'add', this.onAdd, this
                if collection.isSubset
                    collection.destroy()
                    @state.model = undefined
                    nextState.model = undefined if nextState
            super

            return

        childNodeList: ->
            if @_childNodeList
                return @_childNodeList

            if collection = @getModel()
                if collection.isSubset
                    collection.detachEvents()
                    collection.populate()
                    collection.attachEvents()

                {limit, offset} = @props
                models = collection.models

                if limit > 0
                    if offset > 0
                        limit += offset
                    else
                        offset = 0
                    if limit > models.length
                        limit = models.length
                else
                    limit = models.length
                    offset = 0

                index = 0
                @_childNodeList = []
                for i in [offset...limit] by 1
                    model = models[i]
                    @_childNodeList[index] = @props.childNode model, index, collection, {}
                    index++
                
                @_childNodeList

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
                @state.pending.push ["change", model, index, collection, options]

                @_updateView()

            return

        onAdd: (model, collection, options)->
            if @destroyed or options?.bubble > 1
                # ignore bubbled events
                return false

            index = options.index or collection.indexOf model
            if index is -1
                index = collection.length
            @state.pending.push ["add", model, index, collection, options]

            @_updateView() if not options.silentView
            return

        onRemove: (model, collection, options)->
            if @destroyed or options?.bubble > 1
                # ignore bubbled events
                return false

            index = options.index
            @state.pending.push ["remove", index]

            @_updateView() if not options.silentView
            return

        onMove: (model, collection, options)->
            if @destroyed or options?.bubble > 1
                # ignore bubbled events
                return false

            {from, index} = options
            @state.pending.push ["move", from, index]

            @_updateView() if not options.silentView
            return

        getChildNodeList: ->
            childNodeList = @childNodeList()
            hasUpdate = @state.pending.length

            for args in @state.pending
                switch args[0]
                    when "change"
                        [_UNUSED_, model, index, collection, options] = args
                        childNodeList[index] = @props.childNode model, index, collection, options
                    when "add"
                        [_UNUSED_, model, index, collection, options] = args
                        childNode = @props.childNode model, index, collection, options
                        childNodeList.splice index, 0, childNode
                    when "remove"
                        [_UNUSED_, index] = args
                        childNode = childNodeList[index]
                        childNodeList.splice(index, 1)
                    when "move"
                        [_UNUSED_, from, index] = args
                        childNodeList.splice from, 1
                        childNodeList.splice index, 0, childNode

            if hasUpdate
                @state.pending.length = 0
                childNodeList = childNodeList.slice()

            return childNodeList

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

        _getProps: ->
            props = _.clone @props
            for key in ['order', 'filter', 'reverse', 'model', 'childNode', 'limit', 'offset']
                delete props[key]
            props

        render:->
            props = @_getProps()

            children  = props.children
            delete props.children

            childNodeList = @getChildNodeList()

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
