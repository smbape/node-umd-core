
deps = [
    './common'
    './GenericUtil'
]

factory = ({Backbone}, Util)->
    class ClientController extends Backbone.Model
        getMethod: ({pathParams})->
            if 'string' is typeof pathParams?.action
                Util.StringUtil.toCamelDash(pathParams.action.toLowerCase()) + 'Action'

    ClientController::emit = ClientController::trigger

    ClientController
