# Automated Receipt Organizer – AWS AI/Serverless Project

## Project Overview
Keeping track of paper receipts manually is time-consuming and disorganized. I wanted to build a fully automated cloud system where:
- Receipts could be uploaded easily
- Important data (vendor, date, total) would be extracted automatically
- Data would be stored neatly in a database
- Email summaries would be sent without manual work

The solution needed to be scalable, serverless, and fit within AWS Free Tier limits.

---

## How It Works
Built an end-to-end serverless system using AWS services:
- **Amazon S3**: Upload and store receipt images (Incoming folder)
- **AWS Lambda (Python 3.9)**: Orchestrate receipt processing
- **Amazon Textract**: Extract text data from receipt files
- **Amazon DynamoDB**: Store extracted receipt metadata
- **Amazon SES**: Email summarized receipt details to the user
- **AWS IAM**: Manage permissions and secure service communication

### Workflow Summary
1. A user uploads a receipt to the S3 Incoming folder.
2. S3 triggers a Lambda function automatically.
3. Lambda processes the receipt with Textract.
4. Extracted details are saved to DynamoDB.
5. An email summary is sent via SES.

---

## Tech Stack
- AWS S3
- AWS Lambda (Python 3.9)
- Amazon Textract
- Amazon DynamoDB
- Amazon SES
- AWS IAM

---

## Key Lessons Learned
- Gained experience integrating multiple AWS services together
- Managed IAM roles for secure communication
- Learned to adjust Lambda timeouts for longer Textract processing
- Practiced setting up S3 Event Notifications and Lambda triggers

---

## Demonstration
- **Live Portfolio Site:** [josephventuri.io](https://josephventuri.io)
- **GitHub Repo:** [aws-receipt-organizer](https://github.com/josephventuri/aws-receipt-organizer)


