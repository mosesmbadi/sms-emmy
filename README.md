Plugin addon for processing SMS.
Receives contacts and message and processes them.
Might be used to call an external API such as Twilio to send SMS.

## Features

- **Web UI**: User-friendly interface for uploading CSV files and sending bulk SMS
- **CSV Processing**: Automatically converts CSV files to the required JSON format
- **Phone Validation**: Validates phone numbers using the phonenumbers library
- **Rate Limiting**: Built-in rate limiting to prevent abuse
- **Results Dashboard**: View detailed results of message processing
- **API Endpoints**: RESTful API for programmatic access

## Usage

### Web Interface

1. Start the application with `docker compose up`
2. Open your browser and go to `http://localhost:5000`
3. Upload a CSV file with contacts (see format below)
4. Enter your message template using placeholders like `{name}`, `{company}`
5. Click "Send Messages" to process

### CSV File Format

Your CSV file should have the following columns:

- `phone`: Phone number (with or without country code)
- `name`: Contact name
- `company`: Company name (optional)

Example:

```csv
phone,name,company
+14155552671,Jane Doe,Acme Corp
55552672,John Smith,Tech Solutions
+1234567890,Alice Johnson,Creative Agency
```

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

### API Endpoints

**Send Messages via JSON (Original)**

```bash
curl --request POST \
  --url http://localhost:5000/messages \
  --header 'Content-Type: application/json' \
  --header 'User-Agent: insomnia/11.4.0' \
  --data '{
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
     }
   ],
   "message": "Hello, {name} your company {company} this is a test message."
}'
```

**Upload CSV File**

```bash
curl --request POST \
  --url http://localhost:5000/upload \
  --form 'csvFile=@/path/to/contacts.csv' \
  --form 'message=Hello {name}, your company {company} has been selected!'
```

**Get Metrics**

```bash
curl --request GET \
  --url http://localhost:5000/metrics \
  --header 'User-Agent: insomnia/11.4.0'
```

## CSV to JSON Conversion Function

The application includes a `csv_to_json_converter` function that transforms CSV data into the JSON format expected by the API:

```python
def csv_to_json_converter(csv_content, message_template):
    """
    Convert CSV content and message template to JSON format expected by the API

    Args:
        csv_content (str): CSV content as string
        message_template (str): Message template with placeholders

    Returns:
        dict: JSON object with contacts and message
    """
```

This function:

- Parses CSV data and converts it to a list of contact dictionaries
- Handles missing fields by setting defaults (`name='Customer'`, `company='N/A'`)
- Returns the data in the exact format required by the `/messages` endpoint
