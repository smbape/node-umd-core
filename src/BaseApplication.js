/* globals Modernizr */

import $ from "%{amd: 'jquery', brunch: '!jQuery', common: 'jquery'}";
import Backbone from "%{amd: 'backbone', brunch: '!Backbone', common: 'backbone', node: 'backbone'}";
import inherits from "./functions/inherits";
import eachOfLimit from "./functions/eachOfLimit";
import "./extensions";

const PATH_SPLIT_REG = /^([^?#]*)(\?[^#]*)?(#.*)?$/;

// '#url?query!anchor'
const HASH_SPLIT_REG = /^([^?!]*)(\?[^!]*)?(!.*)?$/;

function BaseApplication() {
    this.tasks = [];
    BaseApplication.__super__.constructor.apply(this, arguments);
}

inherits(BaseApplication, Backbone.Model);

Object.assign(BaseApplication.prototype, {
    take() {
        if (this.$$busy) {
            throw new Error("application is busy");
        }
        this.$$busy = true;
    },

    give() {
        this.$$busy = false;
    },

    initialize() {
        this.addInitializer(options => {
            if (options.baseUrl) {
                this.set("baseUrl", options.baseUrl);
                this.hasPushState = Modernizr.history;
            } else {
                this.set("baseUrl", "#");
                this.hasPushState = false;
            }

            this.set("build", options.build);

            if (this.hasPushState) {
                this.getLocation = this._getPathLocation;
                this._setLocationHash = this._setNativeLocationHash;
                this.getWindowHash = this._getWindowNativeHash;
                this.hashChar = "#";
            } else {
                this.getLocation = this._getHashLocation;
                this._setLocationHash = this._setBangLocationHash;
                this.getWindowHash = this._getWindowBangHash;
                this.hashChar = "!";
            }
        });

        this.addInitializer(options => {
            // IE special task
            if (typeof document.documentMode === "undefined") {
                return;
            }

            // Add IE-MODE-xx to body. For css
            if (typeof document.body.className === "string" && document.body.className.length > 0) {
                document.body.className += " ";
            }

            document.body.className += `IE-MODE-${ document.documentMode }`;
        });

        this.addInitializer(this.initRouter);
        this.once("start", this._initHistory, this);
        this.init();
    },

    _initHistory(options) {
        let location = this._getHashLocation();

        if (this.hasPushState) {
            // /context/.../#pathname?query!anchor -> /context/pathname?query#anchor
            const routeInfo = this.router.getRouteInfo(location);

            if (routeInfo) {
                // const [engine, pathParams] = routeInfo;
                window.history.replaceState({}, document.title, `${ options.baseUrl + location.pathname + location.search }#${ location.hash.slice(1) }`);
            } else {
                location.pathname = "";
            }
        } else if (!this.router.getRouteInfo(location)) {
            // use route from pathname with partial match
            // preserve hash
            // /context/pathname?query#anchor -> /context/#pathname?query!anchor
            const url = `${ options.baseUrl }#${ location.pathname }${ location.search }${ location.hash }`;
            if (url !== window.location.href) {
                window.location.href = url;
            }
        }

        this._listenHrefClick(options);

        const app = this;

        Backbone.history.checkUrl = (function(e) {
            let current = this.getFragment();

            // If the user pressed the back button, the iframe's hash will have
            // changed and we should use that for comparison.
            if (current === this.fragment && this.iframe) {
                current = this.getHash(this.iframe.contentWindow);
            }

            if (current === this.fragment) {
                app.setLocationHash(app.getLocation().hash);
                return false;
            }

            if (this.iframe) {
                this.navigate(current);
            }

            this.loadUrl();
            return undefined;
        }).bind(Backbone.history);

        Backbone.history.start({
            pushState: this.hasPushState,
            silent: true
        });

        if (location.pathname === "") {
            location = window.location;
        }

        Backbone.history.loadUrl(location.pathname + location.search);
    },

    // eslint-disable-next-line no-empty-function
    init() {},

    start(config, done) {
        this.config = config;

        eachOfLimit(this.tasks, 1, (task, i, next) => {
            if (task.length < 2) {
                task.call(this, config);
                next();
            } else {
                task.call(this, config, next);
            }
        }, err => {
            if (!this.router) {
                throw new Error("a router must be defined");
            }

            this.emit("start", config);
            if ("function" === typeof done) {
                done();
            }
        });
    },

    addInitializer(fn) {
        if ("function" === typeof fn) {
            if (fn.length > 2) {
                throw new Error("Initializer function must be a function waiting for 2 arguments a most");
            }

            this.tasks.push(fn);
        }
    },

    initRouter(options) {
        throw new Error("a router must be defined");
    },

    setLocationHash(hash) {
        const type = typeof hash;

        if ("undefined" === type) {
            hash = this.getLocation().hash;
        } else if ("string" !== type) {
            return false;
        }

        this._setLocationHash(hash);
        return true;
    },

    _getPathLocation(url) {
        if (!url) {
            return {
                pathname: window.location.pathname,
                search: window.location.search,
                hash: window.location.hash
            };
        }

        const split = PATH_SPLIT_REG.exec(url);
        if (split) {
            return {
                pathname: split[1] || "",
                search: split[2] || "",
                hash: split[3] || ""
            };
        }

        return {
            pathname: "",
            search: "",
            hash: ""
        };
    },

    _getHashLocation(url) {
        if (!url) {
            url = window.location.hash.slice(1);
        }

        const split = HASH_SPLIT_REG.exec(url);

        if (!split) {
            return {
                pathname: "",
                search: "",
                hash: ""
            };
        }

        return {
            pathname: split[1] || "",
            search: split[2] || "",
            hash: split[3] || ""
        };
    },

    _setNativeLocationHash(hash) {
        const location = window.location;

        if (!hash) {
            if (location.href !== (`${ location.protocol }//${ location.host }${ location.pathname }${ location.search }`)) {
                window.history.pushState({}, document.title, location.pathname + location.search);
            }
            return;
        }

        const windowHash = this._getWindowNativeHash(hash);
        hash = hash.slice(1);

        if (window.location.hash === windowHash) {
            let element = document.getElementById(hash);
            if (!element) {
                element = $(`[name=${ hash.replace(/([^\w-])/g, "\\$1") }]`)[0];

                if (element) {
                    element.scrollIntoView();
                }
            }
        } else {
            window.location.hash = windowHash;
        }
    },

    _getWindowNativeHash(hash) {
        return hash ? `#${ hash.slice(1) }` : window.location.hash;
    },

    _setBangLocationHash(hash) {
        const windowHash = this._getWindowBangHash(hash);
        window.location.hash = windowHash;

        if (hash) {
            hash = hash.slice(1);
            let element = document.getElementById(hash);

            if (!element) {
                element = $(`[name=${ hash.replace(/([^\w-])/g, "\\$1") }]`)[0];
            }

            if (element) {
                element.scrollIntoView();
            }
        }
    },

    _getWindowBangHash(hash) {
        const location = this._getHashLocation();

        if (!hash) {
            return `#${ location.pathname }${ location.search }`;
        }

        hash = hash.slice(1);
        location.hash = `!${ hash }`;

        return `#${ location.pathname }${ location.search }${ location.hash }`;
    },

    _listenHrefClick(options) {
        const app = this;
        const $document = $(document.body);

        $document.on("click", "a[href]", function(evt) {
            // Allow prevent default
            if (evt.isDefaultPrevented()) {
                return;
            }

            // Only trigger router on left click with no fancy stuff
            // allowing open in new tab|window shortcut
            const which = evt.which;
            if (which !== 1 || evt.altKey || evt.ctrlKey || evt.shiftKey) {
                return;
            }

            // Ignore elements that have no-navigate class
            // eslint-disable-next-line no-invalid-this
            if (/(?:^|\s)no-navigate(?:\s|$)/.test(this.className)) {
                return;
            }

            // Only cares about non anchor click
            // eslint-disable-next-line no-invalid-this
            let href = this.getAttribute("href");
            const _char = href.charAt(0);
            if (_char === "!") {
                evt.preventDefault();
                app.setLocationHash(href);
                return;
            }

            if (_char === "#") {
                if (app.hasPushState) {
                    evt.preventDefault();
                    app.setLocationHash(href);
                    return;
                }

                const hash = href.slice(1);
                if (hash) {
                    let element = document.getElementById(hash);
                    if (!element) {
                        element = $(`[name=${ hash.replace(/([^\w-])/g, "\\$1") }]`)[0];
                    }

                    if (element) {
                        evt.preventDefault();
                        app.setLocationHash(href);
                        return;
                    }
                }
            }

            // Get the absolute base url
            const baseUrl = `${ window.location.protocol }//${ window.location.host }${ options.baseUrl }`;

            // only care about paths relative to baseUrl
            // eslint-disable-next-line no-invalid-this
            if (this.href.slice(0, baseUrl.length) !== baseUrl) {
                return;
            }

            if (href.slice(0, baseUrl.length) === baseUrl) {
                href = href.slice(baseUrl.length);
            }

            // Stop the default event to ensure that the link will not cause a page refresh.
            evt.preventDefault();

            // Ignore trigger router for irrelevant click
            if (href === "#" || href === "") {
                return;
            }

            // `Backbone.history.navigate` is sufficient for all Routers and will
            // trigger the correct events. The Router's internal `navigate` method
            // calls this anyways. The fragment is sliced from the base url.
            app.router.navigate(href, {
                trigger: true,
                replace: false
            }, evt);
        });
    }
});

BaseApplication.prototype.emit = BaseApplication.prototype.trigger;

module.exports = BaseApplication;
