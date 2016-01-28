deps = [
    './common'
    './eachSeries'
    './patch'
]

factory = ({$, Backbone}, eachSeries)->

    class BasicBackboneApplication extends Backbone.Model

        take: ->
            throw new Error 'application is busy' if this.$$busy
            this.$$busy = true
            return

        give: ->
            this.$$busy = false
            return

        initialize: ->
            @isFileLocation = appConfig.baseUrl is ''
            @set 'baseUrl', if @isFileLocation then '#' else appConfig.baseUrl
            @set 'resource', appConfig.resource

            @hasPushState = not @isFileLocation and Modernizr.history

            if @hasPushState
                @getLocation = @_getPathLocation
                @_setLocationHash = @_nativeLocationHash
                @hashChar = '#'
            else
                @getLocation = @_getHashLocation
                @_setLocationHash = @_customLocationHash
                @hashChar = '!'

            @addInitializer ieTask = (options)->
                # IE special task
                return if typeof document.documentMode is 'undefined'

                if document.documentMode < 9
                    depsLoader.loadScript appConfig.baseUrl + 'vendor/html5shiv.js'
                    depsLoader.loadScript appConfig.baseUrl + 'vendor/respond.src.js'

                if document.documentMode < 8
                    # IE < 8 fetch from cache
                    $.ajaxSetup cache: false

                # Add IE-MODE-xx to body. For css
                if typeof document.body.className is 'string' and document.body.className.length > 0
                    document.body.className += ' '
                document.body.className += 'IE-MODE-' + document.documentMode

                return

            @addInitializer @initRouter

            @once 'start', initHistory = (options)->
                location = @_getHashLocation()

                if @hasPushState
                    #   /context/.../#pathname?query!anchor -> /context/pathname?query#anchor
                    if routeInfo = @router.getRouteInfo location
                        [engine, pathParams] = routeInfo
                        window.location.href = appConfig.baseUrl + location.pathname + location.search + '#' + location.hash.substring(1)
                        return
                else if not @router.getRouteInfo location
                    #   use route from pathname with partial match
                    #   preserve hash
                    #   /context/pathname?query#anchor -> /context/#pathname?query!anchor
                    url = appConfig.baseUrl + '#' + location.pathname + location.search + location.hash
                    window.location.href = url if url isnt window.location.href

                @_listenHrefClick()
                Backbone.history.start pushState: @hasPushState
                return
            , @
            return

        start: (options, done)->
            app = @

            eachSeries app, app.tasks.map((task)-> [task, options]), ->
                throw new Error 'a router must be defined' if not app.router
                app.emit 'start'
                done() if 'function' is typeof done
                return

            return

        addInitializer: (fn)->
            @tasks = [] if not @tasks

            if 'function' is typeof fn
                if fn.length > 2
                    throw new Error 'Initializer function must be a function waiting for 2 arguments a most'

                @tasks.push fn
            return

        initRouter: (options)->
            throw new Error 'a router must be defined'

        setLocationHash: (hash)->
            hash or (hash = @getLocation().hash)
            return false if not hash
            if hash.charAt(0) in ['#', '!']
                hash = hash.substring 1
            return false if hash.length is 0

            @_setLocationHash hash
            return true

        _getPathLocation: (url)->
            if url
                splitPathReg = /^([^?#]*)(\?[^#]*)?(\#.*)?$/
                return {pathname: '', search: '', hash: ''} if not (split = splitPathReg.exec url)
                pathname: split[1] or ''
                search: split[2] or ''
                hash: split[3] or ''
            else
                pathname: window.location.pathname
                search: window.location.search
                hash: window.location.hash

        _getHashLocation: (url)->
            url or (url = window.location.hash.slice(1))
            # '#url?query!anchor'
            splitPathReg = /^([^?!]*)(\?[^!]*)?(\!.*)?$/
            return {pathname: '', search: '', hash: ''} if not (split = splitPathReg.exec url)

            pathname: split[1] or ''
            search: split[2] or ''
            hash: split[3] or ''

        _nativeLocationHash: (hash)->
            if window.location.hash is '#' + hash
                element = document.getElementById(hash) or $("[name=#{hash.replace(/([^\w\-.])/g, '\\$1')}]")[0]
                element.scrollIntoView() if element
            else
                window.location.hash = '#' + hash

            return

        _customLocationHash: (hash)->
            location = @_getHashLocation()
            location.hash = '!' + hash
            window.location.hash = '#' + location.pathname + location.search + location.hash
            element = document.getElementById(hash) or $("[name=#{hash}]")[0]
            element.scrollIntoView() if element

            return

        _listenHrefClick: ->
            app = @
            $document = $(document)

            # on IE < 9 which is not defined on click event, only on mouseup and mousedown
            if document.documentMode < 9
                isIElt8 = true
                which = 0
                $document.on 'mouseup mousedown', (evt)->
                    which = evt.which

            $document.on 'click', 'a[href]', (evt) ->

                # Allow prevent propagation
                return if evt.isDefaultPrevented()

                if not isIElt8
                    which = evt.which

                # Only trigger router on left click with no fancy stuff
                # allowing open in new tab|window shortcut
                return if which isnt 1 or evt.altKey or evt.ctrlKey or evt.shiftKey

                # Only cares about non anchor click
                href = this.getAttribute 'href'
                _char = href.charAt(0)

                if _char is '!'
                    evt.preventDefault()
                    app.setLocationHash href
                    return

                if _char is '#'
                    if app.hasPushState
                        evt.preventDefault()
                        app.setLocationHash href
                        return

                    hash = href.substring 1
                    if document.getElementById(hash) or $("[name=#{hash.replace(/([\\\/])/g, '\\$1')}]")[0]
                        evt.preventDefault()
                        app.setLocationHash href
                        return

                # Get the absolute root path
                root = window.location.protocol + '//' + window.location.host

                # Only care about relative path
                return if this.href.slice(0, root.length) isnt root
                href = href.slice(root.length) if href.slice(0, root.length) is root

                # Stop the default event to ensure that the link will not cause a page refresh.
                evt.preventDefault()

                # Avoid trigger router for irrelevant click
                return if href is '#' or href is ''

                # `Backbone.history.navigate` is sufficient for all Routers and will
                # trigger the correct events. The Router's internal `navigate` method
                # calls this anyways.    The fragment is sliced from the root.
                app.router.navigate href,
                    trigger: true
                    replace: false
                , evt

                return

            return

    BasicBackboneApplication::emit = BasicBackboneApplication::trigger

    return BasicBackboneApplication
