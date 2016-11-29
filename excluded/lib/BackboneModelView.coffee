deps = [
    {amd: 'lodash', common: 'lodash', brunch: '!_', node: 'lodash'}
    {amd: 'jquery', common: 'jquery', brunch: '!jQuery'}
    {amd: 'backbone', brunch: '!Backbone'}
    '../eachSeries'
    '../ExpressionParser'
    '../patch'
]

factory = (_, $, Backbone, eachSeries, ExpressionParser)->
    hasOwn = {}.hasOwnProperty

    componentCache = {}
    _parseExpression = ExpressionParser.parse
    _expressionCache = {}

    do ->
        delegateEvents = [
            'blur'
            'change'
            'click'
            'drag'
            'drop'
            'focus'
            'input'
            'load'
            'mouseenter'
            'mouseleave'
            'mousemove'
            'propertychange'
            'reset'
            'scroll'
            'submit'

            'abort'
            'canplay'
            'canplaythrough'
            'durationchange'
            'emptied'
            'encrypted'
            'ended'
            'error'
            'loadeddata'
            'loadedmetadata'
            'loadstart'
            'pause'
            'play'
            'playing'
            'progress'
            'ratechange'
            'seeked'
            'seeking'
            'stalled'
            'suspend'
            'timeupdate'
            'volumechange'
            'waiting'
        ]

        $document = $(document)
        delegate = (type)->
            attr = 'data-' + type
            $document.on type, "[#{attr}]", (evt)->
                expr = evt.currentTarget.getAttribute(attr)
                if !expr
                    return

                fn = _expressionCache[expr]
                if !fn
                    fn = _expressionCache[expr] = _parseExpression(expr)

                reactNode = $(evt.currentTarget)
                while (reactNode = reactNode.closest('[id^=view_]')).length
                    nodeID = reactNode[0].id
                    if hasOwn.call componentCache, nodeID
                        component = componentCache[nodeID]
                        break

                    reactNode = reactNode.parent().closest('[id^=view_]')

                if component
                    return fn.call component, {event: evt}, window


        for evt in delegateEvents
            delegate evt

    isDeclaredProperty = (currProto, prop, stopPrototype)->
        while currProto and not hasOwn.call(currProto, prop)
            if currProto is stopPrototype
                currProto = undefined
            else if currProto.constructor?.__super__
                currProto = currProto.constructor.__super__
            else if currProto.constructor.prototype is currProto
                # backup original constructor
                proto = currProto
                ctor = proto.constructor

                # expose parent constructor
                delete currProto.constructor
                currProto = currProto.constructor?.prototype

                # restore constructor
                proto.constructor = ctor
            else
                currProto = undefined

        currProto

    class BackboneView extends Backbone.View

        container: null
        events: null
        title: null

        constructor: (options = {})->
            @id = @id or _.uniqueId 'view_'
            componentCache[@id] = @

            # proto = @constructor.prototype
            # stopPrototype = Backbone.View.prototype

            for own opt of options
                if opt.charAt(0) isnt '_' and opt of @
                    @[opt] = options[opt]

            super options

        initialize: (options)->
            super

            overridables = [
                'template'
                'componentWillMount'
                'mount'
                'componentDidMount'
                'componentWillUnmount'
                'unmount'
                'componenDidUnmount'
            ]
            for opt in overridables
                @[opt] = options[opt] if hasOwn.call options, opt

        take: ->
            throw new Error 'View is in a rendering process' if this.$$busy
            this.$$busy = true
            return

        give: ->
            this.$$busy = false
            return

        mountTasks: ->
            [
                'componentWillMount'
                ['mount', this.container]
                'componentDidMount'
            ]

        unmountTasks: ->
            [
                'componentWillUnmount'
                'unmount'
                'componenDidUnmount'
            ]

        modelChangeTasks: ->
            this.unmountTasks(this.container).concat this.mountTasks(this.container)

        render: (done)->
            view = @
            view.take()
            eachSeries view, this.mountTasks(), (err)->
                view.give()
                done null, view if 'function' is typeof done
                return

            return

        onModelChange: (model, done)->
            @reRender done
            return

        reRender: (done)->
            view = this
            modelChangeTasks = view.modelChangeTasks(view.container)
            view.take()
            eachSeries view, modelChangeTasks, (err)->
                view.give()
                done() if 'function' is typeof done
                return
            return

        destroy: (done)->
            view = @
            return if view.destroyed

            delete componentCache[@id]

            view.take()

            destroyTasks = this.unmountTasks().concat ['undelegateEvents']

            eachSeries view, destroyTasks, (err)->
                view.trigger 'destroy', view
                if typeof view.$el isnt 'undefined'
                    view.$el.destroy()

                for own prop of view
                    view[prop] = null

                view.destroyed = true
                done() if 'function' is typeof done
                return

            return

        isMounted: ->
            @mounted

        # to attach delegated events, use events instead
        # here do dom manipulations that do not need mount
        # it will be faster than doing it when element is mounted
        componentWillMount: ->
            switch typeof @template
                when 'function'
                    if @model instanceof Backbone.Model
                        data = @model.toJSON()
                    else if @model instanceof Backbone.Collection and 'function' is typeof @model.attrToJSON
                        data = @model.attrToJSON()
                    xhtml = @template.call @, data
                when 'string'
                    xhtml = @template
                else
                    xhtml = ''

            @.$el.empty().html xhtml
            return

        mount: (container)->
            container.appendChild @el
            @mounted = true
            return

        # here do dom manipulations that need mount
        componentDidMount: ->
            if model = this.model
                model.on 'change', this.onModelChange, this
            return

        # undo what have been done in componentDidMount
        componentWillUnmount: ->
            if model = this.model
                model.off 'change', this.onModelChange, this

            return

        # undo what have been done in mount
        unmount: ->
            @el.parentNode.removeChild @el if @el.parentNode
            @mounted = false
            return

        # undo what have been done in componentWillMount
        componenDidUnmount: ->

    BackboneView.createElement = (props)->
        new this props

    BackboneView
