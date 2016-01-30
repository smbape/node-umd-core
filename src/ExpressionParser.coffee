deps = [
    {amd: 'lodash', common: '!_', node: 'lodash'}
    '../lib/acorn'
]

factory = (_, acorn)->
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

    searchGlobals = (node, env, globalEnv)->
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
                searchGlobals node.body, env, globalEnv

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
                    searchGlobals expr, env, globalEnv

            when 'ExpressionStatement'
                searchGlobals node.expression, env, globalEnv

            when 'VariableDeclaration'
                for declaration in node.declarations
                    searchGlobals declaration, env, globalEnv

            when 'VariableDeclarator'
                if node.init
                    searchGlobals node.init, env, globalEnv

                if node.id.type is 'Identifier'
                    env.set node.id.name, true

            when 'CallExpression'
                for arg in node.arguments
                    searchGlobals arg, env, globalEnv

                searchGlobals node.callee, env, globalEnv

            when 'MemberExpression'
                if node.object.type is 'Identifier'
                    computeIdentifier node.object, env, globalEnv

            when 'BinaryExpression'
                searchGlobals node.left, env, globalEnv
                searchGlobals node.right, env, globalEnv

            when 'ConditionalExpression', 'IfStatement'
                searchGlobals node.test, env, globalEnv
                searchGlobals node.consequent, env, globalEnv
                searchGlobals node.alternate, env, globalEnv

            when 'SwitchStatement'
                searchGlobals node.discriminant, env, globalEnv
                for cnode in node.cases
                    searchGlobals cnode, env, globalEnv

            when 'SwitchCase'
                searchGlobals node.test, env, globalEnv
                for cnode in node.consequent
                    searchGlobals cnode, env, globalEnv

        return


    parse: (str)->
        ast = acorn.parse(str)
        globalEnv = new Environment()
        searchGlobals ast, env = new Environment(), globalEnv
        globals = _.keys globalEnv.attributes

        vars = ''
        if globals.length
            declaration = []
            for arg in globals
                declaration.push "#{arg} = 'undefined' === typeof locals.#{arg} ? globals.#{arg} : locals.#{arg}"

            vars = 'var ' + declaration.join(',\n    ') + ';'


        fnText = """
            #{vars}
            #{str}
        """

        ### jshint -W054 ###
        return new Function 'locals', 'globals', fnText
