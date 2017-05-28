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
    assign = Object.assign
    EXPANDO_BINDINGS = expando + "_bindings"

    assignProperty = (obj, property, value, definition) ->
        Object.defineProperty obj, property, assign({
            configurable: true
            enumerable: true
            writable: true
            value: value
        }, definition)

        obj[property]

    makeBindingRef = (bindings, events)->
        (ref)->
            if ref
                for evt in events
                    if (hasProp.call(bindings.events, evt))
                        bindings.events[evt]++
                    else
                        bindings.events[evt] = 1
            else
                for evt in events
                    if (hasProp.call(bindings.events, evt))
                        bindings.events[evt]--
                        if bindings.events[evt] is 0
                            delete bindings.events[evt]

            return

    setRef = (name, ref)->
        if (ref)
            this.refs[name] = ref
        else
            delete this.refs[name]
        return

    createChainedFunction = (a, b)->
        ->
            a.apply(this, arguments)
            b.apply(this, arguments)
            return

    _onModelChange = (model, value, options)->
        pure = this.isPureDataModel
        state = if pure then {} else getChangedState(model.cid, model.changed, model.attributes)
        this.setState(state)
        return

    requestCheckboxChange = (evt)->
        value = evt.currentTarget.checked
        model.set property, value
        return

    requestValueChange = (evt)->
        value = evt.currentTarget.value
        model.set property, value
        return

    requestInnerHTMLChange = (evt)->
        value = evt.currentTarget.innerHTML
        model.set property, value
        return

    uid = '_' + randomString()
    getChangedState = (cid, changed, attributes)->
        state = {}
        for key of changed
            state[uid + ":" + cid + ":" + key] = attributes[key]

        return state

    setRequestChange = (onChange, requestChange)->
        if not hasProp.call(onChange, "original") or onChange.original isnt requestChange
            onChange.original = requestChange
            onChange.derivated.clear()
        return

    createElement = React.createElement
    React.createElement = (type, config)->
        args = slice.call arguments

        if componentHandler and config and not config.mdlIgnore and 'string' is typeof type and /(?:^|\s)mdl-/.test config.className
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

        _handleBinding: (type, config, element)->
            {spModel: model, validate} = config

            if 'string' is typeof model
                property = model
                model = @inline
                if 'string' isnt typeof type
                    element.props.spModel = [model, property]
            else if _.isArray(model)
                [model, property, events] = model
            else
                return

            if 'function' is typeof type and not type.getBinding
                return

            if not _.isObject(model) or 'function' isnt typeof model.on or 'function' isnt typeof model.off
                return

            if 'string' is typeof property
                if Array.isArray(events) and events.length > 0
                    events = events.map((type)-> "#{type}:#{property}")
                else if 'string' is typeof events and events.length > 0
                    events = events.split(' ').map((type)-> "#{type}:#{property}")
                else if not events
                    events = ["change:#{property}"]

            if not events
                return

            eventsId = events.sort().join(' ')
            bindings = if hasProp.call(this, EXPANDO_BINDINGS) then this[EXPANDO_BINDINGS] else assignProperty(this, EXPANDO_BINDINGS, {}, { enumerable: false })
            bindings = if hasProp.call(bindings, model.cid) then bindings[model.cid] else assignProperty(bindings, model.cid, {
                model: model
                refs: {}
                events: {}
                handlers: {}
                onChange: {
                    derivated: new Map()
                }
            })

            if not hasProp.call(bindings.refs, eventsId)
                bindings.refs[eventsId] = {
                    original: makeBindingRef(bindings, events)
                    derivated: new Map()
                }
            ref = bindings.refs[eventsId]

            currentRef = element.ref
            typeofRef = typeof currentRef
            original = ref.original
            derivated = ref.derivated

            if not currentRef
                ref = original
            else if derivated.has(currentRef)
                ref = derivated.get(currentRef)
            else
                if 'string' is typeofRef
                    ref = setRef.bind(this, currentRef)
                else if 'function' is typeofRef
                    ref = createChainedFunction(currentRef, ref)
                else
                    ref = currentRef
                derivated.set(currentRef, ref)

            element.ref = ref

            if property
                props = element.props

                # to ease testing
                props['data-bind-model'] = model.cid
                props['data-bind-attr'] = property

                defaultValue = undefined
                valueProp = undefined

                switch type
                    when 'input'
                        if config.type is 'checkbox'
                            valueProp = 'checked'
                            defaultValue = false
                            setRequestChange bindings.onChange, requestCheckboxChange
                        else
                            valueProp = 'value'
                            setRequestChange bindings.onChange, requestValueChange
                    when 'textarea', 'select', 'option', 'button', 'datalist', 'output'
                        valueProp = 'value'
                        setRequestChange bindings.onChange, requestValueChange
                    else
                        if 'string' is typeof type and Boolean(config.contentEditable)
                            valueProp = 'innerHTML'
                            setRequestChange bindings.onChange, requestInnerHTMLChange
                        else
                            valueProp = 'value'
                            setRequestChange bindings.onChange, requestValueChange

                value = model.attributes[property]
                switch typeof value
                    when 'undefined'
                        if valueProp is 'innerHTML'
                            delete props.dangerouslySetInnerHTML
                        else if typeof defaultValue isnt 'undefined'
                            props[valueProp] = defaultValue
                        else
                            delete props[valueProp]

                    when 'boolean', 'number', 'string'
                        if valueProp is 'innerHTML'
                            props.dangerouslySetInnerHTML = __html: value
                        else
                            props[valueProp] = value

                    else
                        if valueProp is 'innerHTML'
                            delete props.dangerouslySetInnerHTML
                        else
                            delete props[valueProp]

                if type is 'input'
                    onInput = config.type isnt 'checkbox'
                else
                    onInput = type is 'textarea' or Boolean(config.contentEditable)

                if onInput
                    onChangeEvent = 'onInput'
                else
                    onChangeEvent = 'onChange'

                currentOnChange = props[onChangeEvent]
                original = bindings.onChange.original
                derivated = bindings.onChange.derivated

                if not currentOnChange
                    requestChange = original
                else if derivated.has(currentOnChange)
                    requestChange = derivated.get(currentOnChange)
                else
                    if 'function' is typeof currentOnChange
                        requestChange = createChainedFunction(currentOnChange, requestChange)
                    else
                        requestChange = currentOnChange
                    derivated.set(currentOnChange, requestChange)

                props[onChangeEvent] = requestChange

            return

        componentWillMount: ->
            return

        componentDidMount: ->
            @el = ReactDOM.findDOMNode @
            @$el = $ @el
            @attachEvents.apply @, @getEventArgs()

            if hasProp.call(this, EXPANDO_BINDINGS)
                for cid, bindings of this[EXPANDO_BINDINGS]
                    { model, events, handlers } = bindings
                    for evt of events
                        model.on evt, _onModelChange, @
                        handlers[evt] = true
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

            if hasProp.call(this, EXPANDO_BINDINGS)
                for cid, bindings of this[EXPANDO_BINDINGS]
                    { model, events, handlers } = bindings

                    for evt of handlers
                        if not hasProp.call(events, evt)
                            model.off evt, _onModelChange, @
                            delete handlers[evt]

                    for evt of events
                        if not hasProp.call(handlers, evt)
                            model.on evt, _onModelChange, @
                            handlers[evt] = true

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

            if hasProp.call(this, EXPANDO_BINDINGS)
                for cid, bindings of this[EXPANDO_BINDINGS]
                    { model, events, handlers, refs, onChange } = bindings
                    for name in ['model', 'events', 'handlers', 'refs', 'onChange']
                        delete bindings[name]

                    onChange.derivated.clear()
                    delete onChange.original
                    delete onChange.derivated

                    for eventsId, obj of refs
                        obj.derivated.clear()
                        delete obj.original
                        delete obj.derivated
                        delete refs[eventsId]

                    for evt of handlers
                        model.off evt, _onModelChange, @


                delete this[EXPANDO_BINDINGS]

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