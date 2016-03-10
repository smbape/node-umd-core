deps = [
    '../common'
    '../makeTwoWayBinbing'
    '!componentHandler'
]

freact = ({_, $, Backbone}, makeTwoWayBinbing, componentHandler)->
    slice = [].slice
    hasOwn = {}.hasOwnProperty

    createElement = React.createElement
    React.createElement = (type, config)->
        args = arguments

        if config and not config.mdlIgnore and 'string' is typeof type and /(?:^|\s)mdl-/.test config.className
            # dynamic mdl component creation
            # TODO: create a hook system to allow more dynamic components creation
            args = slice.call arguments
            config = _.defaults {tagName: type, mdlIgnore: true}, config
            type = args[0] = MdlComponent
            args[1] = config

        element = createElement.apply React, args
        binding = makeTwoWayBinbing element, type, config
        element.props.binding = binding

        if not appConfig.isProduction
            Object.freeze element.props
            Object.freeze element

        return element

    class AbstractModelComponent extends React.Component
        uid: 'AbstractModelComponent' + ('' + Math.random()).replace(/\D/g, '')

        constructor: ->
            super
            @inline = new Backbone.Model()
            @_refs = {}
            @_reffn = {}
            @initialize()

        setRef: (name)->
            if 'string' isnt typeof name or name.length is 0
                return

            if hasOwn.call @_reffn, name
                return @_reffn[name]

            @_reffn[name] = (ref)=>
                if @_refs
                    @_refs[name] = ref
                return

        getRef: (name)->
            if hasOwn.call @_refs, name
                return @_refs[name]

            @refs[name]

        initialize: ->

        componentWillMount: ->

        componentDidMount: ->
            @el = ReactDOM.findDOMNode @
            @$el = $ @el
            @attachEvents.apply @, @getEventArgs()
            return

        componentWillReceiveProps: (nextProps)->

        shouldComponentUpdate: (nextProps, nextState)->
            @shouldUpdate = @shouldUpdate or !_.isEqual(@state, nextState) or !_.isEqual(@props, nextProps)

            @shouldUpdateEvent = @shouldUpdateEvent or @shouldComponentUpdateEvent nextProps, nextState
            @shouldUpdate or @shouldUpdateEvent

        shouldComponentUpdateEvent: (nextProps, nextState)->
            if 'function' is typeof @getNewEventArgs
                args = @getNewEventArgs nextProps, nextState
            else
                args = @getEventArgs nextProps, nextState

            oldArgs = @getEventArgs()

            if _.isEqual(args, oldArgs)
                return false

            return true

        componentWillUpdate: (nextProps, nextState)->
            if @shouldUpdateEvent
                oldArgs = @getEventArgs()
                @detachEvents.apply @, oldArgs

                if 'function' is typeof @getNewEventArgs
                    args = @getNewEventArgs nextProps, nextState
                else
                    args = @getEventArgs nextProps, nextState
                @attachEvents.apply @, args

            @shouldUpdate = @shouldUpdateEvent = false
            return

        componentDidUpdate: (prevProps, prevState)->

        componentWillUnmount: ->
            if @_bindings
                for binding in @_bindings
                    binding._detach binding

            @detachEvents.apply @, @getEventArgs()

            # remove every references
            for own prop of @
                switch prop
                    when 'props', 'state', 'refs', 'context', 'updater', '_reactInternalInstance'
                        continue
                
                delete @[prop]

            @destroyed = true
            return

        getEventArgs: ->

        attachEvents: ->

        detachEvents: ->

        onModelChange: ->
            options = arguments[arguments.length - 1]
            if options.bubble > 0
                # ignore bubbled events
                return

            @_updateOwner()
            return

        _updateView: ->
            @shouldUpdate = true
            if @_reactInternalInstance
                state = {}
                state[@uid] = new Date().getTime()
                @setState state
            return

        _updateOwner: ->
            @shouldUpdate = true

            if @_reactInternalInstance
                state = {}
                state[@uid] = new Date().getTime()
                if owner = @_reactInternalInstance._currentElement._owner?._instance
                    owner.setState state
                else
                    @setState state
            return

        getFilter: (query, isValue)->
            if not isValue
                query = @inline.get query

            switch typeof query
                when 'string'
                    query = query.trim()
                    if query.length is 0
                        return null

                    @filterCache = {} if not @filterCache
                    if hasOwn.call @filterCache, query
                        return @filterCache[query]

                    regexp = new RegExp query.replace(/([\\\/\^\$\.\|\?\*\+\(\)\[\]\{\}])/g, '\\$1'), 'i'
                    fn = (model)->
                        for own prop of model.attributes
                            if regexp.test(model.attributes[prop]) 
                                return true

                        return false

                    @filterCache[query] = fn
                when 'function'
                    query
                else
                    null

    class MdlComponent extends AbstractModelComponent
        componentDidMount:->
            super
            componentHandler.upgradeElement @el

            return

        componentWillUnmount: ->
            componentHandler.downgradeElements [@el]
            super
            return

        render:->
            React.createElement @props.tagName or 'span', @props

    MdlComponent.getBinding = true

    AbstractModelComponent.MdlComponent = MdlComponent

    # avoid circular reference
    makeTwoWayBinbing.init AbstractModelComponent

    AbstractModelComponent