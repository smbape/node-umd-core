deps = [
    'application'
    'umd-core/src/common'
    'umd-core/src/components/AbstractModelComponent'
]

freact = (app, {_, Backbone}, AbstractModelComponent)->
    ### globals grecaptcha: false ###
    loading = false
    loaded = false
    emitter = _.extend {}, Backbone.Events

    class Recaptcha extends AbstractModelComponent
        componentDidMount: ->
            super
            @initWidget()
            return

        # componentDidUpdate: ->
        #     super
        #     @initWidget()
        #     return

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
