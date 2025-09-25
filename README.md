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

Testing/Manual deployments:
You can deploy the project manually by running the ./deploy.sh script in the terraform directory.
This should not be for production and is just for testing purposes.
Pre-requisites:

1. AWS CLI installed and configured with appropriate credentials.
2. Terraform installed.
3. Make the scripts executable and copy the example terraform.tfvars file.

```bash
╰─$ chmod +x "/home/mbadi/Desktop/Moses Mbadi/SavnnahInformaticsDevOpsAss/sms-emmy/terraform/deploy.sh"

╰─$ chmod +x "/home/mbadi/Desktop/Moses Mbadi/SavnnahInformaticsDevOpsAss/sms-emmy/terraform/destroy.sh"

╰─$ cd "/home/mbadi/Desktop/Moses Mbadi/SavnnahInformaticsDevOpsAss/sms-emmy/terraform" && cp ter
raform.tfvars.example terraform.tfvars

╰─$ aws --version
aws-cli/2.31.0 Python/3.13.7 Linux/6.8.0-51-generic exe/x86_64.ubuntu.24

╰─$ terraform version
Terraform v1.12.2
on linux_amd64

╰─$ ls -la ~/.aws/ 2>/dev/null || echo "No AWS config directory found"
total 16
drwxrwxr-x   2 mbadi mbadi 4096 Jul 13 18:49 .
drwxr-x---+ 85 mbadi mbadi 4096 Sep 25 13:35 ..
-rw-------   1 mbadi mbadi  123 Jul 13 18:49 config
-rw-------   1 mbadi mbadi  324 Jul 13 18:49 credentials

╰─$ cd "/home/mbadi/Desktop/Moses Mbadi/SavnnahInformaticsDevOpsAss/sms-emmy/terraform" && ./deploy.sh
```

## CI/CD Pipeline

This project includes a complete CI/CD pipeline using GitHub Actions that automatically:

1. **Builds** Docker images on every push/PR
2. **Pushes** images to GitHub Container Registry (ghcr.io)
3. **Deploys** to AWS infrastructure when code is merged to main

### GitHub Secrets Required

Configure these secrets in your GitHub repository:

**For Infrastructure Deployment:**

- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `AWS_REGION`: AWS region (e.g., us-west-2)

**For Application Deployment:**

- `PRODUCTION_HOST`: EC2 instance public IP (set after infrastructure deployment)
- `PRODUCTION_USER`: SSH username (default: ubuntu)
- `PRODUCTION_SSH_KEY`: Private key for SSH access to EC2 instances

### CI/CD Workflows

This project uses **two separate workflows** following industry best practices:

#### 1. Infrastructure Deployment (Manual Trigger)

**Workflow:** `.github/workflows/infrastructure.yml`

- **Trigger:** Manual workflow dispatch
- **Purpose:** Deploy/destroy AWS infrastructure using Terraform
- **Actions:** `apply`, `destroy`, or `plan`
- **Run:** Go to GitHub Actions → "Deploy Infrastructure" → Run workflow

```
Manual Trigger → Terraform Init → Validate → Plan → Apply/Destroy → Summary
```

#### 2. Application Deployment (Automatic)

**Workflow:** `.github/workflows/deploy.yml`

- **Trigger:** Push to main branch
- **Purpose:** Build, push, and deploy application
- **Target:** Existing infrastructure (assumes infrastructure is already deployed)

```
Push to main → Build Image → Push to GHCR → Deploy to Server → Health Check → Cleanup
```

### Deployment Process

1. **First-time Setup:**

   ```bash
   # 1. Deploy infrastructure manually
   Go to GitHub Actions → "Deploy Infrastructure" → Run workflow (action: apply)

   # 2. Update repository secrets with the instance IP from Terraform output
   PRODUCTION_HOST: <instance_ip_from_terraform>

   # 3. Push code to main branch to trigger app deployment
   git push origin main
   ```

2. **Regular Deployments:**
   ```bash
   # Simply push to main - infrastructure stays unchanged
   git push origin main
   ```

### Benefits of This Approach

- **Faster Deployments**: No Terraform overhead on every deploy (~2-3 min vs 8-10 min)
- **Infrastructure Safety**: Prevents accidental infrastructure changes
- **Cost Control**: Infrastructure changes are intentional and reviewed
- **Separation of Concerns**: Infrastructure and application lifecycles are separate
- **Zero Downtime**: Application deployments use health checks and rolling updates

### Manual Deployment (Alternative)

For manual deployments:

1. Ensure you have proper AWS IAM permissions for EC2, VPC, and related services
2. Configure your terraform.tfvars file with appropriate values
3. Run `terraform init` to initialize the Terraform working directory
4. Run `terraform plan` to review the infrastructure changes
5. Run `terraform apply` to deploy the infrastructure
6. The application will be accessible at the EC2 instance's public IP

Note: This configuration uses local state management. For production environments, consider configuring a remote backend with S3 and DynamoDB for state management and team collaboration.
