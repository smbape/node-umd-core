`
/* eslint no-shadow: ["error", { "allow": ["hasEditableValue", "emptyObject", "handleTargetChange", "_makeTwoWayBinbing", "getChangedState", "makeTwoWayBinbing", "initTagBinding", "__onChange", "getChangedState"] }] */

import _ from "%{amd: 'lodash', brunch: '!_', common: 'lodash'}";
import Backbone from "%{amd: 'backbone', brunch: '!Backbone', common: 'backbone'}";
import i18n from "%{amd: 'i18next', brunch: '!i18next', common: 'i18next'}";
import ReactDOM from "%{ amd: 'react-dom', brunch: '!ReactDOM', common: 'react-dom' }";
import AbstractModelComponent from "./components/ModelComponent";
import isEqual from "../lib/fast-deep-equal";
`

hasProp = Object::hasOwnProperty
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
        # continue if prop is "id"
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
        if model.some((itModel)-> not _.isObject(itModel) or 'function' isnt typeof itModel.on or 'function' isnt typeof itModel.off)
            return
    else if not _.isObject(model) or 'function' isnt typeof model.on or 'function' isnt typeof model.off
        return

    if 'string' is typeof property
        if 'string' is typeof events and events.length > 0
            events = events.map((name)-> "#{name}:#{property}").join(' ')
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

        _attach: (currentBinding)->
            if Array.isArray currentBinding.model
                for i in [0...currentBinding.model.length] by 1
                    _model = currentBinding.model[i]
                    _events = currentBinding.events[i]
                    _model.on _events, currentBinding._onModelChange, currentBinding
            else
                currentBinding.model.on currentBinding.events, currentBinding._onModelChange, currentBinding

            currentBinding.owner._bindexists[currentBinding.id] = currentBinding
            return

        _detach: (currentBinding)->
            if Array.isArray currentBinding.model
                for i in [0...currentBinding.model.length] by 1
                    _model = currentBinding.model[i]
                    _events = currentBinding.events[i]
                _model.off _events, currentBinding._onModelChange, currentBinding
            else
                currentBinding.model.off currentBinding.events, currentBinding._onModelChange, currentBinding

            delete currentBinding.owner._bindexists[currentBinding.id]
            emptyObject(currentBinding)
            if ReactDOM.vrdom is ReactDOM and currentBinding._ref
                delete currentBinding._ref[HIDDEN_BINDING_KEY]
            return

        _onModelChange: (currentModel, currentValue, currentOptions)->
            { owner: currentOwner, _ref } = this

            if currentOwner
                component = currentOwner
            else if _ref instanceof AbstractModelComponent
                component = _ref

            if component
                pure = component.isPureDataModel
                state = if pure then {} else getChangedState(currentModel.cid, currentModel.changed, currentModel.attributes)
                component.setState(state)

            return

        __ref: (ref, status)->
            return if not ref

            currentBinding = this
            currentOwner = currentBinding.owner

            if ReactDOM.vrdom is ReactDOM
                if status isnt "mount"
                    if ref.binding
                        existing = ref.binding
                        prevBinding = currentOwner._bindexists[existing]
                        prevBinding.onChange = currentBinding.onChange if prevBinding

                    index = currentBinding.index
                    currentOwner._bindings.splice index, 1
                    emptyObject(currentBinding)
                    for i in [index...currentOwner._bindings.length] by 1
                        currentOwner._bindings[i].index--
                    binding = null
                    return

                Object.defineProperty ref, HIDDEN_BINDING_KEY, {
                    configurable: true,
                    enumerable: false,
                    writable: true,
                    value: this
                }

            if not ref.binding
                ref.binding = binding.id

            existing = ref.binding
            prevBinding = currentOwner._bindexists[existing]

            if prevBinding and prevBinding isnt currentBinding
                if !isEqual(prevBinding.model, currentBinding.model) or !isEqual(prevBinding.events, currentBinding.events)
                    # use the new binding
                    hasChangedModel = true
                    index = prevBinding.index
                    currentOwner._bindings.splice index, 1
                    prevBinding._detach prevBinding

                else
                    # re-use the previous binding
                    hasChangedModel = false
                    index = currentBinding.index
                    currentOwner._bindings.splice index, 1
                    binding = prevBinding

                    # but call the new onChange listener
                    prevBinding.onChange = currentBinding.onChange

                    # currentBinding is no more needed
                    # garbage collect every referenced by it
                    emptyObject(currentBinding)

                # since an element has been remove
                # elements after the removed index should match their new indexes
                for i in [index...currentOwner._bindings.length] by 1
                    currentOwner._bindings[i].index--

                return if not hasChangedModel

            currentBinding._ref = ref
            currentBinding._node = ReactDOM.findDOMNode(ref)
            currentBinding._attach currentBinding
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

            initTagBinding = (_tagName)->
                if _tagName is "input" and props.type in ["checkbox", "radio"]
                    valueProp = 'checked'
                    defaultValue = false
                    binding.get = (currentBinding, evt)-> evt.target.checked
                else if hasEditableValue(_tagName, props)
                    valueProp = 'value'
                    binding.get = (currentBinding, evt)-> evt.target.value
                else if _tagName in ['option', 'button', 'datalist', 'output']
                    valueProp = 'value'
                    binding.get = (currentBinding, evt)-> evt.target.value
                else if config.contentEditable in ["true", true]
                    valueProp = 'innerHTML'
                    binding.get = (currentBinding, evt)-> evt.target.innerHTML
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
                else
                    `// Nothing to do`

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
            else
                ref = element.ref
                __ref = binding.__ref
                element.ref = (el)->
                    ref.current = el
                    __ref.apply @, arguments
                    return
        else
            `// Nothing to do`

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
