// http://stackoverflow.com/questions/384286/javascript-isdom-how-do-you-check-if-a-javascript-object-is-a-dom-object#384380
const isNode = o => {
    if (typeof Node === "object") {
        return o instanceof Node;
    }
    return o && typeof o === "object" && typeof o.nodeType === "number" && typeof o.nodeName === "string";
};

const isElement = o => {
    if (typeof HTMLElement === "object") {
        return o instanceof HTMLElement;
    }
    return o && typeof o === "object" && o !== null && o.nodeType === 1 && typeof o.nodeName === "string";
};

const isNodeOrElement = o => {
    return isNode(o) || isElement(o);
};

const discard = element => {
    // http://jsperf.com/emptying-a-node

    while (element.lastChild) {
        discard(element.lastChild);
    }

    if (element.nodeType === 1 && !/^(?:IMG|SCRIPT|INPUT)$/.test(element.nodeName)) {
        element.innerHTML = "";
    }

    if (element.parentNode) {
        element.parentNode.removeChild(element);
    }
};

export { isNode, isElement, isNodeOrElement, discard };
