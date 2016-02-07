deps = [
    '../common'
    '../views/ReactModelView'
]

freact = ({_, i18n}, ReactModelView)->
    hasOwn = {}.hasOwnProperty

    translate = (error, options)->
        msg = i18n.t 'error.' + error, options
        if msg isnt 'error.' + error
            return msg

        return i18n.t error

    translateError = (error)->
        if Array.isArray error
            _.map error, (error)->
                translateError error
        else
            switch typeof error
                when 'string'
                    return translate error
                when 'object'
                    return null if error is null
                    return translate error.error, error.options

    class ModelListener extends ReactModelView
        tagName: 'span'

        _onModelEvent: ->
            callback = @props.onEvent
            @_children = callback.apply @, arguments
            @_updateView()
            return

        _getEventConfig: (props = @props, state = @state)->
            if (callback = props.onEvent) and
            (events = props.events) and
            (model = @getModel(props, state)) and
            'function' is typeof callback and
            'string' is typeof events
                return [model, events, @_onModelEvent]

        _onModelValidated: (isValid, model, invalidAttrs)->
            messages = {}
            for attr of model.changed
                if hasOwn.call invalidAttrs, attr
                    messages[attr] = translateError invalidAttrs[attr]
                    if not Array.isArray messages[attr]
                        messages[attr] = [messages[attr]]

                    model.trigger 'translated:invalid:' + attr, model, messages[attr]
                    isAttrValid = false
                else
                    model.trigger 'translated:valid:' + attr, model
                    isAttrValid = true

                model.trigger 'translated:validated:' + attr, isAttrValid, attr, model, messages[attr] or []

            model.trigger 'translated:validated', isValid, model, messages
            return

        attachEvents: ->
            return false if @_attached
            if config = @_getEventConfig()
                [model, events, callback] = config
                model.on 'validated', @_onModelValidated, @
                model.on events, callback, @
            @_attached = true
            return true

        detachEvents: ->
            return false if not @_attached
            if config = @_getEventConfig()
                [model, events, callback] = config
                model.off events, callback, @
                model.off 'validated', @_onModelValidated, @
            @_attached = false
            return true

        render:->
            React.createElement @tagName, @props, @_children
