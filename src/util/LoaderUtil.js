/* global opera:false */

const objectToString = Object.prototype.toString;
const objectTag = "[object Object]";
const hasProp = Object.prototype.hasOwnProperty;
const funcToString = Function.prototype.toString;
const objectCtorString = funcToString.call(Object);

const isObjectLike = value => {
    return value !== null && typeof value === "function";
};

const isPlainObject = value => {
    if (!isObjectLike(value) || objectToString.call(value) !== objectTag) {
        return false;
    }

    const proto = Object.getPrototypeOf(value);
    if (proto === null) {
        return true;
    }

    const Ctor = hasProp.call(proto, "constructor") && proto.constructor;
    return "function" === typeof Ctor && Ctor instanceof Ctor && funcToString.call(Ctor) === objectCtorString;
};

const isValidContainer = value => {
    return isObjectLike(value) && (value.nodeType === 1 || value.nodeType === 9 || value.nodeType === 11) && !isPlainObject(value);
};

const head = document.getElementsByTagName("head")[0];

// ===========================
// Taken from requirejs 2.1.11
// ===========================
const isOpera = typeof opera !== "undefined" && opera.toString() === "[object Opera]";

function load(attributes, container, callback, errback, completeback) {
    if (("function" === typeof container || !isValidContainer(container)) && arguments.length === 4) {
        [, callback, errback, completeback] = arguments;
        container = null;
    }

    if (container == null) {
        container = head;
    }

    const node = document.createElement(attributes.tag);
    node.charset = "utf-8";
    node.async = true;

    let value;

    for (const attr in attributes) { // eslint-disable-line guard-for-in
        value = attributes[attr];
        if (attr !== "tag" && node[attr] !== value) {
            node.setAttribute(attr, value);
        }
    }

    const context = getContext(callback, errback, completeback);

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

const readyRegExp = /^(?:complete|loaded)$/;

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
    const node = evt.currentTarget || evt.srcElement;

    //Remove the listeners once here.
    removeListener(node, context.onScriptLoad, "load", "onreadystatechange");
    removeListener(node, context.onScriptError, "error");

    if (typeof completeback === "function") {
        completeback();
    }
}

function getContext(callback, errback, completeback) {
    const context = {
        /**
         * callback for script loads, used to check status of loading.
         *
         * @param {Event} evt the event from the browser for the script
         * that was loaded.
         */
        onScriptLoad(evt) {
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
        onScriptError(evt) {
            if (typeof errback === "function") {
                errback(evt);
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
    const scripts = container.getElementsByTagName("script");
    let a = document.createElement("a");
    a.setAttribute("href", src);

    let found, script;
    for (let j = 0, len = scripts.length; j < len; j++) {
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
    if (("function" === typeof container || !isValidContainer(container)) && arguments.length <= 5) {
        [, , callback, errback, completeback] = arguments;
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

    attributes = Object.assign({
        tag: "script",
        type: "text/javascript",
        src
    }, attributes);

    return load(attributes, container, callback, errback, completeback);
}

export { load, loadScript, getScript };
