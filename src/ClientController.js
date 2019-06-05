import inherits from "./functions/inherits";
import Backbone from "%{amd: 'backbone', brunch: '!Backbone', common: 'backbone', node: 'backbone'}";

const hasProp = Object.prototype.hasOwnProperty;

const toCamelDash = str => {
    return str.replace(/-(\w)/g, match => {
        return match[1].toUpperCase();
    });
};

function ClientController() {
    ClientController.__super__.constructor.apply(this, arguments);
}

inherits(ClientController, Backbone.Model);

Object.assign(ClientController.prototype, {
    getMethod(handlerOptions) {
        const {pathParams} = handlerOptions;
        const action = pathParams != null ? pathParams.action : null;

        if ("string" === typeof action) {
            return `${ toCamelDash(action.toLowerCase()) }Action`;
        }

        return null;
    },

    getUrl(params, options) {
        if (!(options != null ? options.reset : undefined)) {
            params = Object.assign({}, this.get("pathParams"), params);
        }
        return this.get("engine").getUrl(params, options);
    },

    render(View, options, done) {
        switch (arguments.length) {
            case 0:
                return;
            case 1:
                done = View;
                break;
            case 2:
                done = options;
                options = {
                    container: this.get("container"),
                    controller: this
                };

                this.view = View.createElement(options);
                break;
            default:
                options = Object.assign({}, options, {
                    container: this.get("container"),
                    controller: this
                });

                this.view = View.createElement(options);
        }

        const {view} = this;

        if ("function" !== typeof view.render || view.render.length > 1) {
            done(new Error("invalid render method. It should be a function expectingat most ine argument"));
            return;
        }

        if (view.render.length === 1) {
            const timeout = setTimeout(() => {
                console.log("taking too long to render. Make sure you called done function");
            }, 1000);

            try {
                view.render(err => {
                    clearTimeout(timeout);
                    done(err, view);
                });
            } catch ( err ) {
                clearTimeout(timeout);
                done(err, view);
            }
        } else {
            let err;

            try {
                view.render();
            } catch ( error ) {
                err = error;
            }

            done(err, view);
        }
    },

    navigate(url, options) {
        if (url != null && typeof url === "object") {
            url = this.getUrl(url, options);
        }
        this.get("router").navigate(url, Object.assign({
            trigger: true
        }, options));
    },

    clearContainer(container) {
        this.get("router").clearContainer(container);
    },

    destroy() {
        if (this.view) {
            this.view.destroy();
        }

        for (const prop in this) {
            if (hasProp.call(this, prop)) {
                delete this[prop];
            }
        }
    }

});

ClientController.prototype.emit = ClientController.prototype.trigger;

module.exports = ClientController;
