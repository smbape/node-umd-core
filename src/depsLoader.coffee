((root, factory) ->
    'use strict'
    if typeof exports isnt 'undefined'
        # Node/CommonJS
        module.exports = factory()
    else if typeof define is 'function' and define.amd
        # AMD
        define ['./path-browserify'], factory
    else
        root.depsLoader = factory root.pathBrowserify
    return
) this, (path)->
    'use strict'

    isObject = (obj)->
        return typeof obj is 'object' and obj isnt null

    extend = (target, src)->
        if isObject(src) and isObject(target)
            for own prop of src
                target[prop] = src[prop]
        target

    # Module definition for Common Specification
    commonSpecDefine = (require, type, deps, factory, global)->
        deps = [] if typeof deps is 'undefined'

        # a call for require within the module, will call commonSpecRequire
        localRequire = (deps, callback, errback, options)->
            commonSpecRequire require, type, deps, callback, errback, options, global

        libs = [localRequire]

        _processDep = (dep)->
            if typeof dep is 'undefined'
                libs.push null
                return

            switch dep.charAt(0)
                when '!'
                    # global depency requested
                    throw 'global scope is not defined' if not global
                    libs.push global[dep.substring(1)]
                when '$'
                    # Ignore dependency. To use with angular as an example
                    libs.push null
                else
                    libs.push require dep

            return


        for dep in deps
            if typeof dep is 'string'
                _processDep dep
            else if isObject dep
                _processDep dep[type]

        factory.apply global, libs

    commonSpecRequire = (require, type, deps, callback, errback, options, global)->

        if typeof deps is 'string'
            deps = [deps]
        else if typeof deps is 'undefined'
            deps = []
        libs = []
        errors = []
        hasError = false

        _processDep = (dep)->
            if typeof dep is 'undefined'
                libs.push null
                return

            switch dep.charAt(0)
                when '!'
                    # global depency requested
                    throw 'global scope is not defined' if not global
                    libs.push global[dep.substring(1)]
                when '$'
                    # Ignore dependency. To use with angular as an example
                    libs.push null
                else
                    try
                        libs.push require dep
                    catch ex
                        throw ex if typeof errback isnt 'function'
                        hasError = true
                        errors.push ex

            return

        for dep in deps
            if typeof dep is 'string'
                _processDep dep
            else if isObject dep
                _processDep dep[type]

        if hasError
            errback.apply global, errors
        else if typeof callback is 'function'
            callback.apply global, libs
        else if deps.length is 1
            libs[0]

    amdDefine = (name, deps, factory, global)->
        if arguments.length is 3
            global = factory
            factory = deps
            deps = name
            name = null

        deps = [] if typeof deps is 'undefined'
        libs = ['require']
        availables = []
        map = {}

        _processDep = (dep, index)->
            if typeof dep is 'undefined'
                availables[index] = null
                return

            if typeof dep is 'string'
                switch dep.charAt(0)
                    when '!'
                        # global depency requested
                        throw 'global scope is not defined' if not global
                        availables[index] = global[dep.substring(1)]
                    when '$'
                        # Ignore dependency. To use with angular as an example
                        availables[index] = null
                    else
                        map[libs.length] = index
                        libs.push dep
            return

        for dependency, index in deps
            if typeof dependency is 'string'
                _processDep dependency, index + 1
            else if isObject dependency
                _processDep dependency.amd, index + 1

        callback = (require)->
            # if name is 'ng-tutorial/controllers/HomeController'
            #     debugger
            for index in [1...arguments.length] by 1
                availables[map[index]] = arguments[index]
            
            localRequire = (deps, callback, errback, options)->
                amdRequire require, deps, callback, errback, options, global
            availables[0] = localRequire

            factory.apply this, availables

        # if name is 'ng-tutorial/controllers/HomeController'
        #     debugger
        if name
            define name, libs, callback
        else
            define libs, callback

    amdRequire = (require, deps, callback, errback, options, global)->

        if typeof deps is 'string'
            deps = [deps]
        else if typeof deps is 'undefined'
            deps = []
        libs = []
        availables = []
        map = {}

        _processDep = (dep, index)->
            if typeof dep is 'undefined'
                availables[index] = null
                return

            if typeof dep is 'string'
                switch dep.charAt(0)
                    when '!'
                        # global depency requested
                        throw 'global scope is not defined' if not global
                        availables[index] = global[dep.substring(1)]
                    when '$'
                        # Ignore dependency. To use with angular as an example
                        availables[index] = null
                    else
                        try
                            availables[index] = require dep
                        catch ex
                            map[libs.length] = index
                            libs.push dep

            return

        for dependency, index in deps
            if typeof dependency is 'string'
                _processDep dependency, index
            else if isObject dependency
                _processDep dependency.amd, index

        if typeof callback isnt 'function' and deps.length is 1
            return availables[0]

        if libs.length is 0
            return callback.apply global, availables

        require libs, ->
            for lib, index in arguments
                availables[map[index]] = lib
            callback.apply global, availables
        , errback
        return

    # For bower component files that has AMD definition and requires relative paths
    localDefine = (workingFile)->
        fn = (deps)->
            if Array.isArray deps
                for dep, index in deps
                    if dep.charAt(0) is '.'
                        dep = path.resolve workingFile, dep
                        deps[index] = dep

            define.apply null, arguments
        fn.amd = define.amd
        fn

    exports =
        common: commonSpecDefine
        amd: amdDefine
        define: localDefine

    has = Object::hasOwnProperty

    exports.createNgModule = (angular, name, ngdeps, ngmap, resolvedDeps)->
        toRegister = []
        for dusable, index in resolvedDeps
            if dusable.$ng
                # this is not a module injectable dependency
                toRegister.unshift index

        # remove non injectable dependencies
        for index in toRegister
            ngdeps.splice ngmap[index], 1

        app = angular.module(name, ngdeps)
        app.name = name

        # register usables
        for index in toRegister
            resolvedDeps[index] app

        app

    exports.createNgUsable = (ctor, ngmethod, $name, $path, $dirname, $shortName, ngdeps, resolvedDeps, ngmap)->

        switch ngmethod
            when 'controller'
                name = ctor::$name or (ctor::$name = $name)
                ctor::$path = $path
                ctor::$dirname = $dirname
            when 'directive', 'filter'
                name = $shortName.replace /\-([a-z])/g, (match) ->
                    match[1].toUpperCase()
            else
                name = $name

        usable = (app)->
            toRemove = []
            app.dependencies or (app.dependencies = {})
            app.dependencies[ngmethod] or (app.dependencies[ngmethod] = {})

            if !has.call(app.dependencies[ngmethod], name)
                # first instruction to prevent infinite loop with recursion
                app.dependencies[ngmethod][name] = true

                # recursively register usable dependencies
                for dusable, i in resolvedDeps
                    if dusable.$ng
                        switch dusable.$ng
                            when 'usable', 'config', 'run', 'controller', 'directive', 'filter'
                                # this is not an injectable dependency
                                # unshift to loop from higher to lower
                                # this ensure slice is done on the correct element
                                toRemove.unshift ngmap[i]
                            else
                                ngdeps[ngmap[i]] = dusable.$name
                
                        dusable.apply null, arguments

                # remove non injectable dependencies
                for index in toRemove
                    ngdeps.splice index, 1

                if ngmethod is 'usable'
                    ctor.apply null, arguments
                    return

                withoutName = ngmethod in ['config', 'run']

                # register this usable
                if withoutName
                    app[ngmethod] ctor
                else
                    app[ngmethod] name, ctor
            return

        ctor.$inject = ngdeps
        usable.$name = name
        usable.$path = $path
        usable.$dirname = $dirname
        usable.ctor = ctor
        usable.$ng = ngmethod

        usable

    browserExtend = (exports)->
        if typeof window is 'undefined' or typeof window.window isnt 'object' or window.window.window isnt window.window
            return

        head = document.getElementsByTagName('head')[0]

        # Oh the tragedy, detecting opera. See the usage of isOpera for reason.
        isOpera = typeof opera isnt 'undefined' and opera.toString() is '[object Opera]'

        load = (attributes, callback, errback, completeback)->
            node = document.createElement attributes.tag
            node.charset = 'utf-8'
            node.async = true
            for own attr, value of attributes
                if attr isnt 'tag' and node[attr] isnt value
                    node.setAttribute attr, value

            context = getContext callback, errback, completeback

            # ===========================
            # Taken from requirejs 2.1.11
            # ===========================

            # Set up load listener. Test attachEvent first because IE9 has
            # a subtle issue in its addEventListener and script onload firings
            # that do not match the behavior of all other browsers with
            # addEventListener support, which fire the onload event for a
            # script right after the script execution. See:
            # https://connect.microsoft.com/IE/feedback/details/648057/script-onload-event-is-not-fired-immediately-after-script-execution
            # UNFORTUNATELY Opera implements attachEvent but does not follow the script
            # script execution mode.

            # Check if node.attachEvent is artificially added by custom script or
            # natively supported by browser
            # read https://github.com/jrburke/requirejs/issues/187
            # if we can NOT find [native code] then it must NOT natively supported.
            # in IE8, node.attachEvent does not have toString()
            # Note the test for '[native code' with no closing brace, see:
            # https://github.com/jrburke/requirejs/issues/273
            if node.attachEvent and 
            not (node.attachEvent.toString and node.attachEvent.toString().indexOf('[native code') < 0) and 
            not isOpera

                # Probably IE. IE (at least 6-8) do not fire
                # script onload right after executing the script, so
                # we cannot tie the anonymous define call to a name.
                # However, IE reports the script as being in 'interactive'
                # readyState at the time of the define call.
                useInteractive = true
                node.attachEvent 'onreadystatechange', context.onScriptLoad

            # It would be great to add an error handler here to catch
            # 404s in IE9+. However, onreadystatechange will fire before
            # the error handler, so that does not help. If addEventListener
            # is used, then IE will fire error before load, but we cannot
            # use that pathway given the connect.microsoft.com issue
            # mentioned above about not doing the 'script execute,
            # then fire the script load event listener before execute
            # next script' that other browsers do.
            # Best hope: IE10 fixes the issues,
            # and then destroys all installs of IE 6-9.
            # node.attachEvent('onerror', context.onScriptError);
            else
                node.addEventListener 'load', context.onScriptLoad, false
                node.addEventListener 'error', context.onScriptError, false

            head.appendChild node
            return

        readyRegExp = /^(?:complete|loaded)$/

        removeListener = (node, func, name, ieName) ->

            # Favor detachEvent because of IE9
            # issue, see attachEvent/addEventListener comment elsewhere
            # in this file.
            if node.detachEvent and not isOpera

                # Probably IE. If not it will throw an error, which will be
                # useful to know.
                node.detachEvent ieName, func if ieName
            else
                node.removeEventListener name, func, false
            return

        ###
        Given an event from a script node, get the requirejs info from it,
        and then removes the event listeners on the node.
        @param {Event} evt
        @returns {Object}
        ###
        onScriptComplete = (context, evt, completeback) ->

            # Using currentTarget instead of target for Firefox 2.0's sake. Not
            # all old browsers will be supported, but this one was easy enough
            # to support and still makes sense.
            node = evt.currentTarget or evt.srcElement

            # Remove the listeners once here.
            removeListener node, context.onScriptLoad, 'load', 'onreadystatechange'
            removeListener node, context.onScriptError, 'error'
            completeback() if typeof completeback is 'function'
            return

        getContext = (callback, errback, completeback)->
            context =
                ###
                callback for script loads, used to check status of loading.

                @param {Event} evt the event from the browser for the script
                that was loaded.
                ###
                onScriptLoad: (evt) ->
                    # Using currentTarget instead of target for Firefox 2.0's sake. Not
                    # all old browsers will be supported, but this one was easy enough
                    # to support and still makes sense.
                    if evt.type is 'load' or readyRegExp.test((evt.currentTarget or evt.srcElement).readyState)
                        callback() if typeof callback is 'function'
                        onScriptComplete context, evt, completeback
                    return

                ###
                Callback for script errors.
                ###
                onScriptError: (evt) ->
                    errback() if typeof errback is 'function'
                    onScriptComplete context, evt, completeback
                    return

        exports.load = load
        exports.getScript = getScript = (src)->
            scripts = head.getElementsByTagName 'script'
            a = document.createElement 'a'
            a.setAttribute 'href', src
            for script in scripts
                if script.src is a.href
                    found = script
                    break
            a = null

            return found
        exports.loadScript = loadScript = (src, attributes, callback, errback, completeback)->
            if getScript src
                # console.log 'script already loaded', src
                callback() if typeof callback is 'function'
                completeback() if typeof completeback is 'function'
                return

            attributes = extend
                tag: 'script'
                type: 'text/javascript'
                src: src
            , attributes
            load attributes, callback, errback, completeback
            return

        # exports.shim = shim = (name, options)->
        #     if typeof define is 'function' and define.amd
        #         config =
        #             path: {}
        #             shim: {}

        #         config.path[name] = options.paths
        #         config.shim[name] = options.shim

        #         requirejs.config config

        #     return

    browserExtend exports
    return exports
