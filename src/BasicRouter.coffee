deps = [
	'./common'
	'./RouterEngine'
    './QueryString'
    './StackArray'
]

factory = ({_, $, Backbone}, RouterEngine, qs, StackArray)->
    hasOwn = {}.hasOwnProperty

    class BasicRouter extends Backbone.Router
        constructor: (options)->
            options = _.clone options

            proto = @constructor.prototype

            currProto = proto
            while currProto
                for own opt of currProto
                    if opt.charAt(0) isnt '_' and not hasOwn.call(options, opt) and 'undefined' isnt typeof @[opt]
                        options[opt] = @[opt]
                currProto = currProto.constructor?.__super__

            super routes: '*url': 'dispatch'

            if not options.app
                throw new Error 'app property is undefined'

            @current = {}
            @_initRoutes options
            @_history = new StackArray()
            @container = options.container or document.body

        navigate: (fragment, options = {}, evt)->
            # evt is defined when comming from a click on a[href]
            options.evt = evt
            if _.isObject evt
                target = evt.target

                if target.nodeName isnt 'A'
                    # faster way to do a target.closest('a')
                    while target and target.nodeName isnt 'A'
                        target = target.parentNode

                prefix = 'data-navigate-'
                length = prefix.length
                for attr in target.attributes
                    {name, value} = attr
                    if prefix is name.substring 0, length
                        options[name.substring(length)] = value

            location = @app.getLocation fragment
            if location.pathname.charAt(0) in ['/', '#']
                location.pathname = location.pathname.substring(1)

            if options.force
                Backbone.history.fragment = null
                options.trigger = true
            else if @current.location and location.pathname is @current.location.pathname and location.search is @current.location.search
                location = @app.getLocation fragment
                @app.setLocationHash location.hash
                return @

            super

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
            else if not _.isPlainObject options
                options = {}

            app = @app

            location = options.location or app.getLocation url
            url = location.pathname + location.search

            prevUrl = @getPrevUrl()

            if not app.hasPushState and document.getElementById url
                # Scroll into view has already been done
                url = prevUrl + '!' + url
                @navigate url, {trigger: false, replace: true}
                return

            if hasOwn.call options, 'container'
                container = options.container

            mainContainer = @container

            if not container or container is mainContainer
                container = mainContainer
                @addHistory url

            @_dispatch {container, location, url, prevUrl, otherwise}, options, callback
            return

        getRouteInfo: (location, options)->
            options = _.defaults {throws: false}, options
            for route, routeConfig of @engines
                {engine, handlers} = routeConfig
                pathParams = engine.getParams location.pathname, options
                break if pathParams

            if pathParams
                return [engine, pathParams, handlers]

        _dispatch: (copts, options, callback)->
            app = @app
            router = @

            if app.$$busy
                # changing is too fast
                # wait 200 ms and retry
                clearTimeout @_waiting
                @_waiting = setTimeout _.bind(->
                    @_dispatch copts, options, callback
                    return
                , @), 200
                return

            {container, location, url, prevUrl, otherwise} = copts
            queryParams = qs.parse location.search

            if otherwise
                handlers = [@otherwise]
            else if routeInfo = @getRouteInfo location
                [engine, pathParams, handlers] = routeInfo
            else if @otherwise
                handlers = [@otherwise]
            else
                throw new Error "unmatched route for #{location.pathname}"

            if app.$$rendable
                app.$$rendable.destroy()
                app.$$rendable = null

            $(container).empty()

            handlerOptions = {
                container
                location
                url
                pathParams
                queryParams
                params: _.extend {}, pathParams, queryParams
                engine
            }

            index = 0
            length = handlers.length
            iterate = (err, res)->
                if not err or index is length
                    app.give()
                    app.current = router.current = handlerOptions
                    if _.isObject(res) and 'function' is typeof res.destroy
                        app.$$rendable = res
                    else
                        app.$$rendable = null

                    if err
                        container.innerHTML = err
                        router.onRouteChangeFailure err, handlerOptions
                        app.emit 'routeChangeFailure', router, err, options
                    else
                        app.setLocationHash()
                        router.onRouteChangeSuccess res, handlerOptions
                        app.emit 'routeChangeSuccess', router, res, options

                    callback(err, res) if 'function' is typeof callback
                    return

                handler = handlers[index++]

                timeout = setTimeout ->
                    console.log 'taking too long to handle. Make sure you called done function', handler
                    return
                , 1000

                handler.call router, handlerOptions, (err, res)->
                    clearTimeout timeout
                    iterate err, res
                    return
                return

            app.take()
            iterate(1)

            return

        templateWillMount: (html, engineName, options)->
            baseUrl = @app.get 'baseUrl'
            html.replace /\b(href|src|data-main)="(?!mailto:|https?\:\/\/|[\/#!])([^"]+)/g, "$1=\"#{baseUrl}$2"

        getRendableTitle: (rendable)->
            if rendable
                title = _.result(rendable, 'title')

                if not title and 'function' is typeof rendable?.get
                    title = _.result null, rendable.get('title')

                if not title and rendable.props?.title
                    title = rendable.props.title

            return title

        onRouteChangeSuccess: (rendable, options)->
            if title = @getRendableTitle rendable
                document.title = title

            # publicly notify render
            appConfig.render() if 'function' is typeof appConfig.render
            return

        onRouteChangeFailure: (err, options)->

        engine: (name)->
            @routeByName[name]?.engine

        title: (name)->
            @routeByName[name]?.title

        getPrevUrl: ->
            @_history.get -1

        addHistory: (url)->
            @_history.push url
            return @

        back: ->
            url = @_history.get -2
            @navigate url,
                trigger: true
                replace: false
            return

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

                if 'string' is typeof config.title
                    routeConfig.title = new RouterEngine route: config.title

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
                                throw new Error "Error in route '#{route}', handler '#{handler.name}': unknown type or no fn 'function'"

                            fn = handler.fn

                    handlers.push fn

                    if 'string' is typeof handler.name
                        if hasOwn.call handlerByName, handler.name
                            throw new Error "Error in route '#{route}', handler #{index}: duplicate handler name '#{handler.name}'"
                        
                        handlerByName[handler.name] = fn
            return

        _controllerHandler: (handler, routeConfig)->
            router = @
            titleEngine = routeConfig.title
            engine = new RouterEngine handler
            (options, callback)->

                {pathParams} = options
                path = engine.getFilePath pathParams

                require [path], (Controller)->
                    if 'function' isnt typeof Controller
                        return callback(new Error "invalid Controller at #{path}: not a function")

                    if 'function' isnt typeof Controller::getMethod
                        return callback(new Error "invalid Controller at #{path}: prototype property 'getMethod' must be a function")

                    method = Controller::getMethod options

                    if 'function' isnt typeof Controller::[method]
                        return callback(new Error "controller at #{path}: prototype property '#{method}' is not a function")

                    return callback(null, Controller) if options.checkOnly

                    controller = new Controller _.defaults {
                        title:  if titleEngine then titleEngine.getUrl(pathParams)
                        router: router
                    }, options

                    if 'function' isnt typeof controller[method]
                        return callback(new Error "controller at #{path}: instance property '#{method}' is not a function")

                    if controller[method].length is 1
                        timeout = setTimeout ->
                            console.log 'taking too long to render. Make sure you called done function'
                            return
                        , 1000
                        controller[method] (err)->
                            clearTimeout timeout
                            callback err, controller
                            return
                    else
                        controller[method]()
                        callback null, controller

                    return
                , callback

                return

        _viewHandler: (handler, routeConfig)->
            router = @
            titleEngine = routeConfig.title
            engine = new RouterEngine handler
            (options, callback)->

                {pathParams} = options
                path = engine.getFilePath pathParams

                require [path], (View)->
                    if 'function' isnt typeof View
                        return callback(new Error "invalid View at #{path}")

                    return callback(null, View) if options.checkOnly

                    props =
                        container: options.container
                        title: titleEngine?.getUrl(pathParams)

                    if 'function' is typeof View.createElement
                        view = View.createElement props
                    else
                        view = new View props

                    if 'function' isnt typeof view.doRender or view.doRender.length > 1
                        return callback(new Error "view at #{path}: invalid render method. It should be a function expectingat most ine argument")

                    if view.doRender.length is 1
                        timeout = setTimeout ->
                            console.log 'taking too long to render. Make sure you called done function'
                            return
                        , 1000
                        view.doRender (err)->
                            clearTimeout timeout
                            callback err, view
                            return

                    else
                        view.doRender()
                        callback null, view

                    return
                , callback

                return

        _templateHandler: (handler, routeConfig)->
            router = @
            titleEngine = routeConfig.title
            engine = new RouterEngine handler
            (options, callback)->

                {pathParams} = options
                path = engine.getFilePath pathParams

                require [path], (template)->
                    switch typeof template
                        when 'function'
                            html = template()
                        when 'string'
                            html = template
                        else
                            callback new Error "invalid template at #{path}"
                            return
                    
                    $(options.container).html router.templateWillMount html, engine.name, options
                    callback null, title: if titleEngine then titleEngine.getUrl(pathParams)

                    return
                , callback

                return
