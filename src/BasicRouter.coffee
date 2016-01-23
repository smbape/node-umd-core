deps = [
	'./common'
	'./RouterEngine'
    './QueryString'
    './StackArray'
]

factory = ({_, $, Backbone}, RouterEngine, qs, StackArray)->
    hasOwn = {}.hasOwnProperty

    class BasicRouter extends Backbone.Router
        constructor: (config)->
            super routes: '*url': 'dispatch'

            if not config.app
                throw new Error 'app property is undefined'

            @app = config.app
            @_initRoutes config
            @_history = new StackArray()
            @container = $ config.container or document.body

        dispatch: (url, options, callback)->
            if url is null
                if @_otherwise
                    @navigate @_otherwise
                else if @otherwise
                    url = ''
                    otherwise = true
                else
                    throw new Error "unmatched route for #{url}"
                return

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

        _dispatch: ({container, location, url, prevUrl, otherwise}, options, callback)->
            # {route, handler} = options

            # if 'string' is typeof handler
            #     if not hasOwn.call @handlerByName, handler
            #         throw new Error "unknown handler '#{handler}'"

            #     handler = @handlerByName[handler]

            app = @app
            router = @
            queryParams = qs.parse location.search

            if otherwise
                handlers = [@otherwise]
            else
                for route, routeConfig of @engines
                    {engine, handlers} = routeConfig
                    pathParams = engine.getParams location.pathname, {throws: false}
                    break if pathParams

                if not pathParams
                    if @otherwise
                        handlers = [@otherwise]
                    else
                        throw new Error "unmatched route for #{location.pathname}"

            handlerOptions = {
                container
                location
                url
                pathParams
                queryParams
                params: _.extend {}, pathParams, queryParams
            }

            index = 0
            length = handlers.length
            iterate = (err, res)->
                if not err or index is length
                    app.give()

                    if err
                        router.onRouteChangeFailure err, handlerOptions
                    else
                        router.onRouteChangeSuccess res, handlerOptions

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
                for attr in target.attributes
                    {name, value} = attr
                    if prefix is name.substring 0, prefix.length
                        options[name.substring(prefix.length)] = value

            location = @app.getLocation fragment
            if location.pathname.charAt(0) in ['/', '#']
                location.pathname = location.pathname.substring(1)

            if options.force
                Backbone.history.fragment = null
                options.trigger = true
            else if @_location and location.pathname is @_location.pathname and location.search is @_location.search
                location = @app.getLocation fragment
                @app.setLocationHash location.hash
                return @

            super

        templateWillMount: (html, engineName, options)->
            baseUrl = @app.get 'baseUrl'
            html.replace /\b(href|src|data-main)="(?!mailto:|https?\:\/\/|[\/#!])([^"]+)/g, "$1=\"#{baseUrl}$2"

        onRouteChangeSuccess: (res, options)->
            @_location = options.location
            if res?.title
                document.title = res.title
            return

        onRouteChangeFailure: (options)->

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

        _initRoutes: ({routes, otherwise})->
            if  'string' is typeof otherwise
                router = @
                app = @app
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
            baseUrl = @app.get('baseUrl')

            for route, config of routes
                options = _.pick config, RouterEngine::validOptions

                options.baseUrl = baseUrl
                options.route = route

                routeConfig = engines[route] =
                    engine: new RouterEngine options
                    title: new RouterEngine config.title

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
                            fn = @_controllerHandler handler, config
                        when 'view'
                            fn = @_viewHandler handler, config
                        when 'template'
                            fn = @_templateHandler handler, config
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

        _controllerHandler: (handler, config)->
            router = @
            titleEngine = config.title
            engine = new RouterEngine handler
            (options, callback)->

                {pathParams} = options
                path = engine.getFilePath pathParams

                require [path], (Controller)->
                    if 'function' isnt typeof Controller
                        return callback(new Error "invalid Controller at #{path}")

                    method = Controller::getMethod options

                    if 'function' isnt typeof Controller::method
                        return callback(new Error "controller at #{path}: invalid method")

                    return callback(null, Controller) if options.constructor

                    controller = new Controller _.defaults {
                        title:  if titleEngine then titleEngine.getUrl(pathParams)
                        router: router
                    }, options

                    if 'function' isnt controller[method]
                        return callback(new Error 'invalid method')

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

        _viewHandler: (handler, config)->
            router = @
            titleEngine = config.title
            engine = new RouterEngine handler
            (options, callback)->

                {pathParams} = options
                path = engine.getFilePath pathParams

                require [path], (View)->
                    if 'function' isnt typeof View
                        return callback(new Error "invalid View at #{path}")

                    return callback(null, View) if options.constructor

                    view = new View title:  if titleEngine then titleEngine.getUrl(pathParams)

                    if 'function' isnt typeof view.render or view.render.length < 1 or view.render.length > 2
                        return callback(new Error "view at #{path}: invalid render method. It should be a function expecting one or two arguments")

                    if view.render.length is 2
                        timeout = setTimeout ->
                            console.log 'taking too long to render. Make sure you called done function'
                            return
                        , 1000
                        view.render options.container, (err)->
                            clearTimeout timeout
                            callback err, view
                            return

                    else
                        view.render options.container
                        callback null, view

                    return

                return

        _templateHandler: (handler, config)->
            router = @
            titleEngine = config.title
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
                            throw new Error "invalid template at #{path}"
                    
                    options.container.empty().html @templateWillMount html, engine.name, options
                    callback null, title: if titleEngine then titleEngine.getUrl(pathParams)

                    return

                return
