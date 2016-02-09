deps = [
    '../common'
    './resources'
    {amd: 'backbone.validation'}
]

factory = ({_, Backbone, i18n}, resources)->

    hasOwn = {}.hasOwnProperty

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
            invalidAttrs: {}

            _validate: (attrs, options)->
                switch options.validate
                    when false
                        # do not validate only if explicitely said false
                        return true
                    when true
                        attrs = _.extend {}, @attributes, attrs

                # Since we are automatically validating the model,
                # we must allow invalid values in the model
                # See: https://github.com/thedersen/backbone.validation#force-update
                options = _.extend {validate: true, forceUpdate: true}, options
                if null is options.validate or 'undefined' is typeof options.validate
                    options.validate = true

                error = @validationError = @validate(attrs, options) || null
                return true if not error
                return false

            validate: (attrs, options)->
                model = @
                validateAll = !attrs
                validAttrs = []
                validateAttrs = getValidatedAttrs model, getOptionsAttrs(options)
                return if _.isEmpty validateAttrs

                opts = _.defaults {forceUpdate: false}, options
                invalidAttrs = validate.call @, attrs, opts
                if invalidAttrs
                    for attr of invalidAttrs
                        if not _.isArray invalidAttrs[attr]
                            invalidAttrs[attr] = [invalidAttrs[attr]]

                if validateAll
                    model.invalidAttrs = invalidAttrs or {}
                else
                    if hasOwn.call model, 'invalidAttrs'
                        prevInvalidAttrs = model.invalidAttrs
                        for attr of attrs
                            if invalidAttrs and hasOwn.call(invalidAttrs, attr)
                                prevInvalidAttrs[attr] = invalidAttrs[attr]
                            else
                                delete prevInvalidAttrs[attr]
                    else
                        model.invalidAttrs = invalidAttrs or {}

                # Trigger validated events.
                # Need to defer this so the model is actually updated before
                # the event is triggered.
                _.defer ->
                    if invalidAttrs
                        for attr of validateAttrs
                            if hasOwn.call(invalidAttrs, attr)
                                isAttrValid = false

                            else
                                isAttrValid = true

                            if validateAll or hasOwn.call(attrs, attr)
                                model.trigger 'vstate:' + attr, isAttrValid, attr, model, invalidAttrs[attr] or []
                    else
                        isAttrValid = true
                        for attr of validateAttrs
                            if validateAll or hasOwn.call(attrs, attr)
                                model.trigger 'vstate:' + attr, true, attr, model, []

                    if validateAll
                        model.trigger 'vstate', model._isValid, model, invalidAttrs or {}
                    return

                if options.forceUpdate is false
                    invalidAttrs

        }, mixin
        _.extend Backbone.Model.prototype, mixin

        return
