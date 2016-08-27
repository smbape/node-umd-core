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
        args = slice.call arguments

        if window.componentHandler and config and not config.mdlIgnore and 'string' is typeof type and /(?:^|\s)mdl-/.test config.className
            # dynamic mdl component creation
            # TODO: create a hook system to allow more dynamic components creation
            config = _.defaults {tagName: type, mdlIgnore: true}, config
            type = args[0] = MdlComponent
            args[1] = config

        if config and 'string' is typeof type
            _config = args[1] = _.clone config
            delete _config.binding
            delete _config.mdlIgnore
            delete _config.spModel
            delete _config.tagName

        element = createElement.apply React, args

        binding = makeTwoWayBinbing element, type, config
        if binding and 'string' isnt typeof type
            element.props.binding = binding

        if not appConfig.isProduction
            Object.freeze element.props
            Object.freeze element

        return element

    class AbstractModelComponent extends React.Component
        uid: 'AbstractModelComponent' + ('' + Math.random()).replace(/\D/g, '')

        constructor: ->
            super
            @id = _.uniqueId (@constructor.name or 'AbstractModelComponent') + '_'
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
                oldArgs.push.apply oldArgs, [nextProps, nextState]
                @detachEvents.apply @, oldArgs

                if 'function' is typeof @getNewEventArgs
                    args = @getNewEventArgs nextProps, nextState
                else
                    args = @getEventArgs nextProps, nextState

                args.push.apply args, [nextProps, nextState]
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

        getDOMNode: -> @el

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

        addClass: (props, toAdd)->
            if props.className
                classes = props.className.trim().split(/\s+/g)
            else
                classes = []

            if Array.isArray toAdd
                for className in toAdd
                    if classes.indexOf(className) is -1
                        hasChanged = true
                        classes.push className
            else if classes.indexOf(toAdd) is -1
                hasChanged = true
                classes.push toAdd

            if hasChanged
                props.className = classes.join(' ')

            return

        removeClass: (props, toRemove)->
            if props.className
                classes = props.className.trim().split(/\s+/g)
            else
                classes = []

            if Array.isArray toRemove
                for className in toRemove
                    if ~(at = classes.indexOf(className))
                        hasChanged = true
                        classes.splice at, 1
            else if ~(at = classes.indexOf(toRemove))
                hasChanged = true
                classes.splice at, 1

            if hasChanged
                props.className = classes.join(' ')

            return

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
            props = _.clone @props
            tagName = props.tagName or 'span'
            delete props.tagName
            React.createElement tagName, props

    MdlComponent.getBinding = (binding, config)->
        if config.tagName is 'input' and config.type is 'checkbox'
            binding.get = (binding, evt)->
                $(evt.target).prop('checked')
        else
            binding.get = (binding, evt)->
                $(evt.target).val()

        binding


    AbstractModelComponent.MdlComponent = MdlComponent

    AbstractModelComponent.deepCloneElement = deepCloneElement = (element, overrides)->
        if not React.isValidElement element
            return _.clone element

        {key, props, ref, type} = element
        {children} = props
        props = _.extend {}, props, overrides
        props.key = key if key
        props.ref = ref if ref

        if not children
            return React.createElement type, props

        args = [type, props]
        if _.isArray children
            for child, i in children
                children[i] = deepCloneElement child
            args.push.apply args, children
        else
            args.push deepCloneElement children

        return React.createElement.apply React, args


    # avoid circular reference
    makeTwoWayBinbing.init AbstractModelComponent

    AbstractModelComponent