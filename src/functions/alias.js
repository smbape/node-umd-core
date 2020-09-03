/**
 * Alias a method while keeping the context correct, to allow for overwriting of target method.
 *
 * @param {String} name The name of the target method.
 * @return {Function} The aliased method
 * @api private
 */
const alias = name => {
    return function aliasClosure() {
        return this[name](...arguments); // eslint-disable-line no-invalid-this
    };
};

module.exports = alias;
