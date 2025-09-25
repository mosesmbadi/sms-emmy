Plugin addon for processing SMS.
Recceived contacts and message and processes them.
Might be used to call an external API such us Twilio to send SMS.

Example POST request

```
curl --request POST \
  --url http://localhost:5000/messages \
  --header 'Content-Type: application/json' \
  --header 'User-Agent: insomnia/11.4.0' \
  --data ' {
   "contacts": [
     {
			 "phone": "55552671",
			 "name": "Jane",
			 "company": "Jane & jane"
		 },
		  {
			 "phone": "+14155552671",
			 "name": "Jane",
			 "company": "Jane & jane"
		 },
		 {
			 "phone": "+14155552671",
			 "name": "Jane",
			 "company": "Jane & jane"
		 }

   ],
   "message": "Hello, {name} your company {company} this is a test message."
}
```

Get the metrics:
```
curl --request GET \
  --url http://localhost:5000/metrics \
  --header 'User-Agent: insomnia/11.4.0'
  ```