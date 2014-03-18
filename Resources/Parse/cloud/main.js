var express = require('express');
var app = express();
app.use(express.bodyParser());
 
app.post('/notify',
	express.basicAuth('YOUR_USERNAME', 'YOUR_PASSWORD'),
	function(req, res) {
		var job = req.body.job;
		var query = new Parse.Query(Parse.Installation);
		query.containedIn('deviceToken', [job.pass_through]);
		Parse.Push.send({		
			where: query,
			data: {
				alert: "Job Done!",
				state: job.state,
				id: job.id
			}
		});
		res.send('Success');
	}, function(error) {
    	res.status(500);
    	res.send('Error');
});
 
app.listen();
