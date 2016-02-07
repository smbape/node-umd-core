deps = [
    '../common'
    './resources'
    {amd: 'backbone.validation'}
]

factory = ({_, Backbone}, resources)->
    validation = (options)->
        if 'function' is typeof @updateResources
            @updateResources resources

        # Allow to call Backbone validation on model.
        _.extend Backbone.Model.prototype, Backbone.Validation.mixin

        # Since we are automatically updating the model,
        # we must allow invalid values in the model
        # See: https://github.com/thedersen/backbone.validation#force-update
        Backbone.Validation.configure forceUpdate: true

        return
