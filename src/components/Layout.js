import React from "%{ amd: 'react', brunch: '!React', common: 'react' }";
import ReactDOM from "%{ amd: 'react-dom', brunch: '!ReactDOM', common: 'react-dom' }";
import $ from "%{amd: 'jquery', brunch: '!jQuery', common: 'jquery'}";
import AbstractModelComponent from "./AbstractModelComponent";
import inherits from "../functions/inherits";
import throttle from "../functions/throttle";
import supportOnPassive from "../functions/supportOnPassive";

const ceil = Math.ceil;
const $document = $(document);

const testElementStyle = document.createElement("div").style;
const transformJSPropertyName = "transform" in testElementStyle ? "transform" : "webkitTransform";
// const userSelectJSPropertyName = "userSelect" in testElementStyle ? "userSelect" : "webkitUserSelect";

// manually setting transform properties to fixed values
// gives way smoother animation than adding/removing a className
// because adding/removing a className causes "Recalculate Style"

const openRightPanel = el => {
    const wattr = el.attr("data-umd-layout-width");
    if (wattr !== "small" && wattr !== "large") {
        return;
    }

    const width = el.attr("data-umd-layout-width-value");
    const overlay = {
        opacity: 0.5
    };
    overlay[transformJSPropertyName] = `translate3d(-${ width }px, 0px, 0px)`;
    el.find("> .layout__overlay-left").css(overlay);

    el.find("> .layout__right").css(transformJSPropertyName, `translate3d(-${ el.attr("data-umd-layout-right-width") }, 0px, 0px)`);

    el[0].setAttribute("data-layout-open-right", "");
};

const closeRightPanel = el => {
    const wattr = el.attr("data-umd-layout-width");
    if (wattr !== "small" && wattr !== "large") {
        const overlay = el.find("> .layout__overlay-left")[0];
        overlay.style.opacity = "";
        overlay.style[transformJSPropertyName] = "";
        el.find("> .layout__right")[0].style[transformJSPropertyName] = "";
        return;
    }

    if (wattr) {
        const overlay = {
            opacity: 0
        };
        overlay[transformJSPropertyName] = "translate3d(0px, 0px, 0px)";
        el.find("> .layout__overlay-left").css(overlay);
        el.find("> .layout__right").css(transformJSPropertyName, "translate3d(0px, 0px, 0px)");
    }

    el[0].removeAttribute("data-layout-open-right");
};

const toggleRightPanel = el => {
    if (el[0].hasAttribute("data-layout-open-right")) {
        closeRightPanel(el);
    } else {
        openRightPanel(el);
    }
};

const openLeftPanel = el => {
    const wattr = el.attr("data-umd-layout-width");
    if (wattr !== "small") {
        return;
    }

    const overlay = {
        opacity: 0.5
    };
    overlay[transformJSPropertyName] = "translate3d(0px, 0px, 0px)";
    el.find("> .layout__overlay-center").css(overlay);

    el.find("> .layout__left").css(transformJSPropertyName, "translate3d(0px, 0px, 0px)");

    el[0].setAttribute("data-layout-open-left", "");
};

const closeLeftPanel = el => {
    const wattr = el.attr("data-umd-layout-width");
    if (wattr !== "small") {
        const overlay = el.find("> .layout__overlay-center")[0];
        overlay.style.opacity = "";
        overlay.style[transformJSPropertyName] = "";
        el.find("> .layout__left")[0].style[transformJSPropertyName] = "";
        return;
    }

    const width = el.attr("data-umd-layout-width-value");
    const overlay = {
        opacity: 0
    };
    overlay[transformJSPropertyName] = `translate3d(-${ width }px, 0px, 0px)`;
    el.find("> .layout__overlay-center").css(overlay);

    el.find("> .layout__left").css(transformJSPropertyName, `translate3d(-${ el.attr("data-umd-layout-left-width") }, 0px, 0px)`);

    el[0].removeAttribute("data-layout-open-left");
};

const toggleLeftPanel = el => {
    if (el[0].hasAttribute("data-layout-open-left")) {
        closeLeftPanel(el);
    } else {
        openLeftPanel(el);
    }
};

const handleOpenRightPanel = evt => {
    const data = evt.originalEvent || evt;
    if (data.openHandled) {
        return;
    }

    data.openHandled = true;
    openRightPanel($(evt.currentTarget).closest(".layout"));
};

const handleCloseRightPanel = evt => {
    const data = evt.originalEvent || evt;
    if (data.closeRightPanelHandled) {
        return;
    }

    data.closeRightPanelHandled = true;
    closeRightPanel($(evt.currentTarget).closest(".layout"));
};

const handleOpenLeftPanel = evt => {
    const data = evt.originalEvent || evt;
    if (data.openHandled) {
        return;
    }

    data.openHandled = true;
    openLeftPanel($(evt.currentTarget).closest(".layout"));
};

const handleCloseLeftPanel = evt => {
    const data = evt.originalEvent || evt;
    if (data.closeLeftPanelHandled) {
        return;
    }

    data.closeLeftPanelHandled = true;
    closeLeftPanel($(evt.currentTarget).closest(".layout"));
};

const handleToggleRightPanel = evt => {
    const data = evt.originalEvent || evt;
    if (data.toggleHandled) {
        return;
    }

    data.toggleHandled = true;
    toggleRightPanel($(evt.currentTarget).closest(".layout"));
};

const handleToggleLeftPanel = evt => {
    const data = evt.originalEvent || evt;
    if (data.toggleHandled) {
        return;
    }

    data.toggleHandled = true;
    toggleLeftPanel($(evt.currentTarget).closest(".layout"));
};

// passive click event listening for relevant selectors
(() => {
    const restore = supportOnPassive($, "click");
    $document.on("click", ".layout > .layout__overlay", handleCloseRightPanel);
    $document.on("click", ".layout > .layout__overlay", handleCloseLeftPanel);
    $document.on("click", ".layout .layout-action-close-right", handleCloseRightPanel);
    $document.on("click", ".layout .layout-action-close-left", handleCloseLeftPanel);
    $document.on("click", ".layout .layout-action-open-right", handleOpenRightPanel);
    $document.on("click", ".layout .layout-action-open-left", handleOpenLeftPanel);
    $document.on("click", ".layout .layout-action-toggle-right", handleToggleRightPanel);
    $document.on("click", ".layout .layout-action-toggle-left", handleToggleLeftPanel);
    restore();
})();

const START_EV = "touchstart mousedown";
const MOVE_EV = "touchmove mousemove";
let END_EV = "touchend mouseup";
const CANCEL_EV = "touchcancel mouseleave";
END_EV = [END_EV, CANCEL_EV].join(" ");
const START_EV_MAP = {
    touchstart: /^touch/,
    mousedown: /^mouse/
};

const MAX_TAN = Math.tan(45 * Math.PI / 180);
const MAX_TEAR = 5;

// https://github.com/WICG/EventListenerOptions/blob/gh-pages/explainer.md
const isPassiveEventListenerSupported = () => {
    let supportsPassive = false;

    try {
        window.addEventListener("test", null, Object.defineProperty({}, "passive", {
            // eslint-disable-next-line getter-return
            get() {
                supportsPassive = true;
            }
        }));
    } catch ( error ) {
        /* Nothing to do */
    }

    return supportsPassive;
};

const captureOptions = isPassiveEventListenerSupported() ? {
    capture: true,
    passive: true,
} : true;

function Layout() {
    this._updateWidth = this._updateWidth.bind(this);
    this.onTouchEnd = this.onTouchEnd.bind(this);
    this.onTouchMove = this.onTouchMove.bind(this);
    this.onTouchStart = this.onTouchStart.bind(this);
    Layout.__super__.constructor.apply(this, arguments);
}

inherits(Layout, AbstractModelComponent);

Object.assign(Layout.prototype, {
    uid: `Layout${ (String(Math.random())).replace(/\D/g, "") }`,

    componentDidMount() {
        this._updateWidth();
        const count = $(ReactDOM.findDOMNode(this)).parents(".layout").length + 1;
        this._updateWidth = throttle(this._updateWidth, count * 4, {
            leading: false
        });
        Layout.__super__.componentDidMount.apply(this, arguments);
    },

    attachEvents() {
        window.addEventListener("resize", this._updateWidth, captureOptions);
        if (this.$el) {
            const restore = supportOnPassive($, START_EV);
            this.$el.on(START_EV, "> .layout__left, > .layout__right", this.onTouchStart);
            restore();
        }
    },

    detachEvents() {
        if (this.$el) {
            this.$el.off(START_EV, "> .layout__left, > .layout__right", this.onTouchStart);
        }

        if (this._moveState) {
            this._moveState.removeTouchEventListeners();
        }

        if (this._updateWidth.cancel) {
            this._updateWidth.cancel();
        }

        window.removeEventListener("resize", this._updateWidth, captureOptions);
    },

    _getCurrentTarget(evt) {
        const data = evt.originalEvent || evt;

        if (data.targetPanelHandled) {
            return null;
        }

        data.targetPanelHandled = true;
        return $(evt.currentTarget);
    },

    getPosition(evt) {
        const touches = evt.touches;

        if (touches) {
            return {
                x: touches[0].clientX,
                y: touches[0].clientY
            };
        }

        return {
            x: evt.clientX,
            y: evt.clientY
        };
    },

    onTouchStart(evt) {
        if (this._moveState) {
            // touchevents are more reliable than pointer events on Chrome 55-56
            if (evt.type === "touchstart" && this._moveState.type !== evt.type) {
                this._moveState.type = evt.type;
                this._moveState.regex = START_EV_MAP[evt.type];
            }
            return;
        }

        // only care about single touch
        if (evt.touches && evt.touches.length !== 1) {
            return;
        }

        let $target = this._getCurrentTarget(evt);
        if (!$target || !$target.length) {
            return;
        }

        this._moveState = Object.assign(this.getPosition(evt), {
            type: evt.type,
            regex: START_EV_MAP[evt.type],
            target: $target[0],
            isLeft: $target.hasClass("layout__left"),
            timerInit: Date.now()
        });

        this._inMove = false;
        this._inVScroll = false;

        let scrollContainer = evt.target;
        while (scrollContainer && scrollContainer !== document.body) {
            if (scrollContainer.scrollHeight > scrollContainer.clientHeight) {
                break;
            }
            scrollContainer = scrollContainer.parentNode;
        }

        if (scrollContainer !== document.body) {
            this._moveState.scrollContainer = scrollContainer;
        }

        const restore = supportOnPassive($, `${ MOVE_EV } ${ END_EV }`);
        $target.on(MOVE_EV, this.onTouchMove);
        $target.on(END_EV, this.onTouchEnd);
        restore();

        this._moveState.removeTouchEventListeners = () => {
            $target.off(MOVE_EV, this.onTouchMove);
            $target.off(END_EV, this.onTouchEnd);
            $target = null;
        };
    },

    onTouchMove(evt) {
        if (!this._moveState || !this._moveState.regex.test(evt.type)) {
            return;
        }

        if (!this._inVScroll && this.el.getAttribute("data-umd-layout-width") === "small") {
            const {x: startX, y: startY, isLeft, target, scrollContainer} = this._moveState;
            const {x, y} = this.getPosition(evt);

            let diffX = x - startX;
            const diffY = y - startY;
            const aDiffX = diffX < 0 ? -diffX : diffX;
            const aDiffY = diffY < 0 ? -diffY : diffY;

            if (!this._inMove && (aDiffX === 0 || MAX_TAN < (aDiffY / aDiffX))) {
                this._inVScroll = true;
                this.onTouchEnd(evt, true);
                return;
            }

            if (!this._inMove) {
                this._moveState.target.style.transition = "none";
                this._inMove = true;
            }

            let tx;

            if (isLeft) {
                this._moveState.diffX = -diffX;
                if (diffX > MAX_TEAR) {
                    diffX = MAX_TEAR;
                }
                tx = `translateX(${ ceil(diffX) }px)`;
            } else {
                this._moveState.diffX = diffX;
                if (-diffX > MAX_TEAR) {
                    diffX = -MAX_TEAR;
                }
                tx = `translateX(-100%) translateX(${ ceil(diffX) }px)`;
            }

            if (scrollContainer) {
                scrollContainer.style.overflow = "hidden";
            }

            target.style[transformJSPropertyName] = tx;
        }
    },

    onTouchEnd(evt, fromMove) {
        if (!this._moveState || (!fromMove && !this._moveState.regex.test(evt.type))) {
            return;
        }

        const {target, scrollContainer, diffX, timerInit, removeTouchEventListeners} = this._moveState;
        removeTouchEventListeners();

        if (this._inMove) {
            target.style.transition = "";
            const timerDiff = Date.now() - timerInit;
            const isLeft = /(?:^|\s)layout__left(?:\s|$)/.test(target.className);
            const isRight = /(?:^|\s)layout__right(?:\s|$)/.test(target.className);

            if ((timerDiff < 200 && diffX > 0) || diffX > $(target).width() / 3) {
                if (isLeft) {
                    closeLeftPanel(this.$el);
                } else if (isRight) {
                    closeRightPanel(this.$el);
                }
            } else if (isLeft) {
                openLeftPanel(this.$el);
            } else if (isRight) {
                openRightPanel(this.$el);
            }
        }

        if (scrollContainer) {
            scrollContainer.style.overflow = "";
        }

        this._moveState.target = null;
        this._moveState.scrollContainer = null;
        this._moveState = null;
    },

    _updateWidth() {
        let el, $el;

        if (this.el) {
            el = this.el;
            $el = this.$el;
        } else {
            el = ReactDOM.findDOMNode(this);
            $el = $(el);
        }

        const width = $el.width();

        el.setAttribute("data-umd-layout-width-value", `${ width }`);

        if (width >= 1280) {
            el.setAttribute("data-umd-layout-width", "extra-large");
        } else if (width >= 1024) {
            el.setAttribute("data-umd-layout-width", "large");
        } else {
            el.setAttribute("data-umd-layout-width", "small");
        }

        el.setAttribute("data-umd-layout-right-width", $el.find("> .layout__right").css("width"));
        el.setAttribute("data-umd-layout-left-width", $el.find("> .layout__left").css("width"));

        if (el.hasAttribute("data-layout-open-left")) {
            openLeftPanel($el);
        } else {
            closeLeftPanel($el);
        }

        if (el.hasAttribute("data-layout-open-right")) {
            openRightPanel($el);
        } else {
            closeRightPanel($el);
        }
    },

    getProps() {
        const props = Object.assign({}, this.props);
        let {children} = props;

        let _className, match, name;

        if (props.className) {
            _className = [props.className, "layout"];
        } else {
            _className = ["layout"];
        }

        const _remaining = [];
        const _children = [];

        props.children = _children;

        if (children) {
            if (!Array.isArray(children)) {
                children = [children];
            }

            const item = {};

            children.forEach(child => {
                if (!child) {
                    return;
                }

                const className = child.props && child.props.className;

                if (className) {
                    const re = /(?:^|\s)layout__(content|left|right)(?:\s|$)/g;
                    match = re.exec(className);

                    if (match) {
                        while (match) {
                            [match, name] = match;

                            switch (name) {
                                case "content":
                                    item.content = child;
                                    break;
                                case "left":
                                    item.left = child;
                                    break;
                                case "right":
                                    item.right = child;
                                    break;
                                default:
                                    // Nothing to do
                            }

                            match = re.exec(className);
                        }
                    } else {
                        _remaining.push(child);
                    }
                } else {
                    _remaining.push(child);
                }
            });

            if (!item.content) {
                throw new Error("no content found");
            }

            _children.push(item.content);
            _children.push(<div ref="layout__overlay-center" className="layout__overlay layout__overlay-center" />);

            if (item.left) {
                _className.push("layout-has-left");
                _children.push(item.left);
                _children.push(<div ref="layout__overlay-left" className="layout__overlay layout__overlay-left" />);
            } else {
                _children.push(undefined);
                _children.push(undefined);
            }

            if (item.right) {
                _className.push("layout-has-right");
                _children.push(item.right);
            } else {
                _children.push(undefined);
            }
        }

        _children.push(..._remaining);
        props.className = _className.join(" ");
        return props;
    },

    render() {
        return React.createElement("div", this.getProps());
    }

});

module.exports = Layout;
