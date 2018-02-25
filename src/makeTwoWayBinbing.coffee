`
import _ from "%{amd: 'lodash', common: 'lodash', brunch: '!_', node: 'lodash'}";
import Backbone from "%{amd: 'backbone', common: 'backbone', brunch: '!Backbone', node: 'backbone'}";
import i18n from "%{amd: 'i18next', common: 'i18next', brunch: '!i18next'}";
import ReactDOM from "%{ amd: 'react-dom', common: '!ReactDOM' }";
import AbstractModelComponent from "./components/ModelComponent"
`

hasProp = Object::hasOwnProperty
_expressionCache = {}
uid = '_makeTwoWayBinbing_' + Math.random().toString(36).slice(2)
HIDDEN_BINDING_KEY = uid + "_binding"

# http://www.w3schools.com/tags/att_input_type.asp
inputTypesWithEditableValue = {
    "color": true,
    "date": true,
    "datetime": true,
    "datetime-local": true,
    "email": true,
    "month": true,
    "number": true,
    "password": true,
    "range": true,
    "search": true,
    "tel": true,
    "text": true,
    "time": true,
    "url": true,
    "week": true
}

hasEditableValue = (type, props)->
    switch type
        when "textarea", "select"
            return true
        when "input"
            return props.type in [null, undefined] or hasProp.call(inputTypesWithEditableValue, props.type)
        else
            return false

emptyObject = (binding)->
    for own prop of binding
        binding[prop] = null
        delete binding[prop]
    return

handleTargetChange = (evt)->
    ref = evt.ref or evt.target
    binding = ref[HIDDEN_BINDING_KEY]
    binding.__onChange.apply(this, arguments) if binding
    return

_makeTwoWayBinbing = (type, config, element)->
    if not config or not (this instanceof AbstractModelComponent)
        return

    {spModel: model, validate} = config

    if 'string' is typeof model
        property = model
        model = @inline
        if 'string' isnt typeof type
            element.props.spModel = [model, property]
    else if Array.isArray model
        if Array.isArray model[0]
            models = []
            events = []
            for [_model, evttype] in model
                if _.isObject(_model) && _model.on && _model.off
                    models.push _model
                    events.push evttype
            model = models
        else
            [model, property, events] = model
    else
        return

    if 'function' is typeof type and not type.getBinding
        return

    if Array.isArray(model)
        if model.length is 0
            return
        if model.some((model)-> not _.isObject(model) or 'function' isnt typeof model.on or 'function' isnt typeof model.off)
            return
    else if not _.isObject(model) or 'function' isnt typeof model.on or 'function' isnt typeof model.off
        return

    if 'string' is typeof property
        if 'string' is typeof events and events.length > 0
            events = events.map((type)-> "#{type}:#{property}").join(' ')
        else
            events = "change:#{property}"

    if not events
        return

    # until creation, instance is not known
    # no other choice than add first, then remove it
    if not @_bindings
        @_bindings = []

    if not @_bindexists
        @_bindexists = {}

    binding =
        id: _.uniqueId 'bd'
        events: events
        owner: this
        model: model
        validate: validate

        _attach: (binding)->
            if Array.isArray binding.model
                for i in [0...binding.model.length] by 1
                    _model = binding.model[i]
                    _events = binding.events[i]
                    _model.on _events, binding._onModelChange, binding
            else
                binding.model.on binding.events, binding._onModelChange, binding

            binding.owner._bindexists[binding.id] = binding
            return

        _detach: (binding)->
            if Array.isArray binding.model
                for i in [0...binding.model.length] by 1
                    _model = binding.model[i]
                    _events = binding.events[i]
                _model.off _events, binding._onModelChange, binding
            else
                binding.model.off binding.events, binding._onModelChange, binding

            delete binding.owner._bindexists[binding.id]
            emptyObject binding
            if ReactDOM.vrdom is ReactDOM and binding._ref
                delete binding._ref[HIDDEN_BINDING_KEY]
            return

        _onModelChange: (model, value, options)->
            { owner, _ref } = @

            if owner
                component = owner
            else if _ref instanceof AbstractModelComponent
                component = _ref

            if component
                pure = component.isPureDataModel
                state = if pure then {} else getChangedState(model.cid, model.changed, model.attributes)
                component.setState(state)

            return

        __ref: (ref, status)->
            return if not ref

            binding = this
            owner = binding.owner

            if ReactDOM.vrdom is ReactDOM
                if status isnt "mount"
                    if existing = ref.binding
                        prevBinding = owner._bindexists[existing]
                        prevBinding.onChange = binding.onChange if prevBinding

                    index = binding.index
                    owner._bindings.splice index, 1
                    emptyObject(binding)
                    for i in [index...owner._bindings.length] by 1
                        owner._bindings[i].index--
                    binding = null
                    return

                Object.defineProperty ref, HIDDEN_BINDING_KEY, {
                    configurable: true,
                    enumerable: false,
                    writable: true,
                    value: this
                }

            if not (existing = ref.binding)
                existing = ref.binding = binding.id

            if (prevBinding = owner._bindexists[existing]) and prevBinding isnt binding
                index = binding.index

                if !_.isEqual(prevBinding.model, binding.model) or !_.isEqual(prevBinding.events, binding.events)
                    # use the new binding
                    hasChangedModel = true
                    index = prevBinding.index
                    owner._bindings.splice index, 1
                    prevBinding._detach prevBinding

                else
                    # re-use the previous binding
                    owner._bindings.splice index, 1
                    emptyObject binding

                    # onChange is always a new function, make sure it uses the correct binding object
                    prevBinding.onChange = binding.onChange
                    binding = prevBinding

                for i in [index...owner._bindings.length] by 1
                    owner._bindings[i].index--

                return if not hasChangedModel

            binding._ref = ref
            binding._node = ReactDOM.findDOMNode(ref)
            binding._attach binding
            return

    if type is AbstractModelComponent.MdlComponent
        tagName = config.tagName
    else
        tagName = type

    props = element.props

    if property
        link = if this.getValueLinkProps then this.getValueLinkProps(type, props, property, model) else null

        if link
            # to ease testing
            props['data-bind-model'] = model.cid
            props['data-bind-attr'] = property

            Object.assign(props, link)
        else
            defaultValue = undefined
            valueProp = undefined

            initTagBinding = (type)->
                if type is "input" and props.type in ["checkbox", "radio"]
                    valueProp = 'checked'
                    defaultValue = false
                    binding.get = (binding, evt)-> evt.target.checked
                else if hasEditableValue(type, props)
                    valueProp = 'value'
                    binding.get = (binding, evt)-> evt.target.value
                else if type in ['option', 'button', 'datalist', 'output']
                    valueProp = 'value'
                    binding.get = (binding, evt)-> evt.target.value
                else if config.contentEditable in ["true", true]
                    valueProp = 'innerHTML'
                    binding.get = (binding, evt)-> evt.target.innerHTML
                return

            switch typeof type
                when 'function'
                    if type is AbstractModelComponent.MdlComponent
                        initTagBinding(tagName)
                    else if 'function' is typeof type.getBinding
                        binding = type.getBinding binding, config
                        valueProp = binding.valueProp or 'value'
                        defaultValue = type.getDefaultValue(binding, config) if type.getDefaultValue
                when 'string'
                    initTagBinding(type)

    if valueProp

        # to ease testing
        props['data-bind-model'] = model.cid
        props['data-bind-attr'] = property

        __onChange = (evt)->
            if binding.onChange
                res = binding.onChange.apply(null, arguments)

            binding.model.set property, binding.get(binding, evt), {
                dom: true,
                validate: binding.validate
            }
            return res

        if ReactDOM.vrdom is ReactDOM
            binding.__onChange = __onChange
            __onChange = handleTargetChange

        # make sure created native component will have the correct initial value
        value = model.attributes[property]
        switch typeof value
            when 'undefined'
                if valueProp is 'innerHTML'
                    delete props.dangerouslySetInnerHTML
                else if typeof defaultValue isnt 'undefined'
                    props[valueProp] = defaultValue
                else if valueProp is 'value'
                    props[valueProp] = ''
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

        onChangeEvent = binding.onChangeEvent

        if not onChangeEvent
            onChangeEvent = 'onChange'
            binding.onChangeEvent = onChangeEvent

        if 'function' is typeof props[onChangeEvent]
            binding.onChange = props[onChangeEvent]

        props[onChangeEvent] = __onChange

    binding.index = @_bindings.length
    binding.__ref = binding.__ref.bind binding
    @_bindings.push binding

    if element.preactCompatNormalized
        element = element.attributes

    switch typeof element.ref
        when 'function'
            ref = element.ref
            __ref = binding.__ref
            element.ref = ->
                __ref.apply @, arguments
                ref.apply @, arguments
                return
        when 'string'
            ref = element.ref
            __ref = binding.__ref
            owner = this
            element.ref = (el)->
                __ref.apply @, arguments

                if Object.isFrozen(owner.refs)
                    isFrozen = true
                    { refs } = owner
                    owner.refs = {}
                    for key, value of refs
                        owner.refs[key] = value
                else if not owner.refs
                    owner.refs = {}

                owner.refs[ref] = el

                if isFrozen
                    Object.freeze(owner.refs)

                return
        when 'undefined'
            element.ref = binding.__ref
        when 'object'
            if element.ref is null
                element.ref = binding.__ref

    return binding

getChangedState = (cid, changed, attributes)->
    state = {}
    for key of changed
        state[uid + ":" + cid + ":" + key] = attributes[key]

    return state

makeTwoWayBinbing = (element, type, config, toSetElement)->
    if element and element._owner
        {_instance, stateNode} = element._owner;
        instance = stateNode or _instance

        if instance
            _makeTwoWayBinbing.call(instance, type, config, toSetElement or element)

makeTwoWayBinbing.getChangedState = getChangedState

module.exports = makeTwoWayBinbing
