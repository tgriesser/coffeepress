# Coffeepress

Helps package coffeescript files into a single file for evaluation to js.

## Notes:

Coffeepress uses synchronous `fs` calls, as this is mainly used as a utility before  
an app is loaded, and therefore the performance of async calls shouldn't really matter.

## Usage

`new Coffeepress([options]).run(callback);`

The `options` hash takes several parameters:


## Example

	var Coffeepress = require('coffeepress');

	new Coffeepress({
	  filename : './lib/formloader.coffee'
	}).run(function(err, data){
	  if (err) throw err
	  fs.writeFile('./public/javascripts/formloader.coffee', data, 'UTF-8', function() {
	    fs.writeFile('./public/javascripts/formloader.js', coffee.compile(data), 'UTF-8', function() {
	      console.log('done');
	    });
	  });
	});

## Templating

The following functions are available for use within the templates processed by coffeepress



## License

MIT