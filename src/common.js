import $ from "%{amd: 'jquery', brunch: '!jQuery', common: 'jquery'}";
import _ from "%{amd: 'lodash', brunch: '!_', common: 'lodash', node: 'lodash'}";
import Backbone from "%{amd: 'backbone', brunch: '!Backbone', common: 'backbone', node: 'backbone'}";
import i18n from "%{amd: 'i18next', brunch: '!i18next', common: 'i18next'}";

export {_, $, Backbone, i18n};
