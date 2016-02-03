deps = [
    {amd: 'lodash', common: '!_', node: 'lodash'}
    {amd: 'jquery', common: '!jQuery'}
    {amd: 'backbone', common: '!Backbone', node: 'backbone'}
]

factory = (_, $, Backbone, events)->

	{
		_
		$
		Backbone
	}
