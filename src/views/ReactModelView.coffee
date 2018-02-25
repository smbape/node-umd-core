`
import React from "%{ amd: 'react', common: '!React' }"
import ReactDOM from "%{ amd: 'react-dom', common: '!ReactDOM' }"
import $ from "%{amd: 'jquery', common: 'jquery', brunch: '!jQuery'}";
import Backbone from "%{amd: 'backbone', common: 'backbone', brunch: '!Backbone', node: 'backbone'}";
import AbstractModelComponent from '../components/AbstractModelComponent'
`

emptyObject = (obj)->
    for own prop of obj
        delete obj[prop]

    return

class ReactModelView extends AbstractModelComponent
    uid: 'ReactModelView' + ('' + Math.random()).replace(/\D/g, '')

    constructor: (props = {})->
        @_options = Object.assign {}, props
        super
        @props.mediator?.trigger 'instance', @

    getModel: (props = @props, state = @state)->
        props.model

    # make sure to call this method,
    # otherwise, route changes will hang up
    componentDidMount: ->
        super
        @props.mediator?.trigger 'mount', @
        return

    getEventArgs: (props = @props, state = @state)->
        [@getModel(props, state)]

    attachEvents: (model, attr)->
        if model
            model.on 'change', @onModelChange, @
        return

    detachEvents: (model, attr)->
        if model
            model.off 'change', @onModelChange, @
        return

    onModelChange: ->
        options = arguments[arguments.length - 1]
        if options.bubble > 0
            # ignore bubbled events
            return

        @_updateView()
        return

    destroy: ->
        if @destroyed
            return

        {container, mediator} = @_options

        if container
            ReactDOM.unmountComponentAtNode container

        if mediator
            mediator.trigger 'destroy', @

        for own prop of @
            delete @[prop]

        @destroyed = true
        return

class Element
    constructor: (Component, props)->
        { container } = props
        mediator = Object.assign {}, Backbone.Events
        @props = props = Object.assign { mediator }, props

        if not container
            throw new Error 'container must be defined'

        @_internal = React.createElement Component, props

    render: (done)->
        element = @
        {container, mediator} = @props
        if 'function' is typeof done
            mediator.once 'mount', ->
                setTimeout ->
                    done null, element
                    return
                , 0
                return

        mediator.once 'instance', (component)->
            element._component = component
            return

        mediator.once 'destroy', ->
            mediator.off 'mount'
            emptyObject element
            emptyObject mediator
            return

        ReactDOM.render element._internal, container
        return

    destroy: ->
        if @_component
            @_component.destroy()
            @_component = null
        return

ReactModelView.createElement = (props)->
    return new Element this, props

module.exports = ReactModelView
