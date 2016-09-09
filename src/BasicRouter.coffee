deps = [
	'./common'
	'./RouterEngine'
    './QueryString'
]

factory = ({_, $, Backbone}, RouterEngine, qs)->
    hasOwn = {}.hasOwnProperty

    CACHE_STRATEGIES =
        LOCATION: ({location})->
            JSON.stringify location

        PATHNAME: ({location})->
            location.pathname

        URL: ({url})->
            url

        VARIABLES: ({pathParams, engine})->
            if pathParams and engine
                JSON.stringify _.pick pathParams, engine.getVariables()

    makeError = (msg, code)->
        err = new Error msg
        err.code = code
        err

    class BasicRouter extends Backbone.Router
        app: null
        routes: null
        otherwise: null

        getCacheId: CACHE_STRATEGIES.VARIABLES

        constructor: (options)->
            options = _.clone options

            for own opt of options
                if opt.charAt(0) isnt '_' and opt of @
                    @[opt] = options[opt]

            _.extend options, _.pick @, ['app', 'routes', 'otherwise']
            super routes: '*url': 'dispatch'

            if not options.app
                throw new Error 'app property is undefined'

            @current = {}
            @_initRoutes options
            @container = options.container or document.body

        navigate: (fragment, options = {})->
            location = @app.getLocation fragment
            if location.pathname.charAt(0) in ['/', '#']
                location.pathname = location.pathname.substring(1)

            if @current.location and location.pathname is @current.location.pathname and location.search is @current.location.search
                if options.force
                    Backbone.history.loadUrl location.pathname + location.search + location.hash
                    return

                location = @app.getLocation fragment
                @app.setLocationHash location.hash
                return

            super

        getCurrentUrl: ->
            if location = @app.getLocation()
                return location.pathname + location.search + location.hash

        refresh: ->
            if url = @getCurrentUrl()
                Backbone.history.loadUrl url
            return

        dispatch: (url, options, callback)->
            if url is null
                if @_otherwise
                    @navigate @_otherwise
                    return
                else if @otherwise
                    url = ''
                    otherwise = true
                else
                    throw new Error "unmatched route for #{url}"

            if typeof options is 'string'
                url += '?' + options
                options = {}
            else if not _.isObject options
                options = {}

            app = @app

            location = options.location or app.getLocation url
            url = location.pathname + location.search

            if not app.hasPushState and document.getElementById(url)
                # Scroll into view has already been done
                # url = prevUrl + '!' + url
                # @navigate url, {trigger: false, replace: true}
                return

            if hasOwn.call options, 'container'
                container = options.container

            mainContainer = @container

            if not container
                container = mainContainer

            if not container
                callback() if 'function' is typeof callback
                return

            @_dispatch {container, location, url, otherwise}, options, callback
            return

        getRouteInfo: (location, options)->
            options = _.defaults {throws: false}, options
            for route, routeConfig of @engines
                {engine, handlers} = routeConfig
                try
                    pathParams = engine.getParams location.pathname, options
                    break if pathParams
                catch err

            if pathParams
                return [engine, pathParams, handlers]

        clearContainer: (container)->
            if prevRendable = $.data(container, 'rendable')
                prevRendable.destroy()
                $.removeData(container, 'rendable')

            return

        _dispatch: (copts, options, done)->
            app = @app
            router = @

            if app.$$busy
                # changing is too fast
                # wait 200 ms and retry
                clearTimeout @_waiting
                @_waiting = setTimeout =>
                    @_dispatch copts, options, done
                    return
                , 200
                return

            {container, location, url, otherwise} = copts
            queryParams = qs.parse location.search

            if otherwise
                handlers = [@otherwise]
            else if routeInfo = @getRouteInfo location
                [engine, pathParams, handlers] = routeInfo
            else if @otherwise
                handlers = [@otherwise]
            else
                throw new Error "unmatched route for #{location.pathname}"

            @clearContainer container

            $(container).empty()

            handlerOptions = {
                container
                location
                url
                pathParams
                queryParams
                params: _.extend {}, pathParams, queryParams
                engine
                router
                app
            }

            callback = (err, res)->
                if callback.called
                    return
                callback.called = true

                app.give()
                app.current = router.current = handlerOptions

                if _.isObject(res) and 'function' is typeof res.destroy
                    rendable = res

                if err
                    if rendable
                        rendable.destroy()

                    console.error err, err.stack
                    router.onRouteChangeFailure err, handlerOptions
                    router.emit 'routeChangeFailure', err, options
                    app.emit 'routeChangeFailure', router, err, options
                else
                    if rendable
                        $.data(container, 'rendable', rendable)

                    container.scrollTop = 0

                    app.setLocationHash()
                    router.onRouteChangeSuccess res, handlerOptions, options
                    router.emit 'routeChangeSuccess', res, handlerOptions, options
                    app.emit 'routeChangeSuccess', router, res, handlerOptions, options

                router.afterDispatch(err, res, handlerOptions)
                done(err, res) if 'function' is typeof done
                return

            if 'function' is typeof @getCacheId
                cacheId = @getCacheId handlerOptions
                if cacheId and hasOwn.call router.routeCache, cacheId
                    router.executeHandler router.routeCache[cacheId], handlerOptions, callback
                    return

            index = 0
            length = handlers.length
            iterate = (err, res, initial)->
                # if (err instanceof EvalError) or (err instanceof RangeError) or (err instanceof ReferenceError) or (err instanceof SyntaxError) or (err instanceof TypeError) or (err instanceof URIError)
                if not (err instanceof Error) or # Error that are not instance of Error are not module not found errors
                (err.code not in ['CONTROLLER_HANDLER', 'VIEW_HANDLER', 'TEMPLATE_HANDLER'] and # Invalid handler
                not /^(?:Cannot find module|Script error for) /.test(err.message)) # CommonJs module not found error and RequireJs module not found error
                    callback err, res
                    return

                if not err or index is length
                    if not err and cacheId
                        router.routeCache[cacheId] = handlers[index - 1]

                    callback err, res
                    return

                if _.isObject err
                    console.error err, err.stack

                router.executeHandler handlers[index++], handlerOptions, iterate
                return

            @beforeDispatch(handlerOptions)

            app.take()
            router.executeHandler handlers[index++], handlerOptions, iterate

            return

        executeHandler: (handler, handlerOptions, done)->
            timeout = setTimeout ->
                console.log 'taking too long to handle. Make sure you called done function'
                return
            , 1000

            try
                handler.call @, handlerOptions, (err, res)->
                    clearTimeout timeout
                    done err, res
                    return
            catch err
                clearTimeout timeout
                done err

            return

        onRouteChangeSuccess: (rendable, options)->

        onRouteChangeFailure: (err, { container })->
            container.innerHTML = err
            return

        engine: (name)->
            @routeByName[name]?.engine

        back: ->
            window.history.back()
            return

        forward: ->
            window.history.forward()
            return

        beforeDispatch: (options)->

        afterDispatch: (err, rendable, options)->

        isMainContainer: (container)->
            container is @container

        _extractParameters: (route, fragment) ->
            # return fragment as is
            # parsing is done in dispatch
            [fragment or null]

        _initRoutes: ({app, routes, otherwise})->
            @app = app

            if 'function' is typeof routes
                routes = routes.call @

            if  'string' is typeof otherwise
                router = @
                location = app.getLocation otherwise
                @_otherwise = otherwise
                otherwise = do (otherwise, location, router, app)->
                    (options, callback)->
                        if _.isEqual location, app.getLocation options.url
                            throw new Error "unmatched route for #{otherwise}"

                        router.navigate otherwise
                        callback()
                        return

            @otherwise = otherwise if 'function' is typeof otherwise
            @routeCache = {}
            engines = @engines = {}
            routeByName = @routeByName = {}
            handlerByName = @handlerByName = {}
            baseUrl = app.get('baseUrl')

            for route, config of routes
                options = _.pick config, RouterEngine::validOptions

                options.baseUrl = baseUrl
                options.route = route

                routeConfig = engines[route] =
                    engine: new RouterEngine options

                if 'string' is typeof config.name
                    if hasOwn.call routeByName, config.name
                        throw new Error "Error in route '#{route}', handler #{index}: duplicate route name '#{config.name}'"

                    routeByName[config.name] = routeConfig

                if not Array.isArray config.handlers
                    throw new Error "Error in route '#{route}': handlers options must an Array"

                handlers = routeConfig.handlers = []
                for handler, index in config.handlers
                    switch handler.type
                        when 'controller'
                            fn = @_controllerHandler handler, routeConfig
                        when 'view'
                            fn = @_viewHandler handler, routeConfig
                        when 'template'
                            fn = @_templateHandler handler, routeConfig
                        else
                            if 'function' isnt typeof handler.fn
                                throw new Error "Error in route '#{route}', handler '#{handler.name}': unknown type '#{handler.type}' or no fn 'function'"

                            fn = handler.fn

                    handlers.push fn

                    if 'string' is typeof handler.name
                        if hasOwn.call handlerByName, handler.name
                            throw new Error "Error in route '#{route}', handler #{index}: duplicate handler name '#{handler.name}'"

                        handlerByName[handler.name] = fn
            return

        _controllerHandler: (handler, routeConfig)->
            router = @
            engine = new RouterEngine handler
            (options, callback)->

                {pathParams} = options
                path = engine.getFilePath pathParams

                require [path], (Controller)->
                    if 'function' isnt typeof Controller
                        return callback makeError "Invalid Controller at #{path}: not a function", 'CONTROLLER_HANDLER'

                    if 'function' isnt typeof Controller::getMethod
                        return callback makeError "Invalid method 'getMethod'. Controller.prototype.getMethod is not a function (#{path})", 'CONTROLLER_HANDLER'

                    method = Controller::getMethod options

                    if 'function' isnt typeof Controller::[method]
                        return callback makeError "Invalid method '#{method}'. Controller.prototype.#{method} is not a function (#{path})", 'CONTROLLER_HANDLER'

                    return callback(null, Controller) if options.checkOnly

                    controller = new Controller _.defaults {
                        router: router
                    }, options

                    if 'function' isnt typeof controller[method]
                        return callback makeError "Invalid method '#{method}'. controller.#{method} is not a function (#{path})", 'CONTROLLER_HANDLER'

                    if controller[method].length is 1
                        timeout = setTimeout ->
                            console.log 'taking too long to render. Make sure you called done function'
                            return
                        , 1000

                        try
                            controller[method] (err)->
                                clearTimeout timeout
                                callback err, controller
                                return
                        catch err
                            clearTimeout timeout
                            callback err, controller
                    else
                        try
                            controller[method]()
                        catch err
                        callback err, controller

                    return
                , callback

                return

        _viewHandler: (handler, routeConfig)->
            router = @
            engine = new RouterEngine handler
            (options, callback)->

                {pathParams} = options
                path = engine.getFilePath pathParams

                require [path], (View)->
                    if 'function' isnt typeof View
                        return callback makeError "Invalid View at #{path}", 'VIEW_HANDLER'

                    return callback(null, View) if options.checkOnly

                    options = _.defaults {
                        router: router
                    }, options

                    if 'function' is typeof View.createElement
                        view = View.createElement options
                    else
                        view = new View options

                    if 'function' isnt typeof view.render or view.render.length > 1
                        return callback makeError "view at #{path}: Invalid render method. It should be a function expectingat most ine argument", 'VIEW_HANDLER'

                    if view.render.length is 1
                        timeout = setTimeout ->
                            console.log 'taking too long to render. Make sure you called done function'
                            return
                        , 1000
                        try
                            view.render (err)->
                                clearTimeout timeout
                                callback err, view
                                return
                        catch err
                            clearTimeout timeout
                            callback err, view

                    else
                        try
                            view.render()
                        catch err
                        callback err, view

                    return
                , callback

                return

        _templateHandler: (handler, routeConfig)->
            router = @
            engine = new RouterEngine handler
            (options, callback)->

                {pathParams} = options
                path = engine.getFilePath pathParams

                require [path], (template)->
                    switch typeof template
                        when 'function'
                            html = template(options)
                        when 'string'
                            html = template
                        else
                            callback makeError "Invalid template at #{path}", 'TEMPLATE_HANDLER'
                            return

                    $(options.container).html html
                    callback()
                    return
                , callback

                return

    BasicRouter::emit = BasicRouter::trigger
    BasicRouter.CACHE_STRATEGIES = CACHE_STRATEGIES
    BasicRouter
