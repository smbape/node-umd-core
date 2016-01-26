deps = [
    'umd-core/src/common'
    {amd: 'i18next', common: '!i18next'}
    'umd-core/src/BasicRouter'
    'umd-core/src/RouterEngine'
    './resources'
]

factory = ({_, Backbone}, i18n, BasicRouter, RouterEngine, resources)->
    hasOwn = {}.hasOwnProperty

    # Add choice handler
    ###
    // !!!!!!!!!!!!! be in english before 
    (function(app, i18n) {
        'use strict';

        app.updateResources({
            'en-GB': {
                translation: {
                    'girls-and-boys': {
                        choice: {
                            0: '$t(girls, {"choice": __girls__}) and no boys',
                            1: '$t(girls, {"choice": __girls__}) and a boy',
                            2: '$t(girls, {"choice": __girls__}) and __choice__ boys'
                        }
                    },
                    girls: {
                        choice: {
                            0: 'No girls',
                            1: '__choice__ girl',
                            2: '__choice__ girls',
                            6: 'More than 5 girls'
                        }
                    }
                }
            }
        });

        console.log(i18n.t('girls-and-boys', {choice: 2, girls: 3})); // -> 3 girls and 2 boys
        console.log(i18n.t('girls-and-boys', {choice: 7, girls: 0})); // -> No girls and 7 boys
        console.log(i18n.t('girls-and-boys', {choice: 0, girls: 0})); // -> No girls and no boys
        console.log(i18n.t('girls-and-boys', {choice: 0, girls: 1})); // -> 1 girl and no boys
        console.log(i18n.t('girls-and-boys', {choice: 1, girls: 0})); // -> No girls and a boy
        console.log(i18n.t('girls-and-boys', {choice: 2, girls: 7})); // -> More than 5 girls and 2 boys

    }(require('application'), require('i18next')));
    ###

    # ================================
    # Internationalization
    # ================================
    i18nOptions =
        lng: 'en-GB'
        resources: resources
        interpolation: 
            prefix: '__'
            suffix: '__'
            escapeValue: false
            unescapeSuffix: 'HTML'
        returnedObjectHandler: (key, value, options)->
            if not hasOwn.call(options, 'choice') or 'number' isnt typeof options.choice or not hasOwn.call(value, 'choice') or 'object' isnt typeof value.choice
                return "key '#{@ns[0]}:#{key} (#{@lng})' returned an object instead of string."

            keys = Object.keys value.choice
            choice = keys[0]
            value = options.choice
            for num in keys
                if value >= num
                    choice = num

            i18n.t "#{key}.choice.#{choice}", options

    i18nMixin =

        updateResources: (resources)->
            if _.isPlainObject resources
                for lng of resources
                    if _.isPlainObject resources[lng]
                        for nsp of resources[lng]
                            i18n.addResourceBundle lng, nsp, resources[lng][nsp], true, true
            return

        getLocales: ->
            'en': 'en-GB'
            'fr': 'fr-FR'
        
        getFlags: ->
            'en': 'gb'
            'fr': 'fr'

        getLocale: (language)->
            @getLocales()[language]

        # http://i18next.com/docs/api/
        changeLanguage: (language)->
            locales = @getLocales()

            if hasOwn.call locales, language
                return if locales[language] is i18n.language
            else
                return

            i18n.changeLanguage locales[language]
            @set 'language', language

            {location, pathParams} = @router.current
            if hasOwn.call pathParams, 'language'
                pathParams.language = language
                url = @router.current.engine.getUrl(pathParams) + location.search + location.hash
                Backbone.history.navigate url, trigger: true, replace: true

            return

    internationalize = (options, done)->
        app = @
        _.extend app, i18nMixin

        if false isnt options?.i18n?.router
            app.router.on 'routeChangeSuccess', (router, res, current)->
                if res
                    title = _.result(res, 'title')
                    if not title and 'function' is typeof res?.get
                        title = res.get('title')
                    if title
                        document.title = i18n.t title

                # publicly notify render
                appConfig.render() if 'function' is typeof appConfig.render
                return

        if app.router instanceof BasicRouter
            language = -> app.get('language')
            for route, {engine} of app.router.engines
                if engine instanceof RouterEngine
                    variables = engine.getVariables()
                    if ~variables.indexOf 'language'
                        engine.defaults.language = language

        location = app.getLocation()
        routeInfo = app.router.getRouteInfo location
        if routeInfo
            [engine, pathParams] = routeInfo

        language = pathParams?.language or (navigator.browserLanguage or navigator.language).slice(0, 2)

        locales = app.getLocales()

        if not hasOwn.call locales, language
            language = 'en'

        app.set 'language', language

        i18nOptions.lng = locales[language]

        i18n.init i18nOptions, done

        return
