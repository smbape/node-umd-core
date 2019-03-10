import React from "%{ amd: 'react', brunch: '!React', common: 'react' }";

module.exports = (element, overrides) => {
    if (!React.isValidElement(element)) {
        return Object.assign({}, element);
    }

    const {key, ref, type} = element;
    let {props} = element;
    const {children} = props;

    props = Object.assign({}, props, overrides);

    if (key) {
        props.key = key;
    }

    if (ref) {
        props.ref = ref;
    }

    if (!children) {
        return React.createElement(type, props);
    }

    const args = [type, props];

    if (Array.isArray(children)) {
        args.push(...children);
    } else {
        args.push(children);
    }
    return React.createElement(...args);
};
