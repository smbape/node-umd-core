deps = [
    'application'
    'umd-core/src/common'
    'umd-core/src/GenericUtil'
    'umd-core/src/components/AbstractModelComponent'
]

freact = (app, {_, Backbone}, {DOMUtil}, AbstractModelComponent)->
    ### globals grecaptcha: false ###
    loading = false
    loaded = false
    emitter = _.extend {}, Backbone.Events
    splice = [].splice

    deleteValue = (value, stack, only)->
        if DOMUtil.isNodeOrElement value
            DOMUtil.discardElement value

        else if value isnt null and typeof value in ['object', 'function']
            # avoid circular reference
            isCircular = false
            for prev in stack
                if prev is value
                    isCircular = true
                    break

            if not isCircular
                stack.push value
                deepDelete value, stack, only
                stack.pop value

        return

    deepDelete = (obj, stack, only)->
        if obj isnt window and obj isnt null and typeof obj in ['object', 'function']
            if _.isArray obj
                for value in obj
                    deleteValue value, stack, only
                splice.call obj, 0, obj.length if only obj
            else
                for own key, value of obj
                    deleteValue value, stack, only
                    delete obj[key] if only value, key
            return true

        return false

    class Recaptcha extends AbstractModelComponent
        componentDidMount: ->
            super
            @initWidget()
            return

        componentWillUnmount: ->
            emitter.off 'ready', @_initWidget, @

            # avoid DOM Leak
            # dirty function while waiting for a proper destroy method from google
            el = @el

            only = (value, key)->
                DOMUtil.isNodeOrElement(value)

            toDelete = null
            _.map window.___grecaptcha_cfg.clients, (widget, index)->
                for own key, value of widget
                    if value is el
                        deepDelete widget, [], only
                return

            super
            return

        initWidget: ->
            if loaded
                @_initWidget()
            else
                emitter.once 'ready', @_initWidget, @
                Recaptcha.init()
            return

        _initWidget: ->
            if @el
                options = _.pick @props, ['sitekey', 'theme', 'type', 'size', 'tabindex', 'expired-callback']

                onChange = @props.onChange
                if 'function' is typeof onChange
                    options.callback = (response)->
                        # TODO: create fake change event on @el
                        onChange(null, response)
                        return

                @widgetId = grecaptcha.render @el, options
            return

        render: ->
            `<span className="clearfix" />`

    Recaptcha.init = ->
        return if loading
        loading = true
        loaded = false
        callbackId = 'onloadCallback_' + new Date().getTime()
        window[callbackId] = ->
            loading = false
            loaded = true
            emitter.trigger 'ready'
            return

        lng = app.get('language')
        depsLoader.loadScript "https://www.google.com/recaptcha/api.js?onload=#{callbackId}&render=explicit&hl=#{lng}",
            async: true
            defer: true
        return

    Recaptcha.reset = ->
        loading = false
        loaded = false
        Recaptcha.init()
        return

    Recaptcha.getBinding = (binding)->

        binding.get = (binding)->
            if binding._ref instanceof Recaptcha
                instance = binding._ref
                grecaptcha.getResponse instance.widgetId

        binding

    app.on 'change:language', Recaptcha.reset, Recaptcha

    Recaptcha
