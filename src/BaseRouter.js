import $ from "%{amd: 'jquery', brunch: '!jQuery', common: 'jquery'}";
import _ from "%{amd: 'lodash', brunch: '!_', common: 'lodash', node: 'lodash'}";
import Backbone from "%{amd: 'backbone', brunch: '!Backbone', common: 'backbone', node: 'backbone'}";
import inherits from "./functions/inherits";
import RouterEngine from "./RouterEngine";
import qs from "./QueryString";
import eachOfLimit from "./functions/eachOfLimit";
import isEqual from "../lib/fast-deep-equal";

const { pick } = _;

const WAIT_TIME = 1000;
const hasProp = Object.prototype.hasOwnProperty;

const CACHE_STRATEGIES = {
    location: arg => {
        return JSON.stringify(arg.location);
    },

    pathname: arg => {
        return arg.location.pathname;
    },

    url: arg => {
        return arg.url;
    },

    variables: arg => {
        const {pathParams, engine} = arg;

        if (pathParams && engine) {
            return JSON.stringify(pick(pathParams, engine.getVariables()));
        }

        return null;
    }
};

const makeError = (msg, code) => {
    const err = new Error(msg);
    err.code = code;
    return err;
};

function BaseRouter(options) {
    options = Object.assign({}, options);

    for (const opt in options) {
        if (!hasProp.call(options, opt)) {
            continue;
        }

        if (opt.charAt(0) !== "_" && opt in this) {
            this[opt] = options[opt];
        }
    }

    Object.assign(options, pick(this, ["app", "routes", "otherwise"]));

    BaseRouter.__super__.constructor.call(this, {
        routes: {
            "*url": "dispatch"
        }
    });

    if (!options.app) {
        throw new Error("app property is undefined");
    }

    this.current = {};
    this._initRoutes(options);
    this.container = options.container || document.body;
}

inherits(BaseRouter, Backbone.Router);

Object.assign(BaseRouter.prototype, {
    app: null,
    routes: null,
    otherwise: null,
    getCacheId: CACHE_STRATEGIES.variables,

    navigate(fragment, options) {
        if (options == null) {
            options = {};
        }

        let location = this.app.getLocation(fragment);
        const ch = location.pathname[0];

        if (ch === "/" || ch === "#") {
            location.pathname = location.pathname.substring(1);
        }

        if (this.current.location && location.pathname === this.current.location.pathname && location.search === this.current.location.search) {
            if (options.force) {
                Backbone.history.loadUrl(location.pathname + location.search);
                return undefined;
            }

            location = this.app.getLocation(fragment);
            this.app.setLocationHash(location.hash);
            return undefined;
        }

        return BaseRouter.__super__.navigate.apply(this, arguments);
    },

    getCurrentUrl() {
        const location = this.app.getLocation();

        if (location) {
            return location.pathname + location.search + location.hash;
        }

        return null;
    },

    refresh() {
        const url = this.getCurrentUrl();
        if (url) {
            Backbone.history.loadUrl(url);
        }
    },

    dispatch(url, options, callback) {
        let otherwise = false;

        if (url === null || url === "blank") {
            if (this._otherwise) {
                this.navigate(this._otherwise);
                return;
            } else if (this.otherwise) {
                url = "";
                otherwise = true;
            } else {
                throw new Error(`unmatched route for ${ url }`);
            }
        }

        if (typeof options === "string") {
            url += `?${ options }`;
            options = {};
        } else if (options == null || typeof options !== "object") {
            options = {};
        }

        const app = this.app;
        const location = options.location || app.getLocation(url);
        url = location.pathname + location.search;

        if (!app.hasPushState && document.getElementById(url)) {
            // scroll into view has already been done
            return;
        }

        let container;
        if (hasProp.call(options, "container")) {
            container = options.container;
        }

        const mainContainer = this.container;

        if (!container) {
            container = mainContainer;
        }

        if (!container) {
            if ("function" === typeof callback) {
                callback();
            }
            return;
        }

        this._dispatch({
            container,
            location,
            url,
            otherwise
        }, options, callback);
    },


    getRouteInfo(location, options) {
        options = Object.assign({}, options, {
            throws: false
        });

        const {engines} = this;
        let pathParams, routeConfig, engine, handlers;

        for (const route in engines) { // eslint-disable-line guard-for-in
            routeConfig = engines[route];
            engine = routeConfig.engine;
            handlers = routeConfig.handlers;

            try {
                pathParams = engine.getParams(location.pathname, options);
                if (pathParams) {
                    break;
                }
            } catch ( error ) {
                // route failed
            }
        }

        if (pathParams) {
            return [engine, pathParams, handlers];
        }

        return null;
    },

    clearContainer(container) {
        const prevRendable = $.data(container, "rendable");
        if (prevRendable) {
            prevRendable.destroy();
            $.removeData(container, "rendable");
        }
    },

    _dispatch(copts, options, done) {
        const app = this.app;
        const router = this;

        if (app.$$busy) {
            // changing is too fast
            // wait 100 ms and retry
            clearTimeout(this._waiting);
            this._waiting = setTimeout(() => {
                this._dispatch(copts, options, done);
            }, 100);
            return;
        }

        const {container, location, url, otherwise} = copts;
        const queryParams = qs.parse(location.search);

        let engine, pathParams, handlers, routeInfo;

        if (otherwise) {
            handlers = [this.otherwise];
        } else if (routeInfo = this.getRouteInfo(location)) { // eslint-disable-line no-cond-assign
            [engine, pathParams, handlers] = routeInfo;
        } else if (this.otherwise) {
            handlers = [this.otherwise];
        } else {
            throw new Error(`unmatched route for ${ location.pathname }`);
        }

        this.clearContainer(container);

        $(container).empty();

        const handlerOptions = {
            container,
            location,
            url,
            pathParams,
            queryParams,
            params: Object.assign({}, pathParams, queryParams),
            engine,
            router,
            app
        };

        const callback = (err, res) => {
            if (callback.called) {
                return;
            }

            callback.called = true;
            app.give();

            app.current = router.current = handlerOptions; // eslint-disable-line no-multi-assign

            let rendable;
            if (res != null && typeof res === "object" && "function" === typeof res.destroy) {
                rendable = res;
            }

            const onError = err => {
                if (rendable) {
                    rendable.destroy();
                }
                console.error(err, err.stack);
                router.onRouteChangeFailure(err, handlerOptions);
                router.emit("routeChangeFailure", err, options);
                app.emit("routeChangeFailure", router, err, options);
            };

            if (err) {
                onError(err);
            } else {
                if (rendable) {
                    $.data(container, "rendable", rendable);
                }

                container.scrollTop = 0;

                try {
                    app.setLocationHash();
                    router.onRouteChangeSuccess(res, handlerOptions, options);
                    router.emit("routeChangeSuccess", res, handlerOptions, options);
                    app.emit("routeChangeSuccess", router, res, handlerOptions, options);
                    if (router.container === container) {
                        app.set("navigation", handlerOptions);
                    }
                } catch ( err ) {
                    onError(err);
                }
            }

            router.afterDispatch(err, res, handlerOptions);

            if ("function" === typeof done) {
                done(err, res);
            }
        };

        let cacheId;
        if ("function" === typeof router.getCacheId) {
            cacheId = router.getCacheId(handlerOptions);
            if (cacheId && hasProp.call(router.routeCache, cacheId)) {
                router.executeHandler(router.routeCache[cacheId], handlerOptions, callback);
                return;
            }
        }

        router.beforeDispatch(handlerOptions);
        app.take();

        let res;
        const last = handlers.length - 1;

        eachOfLimit(handlers, 1, (handler, i, next) => {
            router.executeHandler(handler, handlerOptions, (err, _res) => {
                res = _res;

                if (!err) {
                    if (cacheId) {
                        router.routeCache[cacheId] = handler;
                    }
                    next(1);
                    return;
                }

                if (!(err instanceof Error) // Error that are not instance of Error are not module not found errors
                    || (((err.code) !== "CONTROLLER_HANDLER" && err.code !== "VIEW_HANDLER" && err.code !== "TEMPLATE_HANDLER") // Invalid handler
                    && !/^(?:Cannot find module|Script error for) /.test(err.message)) // CommonJs/RequireJs module not found error
                ) {
                    next(err);
                    return;
                }

                if (typeof err === "object") {
                    console.error(err, err.stack);
                }

                next(last === i ? err : null);
            });
        }, err => {
            callback(err === 1 ? null : err, res);
        });
    },

    executeHandler(handler, handlerOptions, done) {
        const timeout = setTimeout(() => {
            console.log("taking too long to handle. Make sure you called done function");
        }, WAIT_TIME);

        try {
            handler.call(this, handlerOptions, (err, res) => {
                clearTimeout(timeout);
                done(err, res);
            });
        } catch ( err ) {
            clearTimeout(timeout);
            done(err);
        }
    },

    // eslint-disable-next-line no-empty-function
    onRouteChangeSuccess(rendable, options) {},

    onRouteChangeFailure(err, handlerOptions) {
        const {container} = handlerOptions;
        container.innerHTML = err;
    },

    engine(name) {
        const route = this.routeByName[name];
        return route != null ? route.engine : undefined;
    },

    back() {
        window.history.back();
    },

    forward() {
        window.history.forward();
    },

    // eslint-disable-next-line no-empty-function
    beforeDispatch(options) {},

    // eslint-disable-next-line no-empty-function
    afterDispatch(err, rendable, options) {},

    isMainContainer(container) {
        return container === this.container;
    },

    _extractParameters(route, fragment) {
        // return fragment as is
        // parsing is done in dispatch
        return [fragment || null];
    },

    _initRoutes(opts) {
        const {app} = opts;
        let {otherwise, routes} = opts;

        this.app = app;

        if ("function" === typeof routes) {
            routes = routes.call(this);
        }

        if ("string" === typeof otherwise) {
            const router = this;
            const location = app.getLocation(otherwise);
            this._otherwise = otherwise;

            otherwise = ((otherwise2, location2, router2, app2) => {
                return (options, callback) => {
                    if (isEqual(location2, app2.getLocation(options.url))) {
                        throw new Error(`unmatched route for ${ otherwise2 }`);
                    }

                    router2.navigate(otherwise);
                    callback();
                };
            })(otherwise, location, router, app);
        }

        if ("function" === typeof otherwise) {
            this.otherwise = otherwise;
        }

        this.routeCache = {};
        const engines = this.engines = {}; // eslint-disable-line no-multi-assign
        const routeByName = this.routeByName = {}; // eslint-disable-line no-multi-assign
        const handlerByName = this.handlerByName = {}; // eslint-disable-line no-multi-assign
        const baseUrl = app.get("baseUrl");

        for (const route in routes) {
            if (!hasProp.call(routes, route)) {
                continue;
            }

            const config = routes[route];
            const options = pick(config, RouterEngine.prototype.validOptions);

            options.baseUrl = baseUrl;
            options.route = route;

            const routeConfig = engines[route] = { // eslint-disable-line no-multi-assign
                engine: new RouterEngine(options)
            };

            if ("string" === typeof config.name) {
                if (hasProp.call(routeByName, config.name)) {
                    throw new Error(`Error in route '${ route }', duplicate route name '${ config.name }'`);
                }
                routeByName[config.name] = routeConfig;
            }

            if (!Array.isArray(config.handlers)) {
                throw new Error(`Error in route '${ route }': handlers options must an Array`);
            }

            const handlers = routeConfig.handlers = []; // eslint-disable-line no-multi-assign

            config.handlers.forEach((handler, index) => {
                let fn;

                switch (handler.type) {
                    case "controller":
                        fn = this._controllerHandler(handler, routeConfig);
                        break;
                    case "view":
                        fn = this._viewHandler(handler, routeConfig);
                        break;
                    case "template":
                        fn = this._templateHandler(handler, routeConfig);
                        break;
                    default:
                        if ("function" !== typeof handler.fn) {
                            throw new Error(`Error in route '${ route }', handler '${ handler.name }': unknown type '${ handler.type }' or no fn 'function'`);
                        }
                        fn = handler.fn;
                }

                handlers.push(fn);

                if ("string" === typeof handler.name) {
                    if (hasProp.call(handlerByName, handler.name)) {
                        throw new Error(`Error in route '${ route }', handler ${ index }: duplicate handler name '${ handler.name }'`);
                    }
                    handlerByName[handler.name] = fn;
                }
            });
        }
    },

    _controllerHandler(handler, routeConfig) {
        const router = this;
        const engine = new RouterEngine(handler);

        return (options, callback) => {
            const {pathParams} = options;
            const path = engine.getFilePath(pathParams);

            require([path], Controller => {
                if ("function" !== typeof Controller) {
                    callback(makeError(`Invalid Controller at ${ path }: not a function`, "CONTROLLER_HANDLER"));
                    return;
                }

                if ("function" !== typeof Controller.prototype.getMethod) {
                    callback(makeError(`Invalid method 'getMethod'. Controller.prototype.getMethod is not a function (${ path })`, "CONTROLLER_HANDLER"));
                    return;
                }

                const method = Controller.prototype.getMethod(options);
                if ("function" !== typeof Controller.prototype[method]) {
                    callback(makeError(`Invalid method '${ method }'. Controller.prototype.${ method } is not a function (${ path })`, "CONTROLLER_HANDLER"));
                    return;
                }

                if (options.checkOnly) {
                    callback(null, Controller);
                    return;
                }

                const controller = new Controller(Object.assign({}, options, {
                    router
                }));

                if ("function" !== typeof controller[method]) {
                    callback(makeError(`Invalid method '${ method }'. controller.${ method } is not a function (${ path })`, "CONTROLLER_HANDLER"));
                    return;
                }

                if (controller[method].length === 1) {
                    const timeout = setTimeout(() => {
                        console.log("taking too long to render. Make sure you called done function");
                    }, WAIT_TIME);

                    try {
                        controller[method](err => {
                            clearTimeout(timeout);
                            callback(err, controller);
                        });
                    } catch ( err ) {
                        clearTimeout(timeout);
                        callback(err, controller);
                    }
                } else {
                    let err;

                    try {
                        controller[method]();
                    } catch ( error ) {
                        err = error;
                    }

                    callback(err, controller);
                }
            }, callback);
        };
    },

    _viewHandler(handler, routeConfig) {
        const router = this;
        const engine = new RouterEngine(handler);

        return (options, callback) => {
            const {pathParams} = options;
            const path = engine.getFilePath(pathParams);

            require([path], View => {
                if ("function" !== typeof View) {
                    callback(makeError(`Invalid View at ${ path }`, "VIEW_HANDLER"));
                    return;
                }

                if (options.checkOnly) {
                    callback(null, View);
                    return;
                }

                options = Object.assign({}, options, {
                    router
                });

                let view;
                if ("function" === typeof View.createElement) {
                    view = View.createElement(options);
                } else {
                    view = new View(options);
                }

                if ("function" !== typeof view.render || view.render.length > 1) {
                    callback(makeError(`view at ${ path }: Invalid render method. It should be a function expectingat most ine argument`, "VIEW_HANDLER"));
                    return;
                }
                if (view.render.length === 1) {
                    const timeout = setTimeout(() => {
                        console.log("taking too long to render. Make sure you called done function");
                    }, WAIT_TIME);

                    try {
                        view.render(err => {
                            clearTimeout(timeout);
                            callback(err, view);
                        });
                    } catch ( err ) {
                        clearTimeout(timeout);
                        callback(err, view);
                    }
                } else {
                    let err;

                    try {
                        view.render();
                    } catch ( error ) {
                        err = error;
                    }

                    callback(err, view);
                }
            }, callback);
        };
    },

    _templateHandler(handler, routeConfig) {
        const engine = new RouterEngine(handler);

        return (options, callback) => {
            const {pathParams} = options;
            const path = engine.getFilePath(pathParams);

            require([path], template => {
                let html;

                switch (typeof template) {
                    case "function":
                        html = template(options);
                        break;
                    case "string":
                        html = template;
                        break;
                    default:
                        callback(makeError(`Invalid template at ${ path }`, "TEMPLATE_HANDLER"));
                        return;
                }

                $(options.container).html(html);
                callback();
            }, callback);
        };
    },

});

BaseRouter.prototype.emit = BaseRouter.prototype.trigger;

BaseRouter.isRouter = obj => {
    return !Object.keys(BaseRouter.prototype).some(key => {
        return !(key in obj);
    });
};

module.exports = BaseRouter;
