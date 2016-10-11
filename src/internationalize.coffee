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
                            0: '$t(girls, { "choice": {{girls}} }) and no boys',
                            1: '$t(girls, { "choice": {{girls}} }) and a boy',
                            2: '$t(girls, { "choice": {{girls}} }) and {{choice}} boys'
                        }
                    },
                    girls: {
                        choice: {
                            0: 'No girls',
                            1: 'a girl',
                            2: '{{choice}} girls',
                            6: 'More than 5 girls'
                        }
                    }
                }
            }
        });

        assertStrictEqual(i18n.t('girls', {choice: 0}), 'No girls');
        assertStrictEqual(i18n.t('girls', {choice: 1}), 'a girl');
        assertStrictEqual(i18n.t('girls', {choice: 2}), '2 girls');
        assertStrictEqual(i18n.t('girls', {choice: 3}), '3 girls');
        assertStrictEqual(i18n.t('girls', {choice: 4}), '4 girls');
        assertStrictEqual(i18n.t('girls', {choice: 5}), '5 girls');
        assertStrictEqual(i18n.t('girls', {choice: 6}), 'More than 5 girls');
        assertStrictEqual(i18n.t('girls', {choice: 9}), 'More than 5 girls');

        assertStrictEqual(i18n.t('girls-and-boys', {girls: 0, choice: 0}), 'No girls and no boys');
        assertStrictEqual(i18n.t('girls-and-boys', {girls: 0, choice: 1}), 'No girls and a boy');
        assertStrictEqual(i18n.t('girls-and-boys', {girls: 0, choice: 7}), 'No girls and 7 boys');
        assertStrictEqual(i18n.t('girls-and-boys', {girls: 1, choice: 0}), 'a girl and no boys');
        assertStrictEqual(i18n.t('girls-and-boys', {girls: 3, choice: 2}), '3 girls and 2 boys');
        assertStrictEqual(i18n.t('girls-and-boys', {girls: 7, choice: 2}), 'More than 5 girls and 2 boys');

        function assertStrictEqual(actual, expected) {
            if (actual !== expected) {
                throw new Error('Expecting ' + actual + ' to equal ' + expected);
            }
        }

    }(require('application'), require('i18next')));
    ###

    # ================================
    # Internationalization
    # ================================
    intComparator = (a, b)->
        a = parseInt(a, 10)
        b = parseInt(b, 10)
        if a > b
            return 1

        if a < b
            return -1

        return 0

    i18nOptions =
        lng: 'en-GB'
        interpolation:
            prefix: '{{'
            suffix: '}}'
            escapeValue: false
            unescapeSuffix: 'HTML'
        returnedObjectHandler: (key, value, options)->
            if not hasOwn.call(options, 'choice') or 'number' isnt typeof options.choice or not hasOwn.call(value, 'choice') or 'object' isnt typeof value.choice
                return "key '#{@ns[0]}:#{key} (#{@lng})' returned an object instead of string."

            keys = Object.keys(value.choice).sort(intComparator)
            choice = keys[0]
            value = options.choice
            for num, i in keys
                num = parseInt(num, 10)
                if value >= num
                    choice = keys[i]

            i18n.t "#{key}.choice.#{choice}", options

    if 'function'is typeof resources
        resources = resources(i18nOptions)
    i18nOptions.resources = resources

    i18nMixin =

        updateResources: (resources)->
            if 'function'is typeof resources
                resources = resources(i18nOptions)

            if _.isObject resources
                for own lng of resources
                    if _.isObject resources[lng]
                        for own nsp of resources[lng]
                            i18n.addResourceBundle lng, nsp, resources[lng][nsp], true, true

            return i18nOptions

        getLocales: ->
            'en': 'en-GB'
            'fr': 'fr-FR'

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
        _.extend i18nOptions, options?.i18n

        if options?.i18n?.router is true
            app.router.onRouteChangeSuccess = (rendable, current)->
                if title = @getRendableTitle rendable
                    document.title = i18n.t title

                appConfig.onRouteChangeSuccess() if 'function' is typeof appConfig.onRouteChangeSuccess
                return

        app.router.on 'routeChangeSuccess', (rendable, {app, pathParams}, options)->
            if pathParams?.language
                app.set 'language', pathParams.language
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
