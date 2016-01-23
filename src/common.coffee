deps = [
    {amd: 'lodash', common: '!_', node: 'lodash'}
    {amd: 'jquery', common: '!jQuery'}
    {amd: 'backbone', common: '!Backbone', node: 'backbone'}
    {amd: 'eventEmitter', common: '!EventEmitter', node: 'events'}
]

factory = (_, $, Backbone, events)->

	{
		_
		$
		Backbone
		EventEmitter: events.EventEmitter or events
	}
