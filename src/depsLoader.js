(function(root, factory) {
    "use strict";
    if (typeof exports !== "undefined") {
        // Node/CommonJS
        module.exports = factory();
    } else if (typeof define === "function" && define.amd) {
        // AMD
        define([], factory);
    } else {
        // global variable
        root.depsLoader = factory();
    }
})(this, function() {
    "use strict";

    var objectToString = Object.prototype.toString;
    var objectTag = "[object Object]";
    var hasProp = Object.prototype.hasOwnProperty;
    var funcToString = Function.prototype.toString;
    var objectCtorString = funcToString.call(Object);

    function isObjectLike(value) {
        return typeof value === "object" && value !== null;
    }

    function isPlainObject(value) {
        if (!isObjectLike(value) || objectToString.call(value) !== objectTag) {
            return false;
        }

        var proto = Object.getPrototypeOf(value);
        if (proto === null) {
            return true;
        }

        var Ctor = hasProp.call(proto, "constructor") && proto.constructor;
        return "function" === typeof Ctor && Ctor instanceof Ctor && funcToString.call(Ctor) === objectCtorString;
    }

    function resolveName(dep) {
        return dep.replace(/(?:(?:\\(.))|(\/\*{1,2})$)/g, function(match, _escape, pack) {
            if (_escape) {
                return _escape;
            }

            if (pack === "/*") {
                return "/package";
            }

            return "/deepack";
        });
    }

    function _processCommonDep(require, type, dep, _global, libs, errors) {
        if (dep == null) {
            libs.push(undefined);
            return;
        }

        var ex;

        switch (dep[0]) {
            case "!":
                // global depency requested
                if (!_global) {
                    throw new Error("global scope is not defined");
                }

                libs.push(_global[dep.slice(1)]);
                break;

            case "$":
                // Ignore dependency. To use with angular as an example
                libs.push(undefined);
                break;

            default:
                dep = resolveName(dep);
                if (errors) {
                    try {
                        libs.push(require(dep));
                    } catch ( error ) {
                        ex = error;
                        if (typeof errback !== "function") {
                            throw ex;
                        }
                        errors.push(ex);
                    }
                } else {
                    libs.push(require(dep));
                }
        }
    }

    function _commonRequireDeps(require, type, deps, _global, libs, errors) {
        deps.forEach(function(dep) {
            var found;

            if (isPlainObject(dep)) {
                if (Array.isArray(type)) {
                    found = null;
                    type.some(function(name) {
                        if (hasProp.call(dep, name)) {
                            found = dep[name];
                            return true;
                        }

                        return false;
                    });
                    dep = found;
                } else {
                    dep = dep[type];
                }
            }

            _processCommonDep(require, type, dep, _global, libs, errors);
        });

        return libs;
    }

    function commonSpecDefine(require, type, deps, factory, _global) {
        if (typeof deps === "undefined") {
            deps = [];
        }

        var localRequire = function(deps, callback, errback, options) {
            return commonSpecRequire(require, type, deps, callback, errback, options, _global);
        };

        var libs = [localRequire];

        _commonRequireDeps(require, type, deps, _global, libs);
        return factory.apply(_global, libs);
    }

    // eslint-disable-next-line consistent-return
    function commonSpecRequire(require, type, deps, callback, errback, options, _global) {
        if (typeof deps === "string") {
            deps = [deps];
        } else if (typeof deps === "undefined") {
            deps = [];
        }

        var libs = [];
        var errors = [];

        _commonRequireDeps(require, type, deps, _global, libs, errors);

        if (errors.length !== 0) {
            return errback.apply(_global, errors);
        }

        if (typeof callback === "function") {
            return callback.apply(_global, libs);
        }

        if (deps.length === 1) {
            return libs[0];
        }
    }

    function _processAmdDep(_global, libs, availables, map, dep, index) {
        if (dep == null) {
            availables[index] = undefined;
            return;
        }

        switch (dep[0]) {
            case "!":
                // global depency requested
                if (!_global) {
                    throw new Error("global scope is not defined");
                }
                availables[index] = _global[dep.slice(1)];
                break;

            case "$":
                // Ignore dependency. To use with angular as an example
                availables[index] = undefined;
                break;

            default:
                map[libs.length] = index;
                dep = resolveName(dep);
                libs.push(dep);
        }
    }

    function amdDefine(name, deps, factory, _global) {
        if (arguments.length === 3) {
            _global = factory;
            factory = deps;
            deps = name;
            name = null;
        }

        if (typeof deps === "undefined") {
            deps = [];
        }

        var libs = ["require"];
        var availables = [];
        var map = {};

        deps.forEach(function(dependency, index) {
            if (typeof dependency === "string") {
                _processAmdDep(_global, libs, availables, map, dependency, index + 1);
            } else if (isPlainObject(dependency)) {
                _processAmdDep(_global, libs, availables, map, dependency.amd, index + 1);
            }
        });

        var callback = function(require) {
            for (var i = 1, len = arguments.length; i < len; i++) {
                availables[map[i]] = arguments[i];
            }

            var localRequire = function(deps, callback, errback, options) {
                return amdRequire(require, deps, callback, errback, options, _global);
            };

            availables[0] = localRequire;
            return factory.apply(_global, availables);
        };

        if (name) {
            return define(name, libs, callback);
        }

        return define(libs, callback);
    }

    // eslint-disable-next-line consistent-return
    function amdRequire(require, deps, callback, errback, options, _global) {
        if (typeof deps === "string") {
            deps = [deps];
        } else if (typeof deps === "undefined") {
            deps = [];
        }

        var libs = [];
        var availables = [];
        var map = {};

        deps.forEach(function(dependency, index) {
            if (typeof dependency === "string") {
                _processAmdDep(_global, libs, availables, map, dependency, index);
            } else if (isPlainObject(dependency)) {
                _processAmdDep(_global, libs, availables, map, dependency.amd, index);
            }
        });

        if (typeof callback !== "function" && deps.length === 1) {
            return availables[0];
        }

        if (libs.length === 0) {
            return callback.apply(_global, availables);
        }

        require(libs, function() {
            var lib;

            for (var index = 0, len = arguments.length; index < len; index++) {
                lib = arguments[index];
                availables[map[index]] = lib;
            }

            return callback.apply(_global, availables);
        }, errback);
    }

    var exports = {
        common: commonSpecDefine,
        amd: amdDefine
    };

    function browserExtend(exports) {
        if (typeof window === "undefined" || typeof window.window !== "object" || window.window.window !== window.window) {
            return;
        }

        function extend(target, src) {
            var prop;
            if (isObjectLike(src) && isObjectLike(target)) {
                // eslint-disable-next-line guard-for-in
                for (prop in src) {
                    target[prop] = src[prop];
                }
            }
            return target;
        }

        function isValidContainer(value) {
            var ref;
            return isObjectLike(value) && ((ref = value.nodeType) === 1 || ref === 9 || ref === 11) && !isPlainObject(value);
        }

        var head = document.getElementsByTagName("head")[0];

        // ===========================
        // Taken from requirejs 2.1.11
        // ===========================
        var isOpera = typeof opera !== "undefined" && opera.toString() === "[object Opera]";

        function load(attributes, container, callback, errback, completeback) {
            if (("function" === typeof container || !isValidContainer(container)) && arguments.length === 4) {
                callback = arguments[2];
                errback = arguments[3];
                completeback = arguments[4];
                container = null;
            }

            if (container == null) {
                container = head;
            }

            var node = document.createElement(attributes.tag);
            node.charset = "utf-8";
            node.async = true;

            var value;

            // eslint-disable-next-line guard-for-in
            for (var attr in attributes) {
                value = attributes[attr];
                if (attr !== "tag" && node[attr] !== value) {
                    node.setAttribute(attr, value);
                }
            }

            var context = getContext(callback, errback, completeback);

            //Set up load listener. Test attachEvent first because IE9 has
            //a subtle issue in its addEventListener and script onload firings
            //that do not match the behavior of all other browsers with
            //addEventListener support, which fire the onload event for a
            //script right after the script execution. See:
            //https://connect.microsoft.com/IE/feedback/details/648057/script-onload-event-is-not-fired-immediately-after-script-execution
            //UNFORTUNATELY Opera implements attachEvent but does not follow the script
            //script execution mode.
            if (node.attachEvent &&
                    //Check if node.attachEvent is artificially added by custom script or
                    //natively supported by browser
                    //read https://github.com/requirejs/requirejs/issues/187
                    //if we can NOT find [native code] then it must NOT natively supported.
                    //in IE8, node.attachEvent does not have toString()
                    //Note the test for "[native code" with no closing brace, see:
                    //https://github.com/requirejs/requirejs/issues/273
                    !(node.attachEvent.toString && node.attachEvent.toString().indexOf("[native code") < 0) &&
                    !isOpera) {

                node.attachEvent("onreadystatechange", context.onScriptLoad);
                //It would be great to add an error handler here to catch
                //404s in IE9+. However, onreadystatechange will fire before
                //the error handler, so that does not help. If addEventListener
                //is used, then IE will fire error before load, but we cannot
                //use that pathway given the connect.microsoft.com issue
                //mentioned above about not doing the 'script execute,
                //then fire the script load event listener before execute
                //next script' that other browsers do.
                //Best hope: IE10 fixes the issues,
                //and then destroys all installs of IE 6-9.
                //node.attachEvent('onerror', context.onScriptError);
            } else {
                node.addEventListener("load", context.onScriptLoad, false);
                node.addEventListener("error", context.onScriptError, false);
            }

            container.appendChild(node);
            return node;
        }

        var readyRegExp = /^(?:complete|loaded)$/;

        function removeListener(node, func, name, ieName) {
            if (node.detachEvent && !isOpera) {
                if (ieName) {
                    node.detachEvent(ieName, func);
                }
            } else {
                node.removeEventListener(name, func, false);
            }
        }

        /**
         * Given an event from a script node, get the requirejs info from it,
         * and then removes the event listeners on the node.
         * @param {Event} evt
         */
        function onScriptComplete(context, evt, completeback) {
            //Using currentTarget instead of target for Firefox 2.0's sake. Not
            //all old browsers will be supported, but this one was easy enough
            //to support and still makes sense.
            var node = evt.currentTarget || evt.srcElement;

            //Remove the listeners once here.
            removeListener(node, context.onScriptLoad, "load", "onreadystatechange");
            removeListener(node, context.onScriptError, "error");

            if (typeof completeback === "function") {
                completeback();
            }
        }

        function getContext(callback, errback, completeback) {
            var context = {
                /**
                 * callback for script loads, used to check status of loading.
                 *
                 * @param {Event} evt the event from the browser for the script
                 * that was loaded.
                 */
                onScriptLoad: function(evt) {
                    //Using currentTarget instead of target for Firefox 2.0's sake. Not
                    //all old browsers will be supported, but this one was easy enough
                    //to support and still makes sense.
                    if (evt.type === "load" ||
                            readyRegExp.test((evt.currentTarget || evt.srcElement).readyState)) {
                        if (typeof callback === "function") {
                            callback();
                        }
                        onScriptComplete(context, evt, completeback);
                    }
                },

                /**
                 * Callback for script errors.
                 */
                onScriptError: function(evt) {
                    if (typeof errback === "function") {
                        errback();
                    }
                    onScriptComplete(context, evt, completeback);
                }
            };

            return context;
        }

        function getScript(src, container) {
            if (container == null) {
                container = head;
            }
            var scripts = container.getElementsByTagName("script");
            var a = document.createElement("a");
            a.setAttribute("href", src);

            var found, script;
            for (var j = 0, len = scripts.length; j < len; j++) {
                script = scripts[j];
                if (script.src === a.href) {
                    found = script;
                    break;
                }
            }

            a = null;
            return found;
        }

        function loadScript(src, attributes, container, callback, errback, completeback) {
            // eslint-disable-next-line no-magic-numbers
            if (("function" === typeof container || !isValidContainer(container)) && arguments.length === 5) {
                callback = arguments[2];
                errback = arguments[3];
                completeback = arguments[4];
                container = null;
            }

            if (getScript(src, container)) {
                if (typeof callback === "function") {
                    callback();
                }

                if (typeof completeback === "function") {
                    completeback();
                }

                return null;
            }

            attributes = extend({
                tag: "script",
                type: "text/javascript",
                src: src
            }, attributes);

            return load(attributes, container, callback, errback, completeback);
        }

        extend(exports, {
            load: load,
            loadScript: loadScript,
            getScript: getScript
        });
    }

    browserExtend(exports);

    return exports;
});