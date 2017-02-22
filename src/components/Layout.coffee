deps = [
    '../common'
    'umd-core/src/GenericUtil'
    './AbstractModelComponent'
]

freact = ({_, $}, {throttle}, AbstractModelComponent)->

    $document = $(document)

    closeRightPanel = (evt)->
        data = evt.originalEvent or evt
        return if data.closeRightPanelHandled
        data.closeRightPanelHandled = true

        $(evt.currentTarget).closest('.layout').removeClass 'layout-open-right'
        return

    closeLeftPanel = (evt)->
        data = evt.originalEvent or evt
        return if data.closeLeftPanelHandled
        data.closeLeftPanelHandled = true

        $(evt.currentTarget).closest('.layout').removeClass 'layout-open-left'
        return

    openRightPanel = (evt)->
        data = evt.originalEvent or evt
        return if data.openHandled
        data.openHandled = true

        $(evt.currentTarget).closest('.layout').addClass 'layout-open-right'
        return

    openLeftPanel = (evt)->
        data = evt.originalEvent or evt
        return if data.openHandled
        data.openHandled = true

        $(evt.currentTarget).closest('.layout').addClass 'layout-open-left'
        return

    toggleRightPanel = (evt)->
        data = evt.originalEvent or evt
        return if data.toggleHandled
        data.toggleHandled = true

        $(evt.currentTarget).closest('.layout').toggleClass 'layout-open-right'
        return

    toggleLeftPanel = (evt)->
        data = evt.originalEvent or evt
        return if data.toggleHandled
        data.toggleHandled = true

        $(evt.currentTarget).closest('.layout').toggleClass 'layout-open-left'
        return

    START_EV = 'touchstart mousedown MSPointerDown pointerdown'
    MOVE_EV = 'touchmove mousemove MSPointerMove pointermove'
    END_EV = 'touchend mouseup MSPointerUp pointerup'
    CANCEL_EV = 'touchcancel mouseleave MSPointerCancel pointercancel'

    START_EV_MAP =
        touchstart: /^touch/
        mousedown: /^mouse/
        MSPointerDown: /^MSPointer/
        pointerdown: /^pointer/

    $document.on 'click', '.layout > .layout__overlay', closeRightPanel
    $document.on 'click', '.layout > .layout__overlay', closeLeftPanel

    $document.on 'click', '.layout .layout-action-close-right', closeRightPanel
    $document.on 'click', '.layout .layout-action-close-left', closeLeftPanel

    $document.on 'click', '.layout .layout-action-open-right', openRightPanel
    $document.on 'click', '.layout .layout-action-open-left', openLeftPanel

    $document.on 'click', '.layout .layout-action-toggle-right', toggleRightPanel
    $document.on 'click', '.layout .layout-action-toggle-left', toggleLeftPanel

    testElementStyle = document.createElement('div').style
    transformJSPropertyName = if 'transform' of testElementStyle then 'transform' else 'webkitTransform'
    userSelectJSPropertyName = if 'userSelect' of testElementStyle then 'userSelect' else 'webkitUserSelect'
    testElementStyle = null

    END_EV = [END_EV, CANCEL_EV].join(' ')
    MAX_TAN = Math.tan(45 * Math.PI / 180)
    MAX_TEAR = 5

    nativeCeil = Math.ceil

    class Layout extends AbstractModelComponent
        uid: 'Layout' + ('' + Math.random()).replace(/\D/g, '')

        componentDidMount: ->
            @_updateWidth()
            super
            return

        attachEvents: ->
            $(window).on 'resize', @_updateWidth
            if @$el
                @$el.find('> .layout__left, > .layout__right').on START_EV, @onTouchStart
                @$el.find('> .layout__left, > .layout__right').on MOVE_EV, @onTouchMove
                @$el.find('> .layout__left, > .layout__right').on END_EV, @onTouchEnd
            return

        detachEvents: ->
            if @$el
                @$el.find('> .layout__left, > .layout__right').off START_EV, @onTouchStart
                @$el.find('> .layout__left, > .layout__right').off MOVE_EV, @onTouchMove
                @$el.find('> .layout__left, > .layout__right').off END_EV, @onTouchEnd
            $(window).off 'resize', @_updateWidth
            return

        _getCurrentTarget: (evt)->
            data = evt.originalEvent or evt
            return if data.targetPanelHandled
            data.targetPanelHandled = true
            $(evt.currentTarget)

        getPosition: (evt)->
            touches = evt.touches
            if touches
                x: touches[0].clientX
                y: touches[0].clientY
            else
                x: evt.clientX
                y: evt.clientY

        onTouchStart: (evt)=>
            if @_moveState
                # touchevents are more reliable that pointer events on Chrome 55-56
                if evt.type is "touchstart" and @_moveState.type isnt evt.type
                    @_moveState.type = evt.type
                    @_moveState.regex = START_EV_MAP[evt.type]
                return

            # only care about single touch
            if evt.touches and evt.touches.length isnt 1
                return

            $target = @_getCurrentTarget(evt)
            return if not $target or not $target.length

            @_moveState = _.extend @getPosition(evt), {
                type: evt.type
                regex: START_EV_MAP[evt.type]
                target: $target[0]
                isLeft: $target.hasClass('layout__left')
                timerInit: new Date().getTime()
            }

            @_moveState.target.style.transition = 'none'
            @_inMove = false
            @_inVScroll = false

            scrollContainer = evt.target
            while scrollContainer and scrollContainer isnt document.body
                break if scrollContainer.scrollHeight > scrollContainer.clientHeight
                scrollContainer = scrollContainer.parentNode

            if scrollContainer isnt document.body
                @_moveState.scrollContainer = scrollContainer
            return

        onTouchMove: (evt)=>
            if not @_moveState or not @_moveState.regex.test(evt.type)
                return

            if not @_inVScroll and @el.getAttribute('data-width') is 'small'
                {x: startX, y: startY, isLeft, target, scrollContainer, timerInit} = @_moveState
                {x, y} = @getPosition(evt)
                diffX = x - startX
                diffY = y - startY
                aDiffX = if diffX < 0 then -diffX else diffX
                aDiffY = if diffY < 0 then -diffY else diffY

                if not @_inMove and (aDiffX is 0 or MAX_TAN < (aDiffY / aDiffX))
                    @_inVScroll = true
                    @onTouchEnd evt, true
                    return

                @_inMove = true
                if isLeft
                    @_moveState.diffX = -diffX
                    if diffX > MAX_TEAR
                        diffX = MAX_TEAR
                    tx = "translateX(#{nativeCeil(diffX)}px)"
                else
                    @_moveState.diffX = diffX
                    if -diffX > MAX_TEAR
                        diffX = -MAX_TEAR
                    tx = "translateX(-100%) translateX(#{nativeCeil(diffX)}px)"

                scrollContainer.style.overflow = 'hidden' if scrollContainer
                console.log(transformJSPropertyName, tx)
                target.style[transformJSPropertyName] = tx
            return

        onTouchEnd: (evt, fromMove)=>
            if not @_moveState or (not fromMove and not @_moveState.regex.test(evt.type))
                return

            {x: startX, y: startY, isLeft, target, scrollContainer, diffX, timerInit} = @_moveState
            if @_inMove
                timerDiff = new Date().getTime() - timerInit
                if (timerDiff < 200 and diffX > 0) or diffX > $(target).width() / 3
                    @$el.removeClass('layout-open-left layout-open-right')
            scrollContainer.style.overflow = '' if scrollContainer
            target.style.transition = ''
            target.style[transformJSPropertyName] = ''
            @_moveState.target = null
            @_moveState.scrollContainer = null
            @_moveState = null

            return

        _updateWidth: =>
            if @el
                {el, $el} = this
            else
                el = ReactDOM.findDOMNode @
                $el = $ el

            @_doUpdateWitdh el, $el
            return

        _doUpdateWitdh: (el, $el)->
            width = $el.width()
            if width < 1024
                el.setAttribute 'data-width', 'small'
            else if width < 1200
                el.setAttribute 'data-width', 'large'
            else
                el.setAttribute 'data-width', 'extra-large'

            return

        getProps: ->
            props = _.clone @props
            children = @props.children

            if props.className
                _className = [props.className, 'layout']
            else
                _className = ['layout']

            props.children = _children = []
            _remaining = []

            if children
                item = {}
                for child, idx in children
                    continue if not child

                    if className = child.props.className
                        re = /(?:^|\s)layout__(content|left|right)(?:\s|$)/g
                        if match = re.exec(className)
                            while match
                                [match, name] = match
                                switch name
                                    when 'content'
                                        item.content = child
                                    when 'left'
                                        item.left = child
                                    when 'right'
                                        item.right = child

                                match = re.exec(className)
                        else
                            _remaining.push child
                    else
                        _remaining.push child


                if not item.content
                    throw new Error "no content found"

                _children.push item.content
                _children.push `<div className="layout__overlay layout__overlay-center" />`

                if item.left
                    _className.push 'layout-has-left'
                    _children.push item.left
                    _children.push `<div className="layout__overlay layout__overlay-left" />`
                else
                    _children.push undefined
                    _children.push undefined

                if item.right
                    _className.push 'layout-has-right'
                    _children.push item.right
                else
                    _children.push undefined

            _children.push.apply _children, _remaining
            props.className = _className.join(' ')
            props

        render: ->
            React.createElement 'div', @getProps()