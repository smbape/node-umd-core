deps = [
    '../common'
    '../makeTwoWayBinbing'
    '!componentHandler'
]

freact = ({_, $, Backbone}, makeTwoWayBinbing, componentHandler)->
    slice = Array::slice
    hasProp = Object::hasOwnProperty

    randomString = -> Math.random().toString(36).slice(2)
    expando = React.expando or (React.expando = randomString())

    MDL_CLASSES = [
        "mdl-js-button",
        "mdl-js-checkbox",
        "mdl-js-icon-toggle",
        "mdl-js-menu",
        "mdl-js-progress",
        "mdl-js-radio",
        "mdl-js-slider",
        "mdl-js-snackbar",
        "mdl-js-spinner",
        "mdl-js-switch",
        "mdl-js-tabs",
        "mdl-js-textfield",
        "mdl-tooltip",
        "mdl-js-layout",
        "mdl-js-data-table",
        "mdl-js-ripple-effect"
    ]

    MDL_CLASSES_REG = new RegExp "(?:^|\\s)(?:" + MDL_CLASSES.join("|") + ")(?:\\s|$)"
    MDL_CLASSES_UPGRADED_SELECTOR = "." + MDL_CLASSES.join("[data-upgraded], .") + "[data-upgraded]"
    MDL_CLASSES_NOT_UPGRADED_SELECTOR = "." + MDL_CLASSES.join(":not([data-upgraded]), .") + ":not([data-upgraded])"

    createElement = React.createElement
    React.createElement = (type, config)->
        args = slice.call arguments

        if componentHandler and config and not config.mdlIgnore and 'string' is typeof type and MDL_CLASSES_REG.test config.className
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

        return element

    class AbstractModelComponent extends React.Component
        uid: 'AbstractModelComponent' + randomString()

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

            if hasProp.call @_reffn, name
                return @_reffn[name]

            @_reffn[name] = (ref)=>
                if @_refs
                    @_refs[name] = ref
                return

        getRef: (name)->
            if hasProp.call @_refs, name
                return @_refs[name]

            @refs[name]

        initialize: ->

        componentWillMount: ->
            return

        componentDidMount: ->
            @el = ReactDOM.findDOMNode @
            @$el = $ @el
            @attachEvents.apply @, @getEventArgs()
            return

        componentWillReceiveProps: (nextProps)->
            return

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
            @_updating = false
            return

        componentWillUnmount: ->
            id = @id

            if @_bindings
                for binding in @_bindings
                    binding._detach binding
                    for own key of binding
                        delete binding[key]

            for name in ['_previousAttributes', 'attributes', 'changed']
                attributes = @inline[name]
                for own key of attributes
                    delete attributes[key]

            @detachEvents.apply @, @getEventArgs()

            # remove every references
            for own prop of @
                switch prop
                    when expando, 'id', 'props', 'refs', '_reactInternalInstance'
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
            return if @_updating
            @shouldUpdate = true
            if @el
                @_updating = true
                state = {}
                state[@uid] = randomString()
                @setState state
            return

        _updateOwner: ->
            @shouldUpdate = true

            if @el
                state = {}
                state[@uid] = randomString()
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
                    if hasProp.call @filterCache, query
                        return @filterCache[query]

                    regexp = new RegExp query.replace(/([\\\/\^\$\.\|\?\*\+\(\)\[\]\{\}])/g, '\\$1'), 'i'
                    fn = (model)->
                        if model instanceof Backbone.Model
                            attributes = model.attributes
                        else
                            attributes = model

                        for own prop of attributes
                            if regexp.test(attributes[prop])
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
            @upgradeElements(@el)
            return

        componentWillUnmount: ->
            @downgradeElements(@el)
            super
            return

        upgradeElements: (el)->
            if MDL_CLASSES_REG.test(el.className) and el.getAttribute("data-upgraded") is null
                componentHandler.upgradeElement(el)

            for child in el.children
                @upgradeElements(child)
            return

        downgradeElements: (el)->
            for child in el.children
                @downgradeElements(child)

            if MDL_CLASSES_REG.test(el.className) and el.getAttribute("data-upgraded") isnt null
                componentHandler.downgradeElements([el])
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
            # for child, i in children
            #     children[i] = deepCloneElement child
            args.push.apply args, children
        else
            # args.push deepCloneElement children
            args.push children

        return React.createElement.apply React, args


    # avoid circular reference
    makeTwoWayBinbing.init AbstractModelComponent

    AbstractModelComponent