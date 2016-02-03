deps = [
    {amd: 'lodash', common: '!_', node: 'lodash'}
    {amd: 'jquery', common: '!jQuery'}
    {amd: 'backbone', common: '!Backbone', node: 'backbone'}
    {amd: 'i18next', common: '!i18next'}
]

factory = (_, $, Backbone, i18n)->
    {_, $, Backbone, i18n}
