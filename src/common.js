import $ from "%{amd: 'jquery', common: 'jquery', brunch: '!jQuery'}";
import _ from "%{amd: 'lodash', common: 'lodash', brunch: '!_', node: 'lodash'}";
import Backbone from "%{amd: 'backbone', common: 'backbone', brunch: '!Backbone', node: 'backbone'}";
import i18n from "%{amd: 'i18next', common: 'i18next', brunch: '!i18next'}";

export {_, $, Backbone, i18n};
