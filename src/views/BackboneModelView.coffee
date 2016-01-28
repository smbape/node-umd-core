deps = [
    {amd: 'lodash', common: '!_', node: 'lodash'}
    {amd: 'jquery', common: '!jQuery'}
    {amd: 'backbone', common: '!Backbone'}
    '../eachSeries'
    '../../lib/acorn'
    '../patch'
]

factory = (_, $, Backbone, eachSeries, acorn)->
    hasOwn = {}.hasOwnProperty

    zip = (keys, values)->
        res = {}

        if keys.length is 0
            return res

        for index in [0...keys.length] by 1
            res[keys[index]] = values[index]

        res

    class Environment
        constructor: (params = [], args = [], @outer)->
            @attributes = {}
            @update zip params, args
        update: (attrs)->
            for own attr of attrs
                @attributes[attr] = attrs[attr]
            @
        find: (x)->
            if hasOwn.call @attributes, x
                return @
            else if @outer
                @outer.find x
        get: (x)->
            @attributes[x]
        set: (x, val)->
            @attributes[x] = val
        has: (x)->
            !!@find x
        findGet: (x)->
            env = @find x
            return env.get x if env
        findEnv: (x)->
            @find(x) or @

    computeIdentifier = (node, env, globalEnv)->
        if not env.has node.name
            # variable has not been declared
            globalEnv.set node.name, true

        return

    computeNode = (node, env, globalEnv)->
        return if node is null

        switch node.type

            when 'Identifier'
                computeIdentifier node, env, globalEnv

            when 'FunctionDeclaration', 'FunctionExpression'
                env.set node.id.name, true if 'FunctionDeclaration' is node.type
                params = []

                for arg in node.params
                    params.push arg.name if 'Identifier' is arg.type

                env = new Environment params, [], env
                computeNode node.body, env, globalEnv

            when 'Program', 'BlockStatement'
                body = []
                fnIndex = 0
                for expr in node.body
                    if expr.type is 'FunctionDeclaration'
                        # Hoisting
                        body.splice fnIndex++, 0, expr
                    else
                        body.push expr

                for expr in body
                    computeNode expr, env, globalEnv

            when 'ExpressionStatement'
                computeNode node.expression, env, globalEnv

            when 'VariableDeclaration'
                for declaration in node.declarations
                    computeNode declaration, env, globalEnv

            when 'VariableDeclarator'
                if node.init
                    computeNode node.init, env, globalEnv

                if node.id.type is 'Identifier'
                    env.set node.id.name, true

            when 'CallExpression'
                for arg in node.arguments
                    computeNode arg, env, globalEnv

                computeNode node.callee, env, globalEnv

            when 'MemberExpression'
                if node.object.type is 'Identifier'
                    computeIdentifier node.object, env, globalEnv

            when 'BinaryExpression'
                computeNode node.left, env, globalEnv
                computeNode node.right, env, globalEnv

            when 'ConditionalExpression', 'IfStatement'
                computeNode node.test, env, globalEnv
                computeNode node.consequent, env, globalEnv
                computeNode node.alternate, env, globalEnv

            when 'SwitchStatement'
                computeNode node.discriminant, env, globalEnv
                for cnode in node.cases
                    computeNode cnode, env, globalEnv

            when 'SwitchCase'
                computeNode node.test, env, globalEnv
                for cnode in node.consequent
                    computeNode cnode, env, globalEnv

        return

    class BackboneView extends Backbone.View
        _expressionCache: {}
        events: null
        title: null

        constructor: (options = {})->
            @id = @id or _.uniqueId 'view_'

            proto = @constructor.prototype

            for own opt of options
                if opt.charAt(0) isnt '_'
                    currProto = proto
                    while currProto and not hasOwn.call(currProto, opt)
                        currProto = currProto.constructor?.__super__

                    if currProto
                        @[opt] = options[opt]

            super options

        delegateEvents: ->
            super

            @$el.on 'click.delegateEvents.' + @cid, '[bb-click]', _.bind (evt)->
                # hack to prevent bubble on this specific handler
                # for triggered user action event or triggered event
                memo = evt.originalEvent or evt
                return if memo['bb-click']
                memo['bb-click'] = true

                expr = evt.currentTarget.getAttribute('bb-click')
                if !expr
                    return

                fn = @_expressionCache[expr]
                if !fn
                    fn = @_expressionCache[expr] = @_parseExpression(expr)
                
                return fn.call @, {event: evt}, window
            , @

            @$el.on 'submit.delegateEvents.' + @cid, '[bb-submit]', _.bind (evt)->
                # hack to prevent bubble on this specific handler
                # for triggered user action event or triggered event
                memo = evt.originalEvent or evt
                return if memo['bb-submit']
                memo['bb-submit'] = true

                expr = evt.currentTarget.getAttribute('bb-submit')
                if !expr
                    return

                fn = @_expressionCache[expr]
                if !fn
                    fn = @_expressionCache[expr] = @_parseExpression(expr)
                
                return fn.call @, {event: evt}, window
            , @

            return

        _parseExpression: (body)->
            ast = acorn.parse(body)
            globalEnv = new Environment()
            computeNode ast, env = new Environment(), globalEnv
            globals = _.keys globalEnv.attributes

            vars = ''
            if globals.length
                declaration = []
                for arg in globals
                    declaration.push "#{arg} = 'undefined' === typeof locals.#{arg} ? globals.#{arg} : locals.#{arg}"

                vars = 'var ' + declaration.join(',\n    ') + ';'


            fnText = """
                #{vars}
                #{body}
            """

            ### jshint -W054 ###
            return new Function 'locals', 'globals', fnText

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

        render: (container, done)->
            view = @
            view.container = container

            if 'function' isnt typeof view.render
                done new Error 'view must implement a render method'
                return

            if 'function' isnt typeof view.mount
                done new Error 'view must implement a mount method'
                return

            view.take()
            eachSeries view, this.mountTasks(), (err)->
                view.give()
                done() if 'function' is typeof done
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
            
            view.take()

            destroyTasks = this.unmountTasks().concat ['undelegateEvents']

            eachSeries view, destroyTasks, (err)->
                view.trigger 'destroy', view
                if typeof view.$el isnt 'undefined'
                    view.$el.destroy()

                for own prop of view
                    view[prop] = null

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
