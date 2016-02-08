deps = [
    '../common'
    './resources'
    {amd: 'backbone.validation'}
]

factory = ({_, Backbone, i18n}, resources)->

    hasOwn = {}.hasOwnProperty

    translateErrorMsg = (message)->
        if Array.isArray message
            _.map message, (message)->
                translateErrorMsg message
        else
            i18n.t message.error, message.options

    # Returns an object with undefined properties for all
    # attributes on the model that has defined one or more
    # validation rules.
    getValidatedAttrs = (model, attrs) ->
        attrs = attrs or _.keys(_.result(model, 'validation') or {})
        _.reduce attrs, ((memo, key) ->
            memo[key] = undefined
            memo
        ), {}
    
    # Returns an array with attributes passed through options
    getOptionsAttrs = (options, view) ->
        attrs = options?.attributes
        _.isArray(attrs) and attrs

    validation = (options)->
        if 'function' is typeof @updateResources
            @updateResources resources

        # Allow to call Backbone validation on model.
        mixin = Backbone.Validation.mixin
        validate = mixin.validate
        mixin = _.defaults {
            _validate: (attrs, options)->
                switch options.validate
                    when false
                        # do not validate only if explicitely said false
                        return true
                    when true
                        attrs = _.extend {}, @attributes, attrs

                error = @validationError = @validate(attrs, options) || null
                return true if not error
                return false

            validate: (attrs, options)->
                options = _.extend {}, options
                model = @
                notify = !attrs or options.validate
                validAttrs = []

                validateAttrs = getValidatedAttrs model, getOptionsAttrs(options)

                # Since we are automatically updating the model,
                # we must allow invalid values in the model
                # See: https://github.com/thedersen/backbone.validation#force-update
                invalidAttrs = validate.call @, attrs, _.defaults {forceUpdate: false}, options
                isValid = model._isValid

                # Trigger validated events.
                # Need to defer this so the model is actually updated before
                # the event is triggered.
                _.defer ->
                    if invalidAttrs
                        for attr of validateAttrs
                            if hasOwn.call(invalidAttrs, attr)
                                isAttrValid = false
                                if not _.isArray invalidAttrs[attr]
                                    invalidAttrs[attr] = [invalidAttrs[attr]]

                                for message, index in invalidAttrs[attr]
                                    invalidAttrs[attr][index] = translateErrorMsg(message)
                            else
                                isAttrValid = true
                            model.trigger 'translated:validated:' + attr, !hasOwn.call(invalidAttrs, attr), attr, model, invalidAttrs[attr] or []
                    else
                        for attr of validateAttrs
                            model.trigger 'translated:validated:' + attr, true, attr, model, []

                    if notify
                        model.trigger 'translated:validated', isValid, model, invalidAttrs or {}
                    return

                if options.forceUpdate is false
                    invalidAttrs

        }, mixin
        _.extend Backbone.Model.prototype, mixin

        return
