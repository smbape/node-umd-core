/*
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
 */

import _ from "%{amd: 'lodash', brunch: '!_', common: 'lodash', node: 'lodash'}";
import Backbone from "%{amd: 'backbone', brunch: '!Backbone', common: 'backbone', node: 'backbone'}";
import i18n from "%{amd: 'i18next', brunch: '!i18next', common: 'i18next', node: 'i18next'}";
import BaseRouter from "./BaseRouter";
import RouterEngine from "./RouterEngine";
import resources from "./resources";

const {hasOwnProperty: hasProp} = Object.prototype;

const intComparator = function(a, b) {
    a = parseInt(a, 10);
    b = parseInt(b, 10);
    return a > b ? 1 : a < b ? -1 : 0;
};

const choiceHandler = function(key, value, options) {
    if (!hasProp.call(options, "choice") || "number" !== typeof options.choice || !hasProp.call(value, "choice") || "object" !== typeof value.choice) {
        // eslint-disable-next-line no-invalid-this
        return `key '${ this.ns[0] }:${ key } (${ this.lng })' returned an object instead of string.`;
    }

    const keys = Object.keys(value.choice).sort(intComparator);
    let choice = keys[0];
    const actual = options.choice;

    keys.forEach((num, i) => {
        num = parseInt(num, 10);
        if (actual >= num) {
            choice = keys[i];
        }
    });

    return i18n.t(`${ key }.choice.${ choice }`, options);
};

const i18nOptions = {
    lng: "en-GB",
    interpolation: {
        prefix: "{{",
        suffix: "}}",
        escapeValue: false,
        unescapeSuffix: "HTML"
    },
    returnedObjectHandler: choiceHandler
};

i18nOptions.resources = "function" === typeof resources ? resources(i18nOptions) : resources;

const i18nMixin = {
    updateResources(newResources) {
        if ("function" === typeof newResources) {
            newResources = newResources(i18nOptions);
        }

        if (_.isObject(newResources)) {
            for (const lng in newResources) {
                if (!hasProp.call(newResources, lng)) {
                    continue;
                }

                if (_.isObject(newResources[lng])) {
                    const ref = newResources[lng];
                    for (const nsp in ref) {
                        if (!hasProp.call(ref, nsp)) {
                            continue;
                        }

                        i18n.addResourceBundle(lng, nsp, newResources[lng][nsp], true, true);
                    }
                }
            }
        }

        return i18nOptions;
    },

    getLocales() {
        return {
            en: "en-GB",
            fr: "fr-FR"
        };
    },

    getLocale(language) {
        return this.getLocales()[language];
    },

    changeLanguage(language) {
        const locales = this.getLocales();

        if (hasProp.call(locales, language)) {
            if (locales[language] === i18n.language) {
                return;
            }
        } else {
            return;
        }

        i18n.changeLanguage(locales[language]);
        this.set("language", language);

        const {location, pathParams} = this.router.current;

        if (hasProp.call(pathParams, "language")) {
            pathParams.language = language;
            const url = this.router.current.engine.getUrl(pathParams) + location.search + location.hash;
            Backbone.history.navigate(url, {
                trigger: true,
                replace: true
            });
        }
    }
};

module.exports = function(options, done) {
    // eslint-disable-next-line no-invalid-this
    const app = this;

    Object.assign(app, i18nMixin);

    if (options && options.i18n) {
        Object.assign(i18nOptions, options.i18n);

        if (options.i18n.router === true) {
            const titleSuffix = document.title;
            app.router.onRouteChangeSuccess = function(rendable, current) {
                const title = this.getRendableTitle(rendable);

                if (title) {
                    document.title = `${ i18n.t(title) } - ${ titleSuffix }`;
                }

                if ("function" === typeof options.onRouteChangeSuccess) {
                    options.onRouteChangeSuccess();
                }
            };
        }
    }

    app.router.on("routeChangeSuccess", (rendable, handlerOptions) => {
        const {pathParams} = handlerOptions;

        if (pathParams && pathParams.language) {
            handlerOptions.app.set("language", pathParams.language);
        }
    });

    if (BaseRouter.isRouter(app.router)) {
        const language = function() {
            return app.get("language") || (navigator.browserLanguage || navigator.language).slice(0, 2);
        };

        const engines = app.router.engines;

        // eslint-disable-next-line guard-for-in
        for (const route in engines) {
            const engine = engines[route].engine;

            if (engine instanceof RouterEngine) {
                const variables = engine.getVariables();
                if (variables.indexOf("language") !== -1) {
                    engine.defaults.language = language;
                }
            }
        }
    }

    const location = app.getLocation();
    const routeInfo = app.router.getRouteInfo(location, {
        partial: true
    });

    let pathParams;
    if (routeInfo) {
        [, pathParams] = routeInfo;
    }

    let language = (pathParams && pathParams.language) || (navigator.browserLanguage || navigator.language).slice(0, 2);
    const locales = app.getLocales();

    if (!hasProp.call(locales, language)) {
        language = "en";
    }

    app.set("language", language);
    i18nOptions.lng = locales[language];
    i18n.init(i18nOptions, done);
};
