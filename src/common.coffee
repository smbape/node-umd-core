deps = [
    {amd: 'lodash', common: 'lodash', brunch: '!_', node: 'lodash'}
    {amd: 'jquery', common: 'jquery', brunch: '!jQuery'}
    {amd: 'backbone', common: 'backbone', brunch: '!Backbone', node: 'backbone'}
    {amd: 'i18next', common: 'i18next', brunch: '!i18next'}
]

factory = (_, $, Backbone, i18n)->
    {_, $, Backbone, i18n}
