deps = [
    {amd: 'jquery', common: '!jQuery'}
]

factory = ($)->
    # https://developer.mozilla.org/fr/docs/Web/JavaScript/Reference/Objets_globaux/Function/bind#Prothèse_d'émulation_(polyfill)
    unless Function::bind
        Function::bind = (oThis) ->
            if typeof this != 'function'
                # au plus proche de la fonction interne 
                # ECMAScript 5 IsCallable
                throw new TypeError('Function.prototype.bind - ce qui est à lier ne peut être appelé')
            aArgs = Array::slice.call(arguments, 1)
            fToBind = this

            fNOP = ->

            fBound = ->
                fToBind.apply (if this instanceof fNOP then this else oThis), aArgs.concat(Array::slice.call(arguments))

            if @prototype
                # Les fonctions natives n'ont pas de prototype
                fNOP.prototype = @prototype
            fBound.prototype = new fNOP
            fBound

    # https://developer.mozilla.org/fr/docs/Web/JavaScript/Reference/Objets_globaux/Array/isArray#Prothèse_d'émulation_(polyfill)
    unless Array.isArray
        Array.isArray = (arg) ->
            Object::toString.call(arg) is '[object Array]'

    # https://developer.mozilla.org/fr/docs/Web/JavaScript/Reference/Objets_globaux/Object/keys#Prothèse_d'émulation_(polyfill)
    unless Object.keys
        do ->
            hasOwnProperty = Object::hasOwnProperty
            hasDontEnumBug = !{ toString: null }.propertyIsEnumerable('toString')
            dontEnums = [
                'toString'
                'toLocaleString'
                'valueOf'
                'hasOwnProperty'
                'isPrototypeOf'
                'propertyIsEnumerable'
                'constructor'
            ]
            dontEnumsLength = dontEnums.length
            Object.keys = (obj) ->
                if typeof obj != 'object' and (typeof obj != 'function' or obj == null)
                    throw new TypeError('Object.keys called on non-object')
                result = []

                for prop of obj
                    if hasOwnProperty.call(obj, prop)
                        result.push prop
                if hasDontEnumBug
                    for i in [0...dontEnumsLength] by 1
                        if hasOwnProperty.call(obj, dontEnums[i])
                            result.push dontEnums[i]
                result
            return

    # https://developer.mozilla.org/fr/docs/Web/JavaScript/Reference/Objets_globaux/String/trim#Polyfill
    unless String::trim
        do ->
            rtrim = /^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g
            String::trim = ->
                @replace rtrim, ''
            return

    discard = (element) ->
        discard element.firstChild while element.firstChild
        if element.nodeType is 1 and not /^(?:IMG|SCRIPT|INPUT)$/.test element.nodeName
            try
                element.innerHTML = ''
            catch ex
        element.parentNode.removeChild element if element.parentNode
        return

    $.fn.destroy = (selector) ->
        ret = this.remove()
        i = 0
        while (elem = this[i])?
            # Remove any remaining nodes
            discard elem
            i++
        ret

    $.fn.insertAt = (index, elements)->
        @domManip [elements], (elem) ->
            if this.children
                if this.children.length < index
                    this.appendChild elem
                else if index < 0
                    this.insertBefore elem, this.firstChild
                else
                    this.insertBefore elem, this.children[index]
            else
                this.appendChild elem
            return

    return
