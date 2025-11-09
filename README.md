# AI-Powered Receipt Organizer

[![AWS](https://img.shields.io/badge/AWS-Serverless-orange)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)
[![Docker](https://img.shields.io/badge/Container-Docker-blue)](https://www.docker.com/)
[![Python](https://img.shields.io/badge/Python-3.11-green)](https://www.python.org/)

Professional-grade receipt management system with AI-powered spending insights. Snap a photo on your iPhone, get instant intelligent analysis via email.

## 🎯 Features

### Core Functionality
- 📱 **iPhone PWA** - Camera-optimized progressive web app
- 🤖 **AI Analysis** - Claude 3.5 Sonnet provides spending insights
- 📊 **Smart Comparisons** - Tracks prices across stores automatically
- 💰 **Budget Tracking** - Compares purchases against 30-day averages
- 📧 **Instant Notifications** - Beautiful HTML emails with actionable tips
- 🔍 **OCR Extraction** - Amazon Textract pulls vendor, date, total, items

### Infrastructure
- 🐳 **Containerized** - Docker images for all Lambda functions
- 🏗️ **Infrastructure as Code** - Complete Terraform deployment
- 🚀 **Serverless** - Zero server management, pay-per-use
- 🔒 **Secure** - Encryption at rest, presigned URLs, least-privilege IAM
- 📈 **Scalable** - Handles 1 or 1,000 receipts per month

## 🏗️ Architecture

```
┌─────────────────┐
│  iPhone Camera  │  ← Progressive Web App
│    (Frontend)   │     Add to home screen
└────────┬────────┘
         │ HTTPS
         ▼
┌─────────────────┐
│   CloudFront    │  ← Global CDN
└────────┬────────┘     Low latency
         │
         ▼
┌─────────────────┐     ┌──────────────────┐
│  API Gateway    │────►│ presigned-url    │  ← Secure upload
│   (HTTP API)    │     │ Lambda (Docker)  │     tokens
└─────────────────┘     └──────────────────┘
                               │
                               ▼
         ┌────────────────────────────────┐
         │      S3 Receipts Bucket        │  ← Receipt storage
         │    (Lifecycle: 90d → IA)       │     Auto-archival
         └────────┬───────────────────────┘
                  │ S3 Event Trigger
                  ▼
         ┌────────────────────────────────┐
         │   receipt-ingest Lambda        │  ← Main processor
         │  (Docker + Python 3.11)        │     60s timeout
         └─┬──────┬────────┬──────────┬───┘
           │      │        │          │
     ┌─────▼──┐ ┌─▼─────┐ ┌▼────────┐ ┌▼──────┐
     │Textract│ │Bedrock│ │DynamoDB │ │  SES  │
     │  (OCR) │ │Claude │ │30d data │ │Email  │
     └────────┘ └───────┘ └─────────┘ └───────┘
```

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured
- Docker & Terraform installed
- SES email verified in us-west-2

### One-Command Deployment

```bash
# Clone repository
git clone https://github.com/josephventuri/aws-receipt-organizer.git
cd aws-receipt-organizer

# Configure (update with your email)
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
vim terraform/terraform.tfvars

# Deploy everything
./deploy.sh dev
```

This will:
1. Build and push Docker images to ECR
2. Create all AWS infrastructure with Terraform
3. Deploy frontend to S3/CloudFront
4. Output your application URL

**Detailed instructions**: [DEPLOYMENT.md](DEPLOYMENT.md)

## 📱 Usage

1. Open CloudFront URL on iPhone
2. Add to home screen (looks like native app)
3. Grant camera permission
4. Take photo of receipt
5. Upload
6. Check email for AI insights!

## 💡 AI Insights Example

After uploading a receipt, you'll receive an email like:

```
💡 Spending Insights

• Great job! $53.28 is right on track with your average spending. 👍

• Turkey seems to be a focus here. Consider buying a whole turkey
  instead of ground turkey - often cheaper per pound and more versatile.

• Cottage cheese was $0.50 cheaper at Albertsons last time you bought it.

• Next time, bring reusable bags to save on checkout bag tax. Small
  amount but adds up over time!
```

## 🛠️ Tech Stack

### Infrastructure
- **Terraform** - Infrastructure as Code
- **Docker** - Lambda containerization
- **AWS Lambda** - Serverless compute (Python 3.11)
- **Amazon S3** - Receipt storage + frontend hosting
- **Amazon CloudFront** - Global CDN
- **Amazon API Gateway** - HTTP API

### AI & Data
- **Amazon Bedrock** - Claude 3.5 Sonnet for insights
- **Amazon Textract** - OCR text extraction
- **Amazon DynamoDB** - Receipt data storage (30 days)
- **Amazon SES** - Email notifications

### Frontend
- **Progressive Web App** - Mobile-optimized
- **Vanilla JavaScript** - No framework overhead
- **Service Worker** - Offline capability

## 📊 Cost Breakdown

**Estimated monthly cost for 100 receipts:**

| Service | Cost |
|---------|------|
| Lambda | $0.20 |
| S3 | $0.50 |
| DynamoDB | $0.25 |
| API Gateway | $0.10 |
| CloudFront | $0.50 |
| Textract | $15.00 |
| Bedrock (Claude) | $0.30 |
| **Total** | **~$17/month** |

*Most costs scale with usage. Textract is the largest component.*

## 🔒 Security Features

- ✅ Encryption at rest (S3, DynamoDB)
- ✅ HTTPS everywhere
- ✅ Presigned S3 URLs (time-limited)
- ✅ Least-privilege IAM roles
- ✅ CloudWatch logging enabled
- ✅ CORS configured properly
- ✅ No hardcoded credentials

## 📁 Project Structure

```
receipt-organizer/
├── docker/                    # Docker configurations
│   ├── receipt-ingest/       # Main processor Lambda
│   ├── presigned-url/        # Upload URL generator
│   └── build.sh              # Build & push script
│
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Root configuration
│   ├── variables.tf          # Input variables
│   ├── outputs.tf            # Output values
│   └── modules/              # Reusable modules
│       ├── lambda/           # Lambda function module
│       ├── s3/               # S3 bucket module
│       ├── dynamodb/         # DynamoDB table module
│       ├── iam/              # IAM roles module
│       ├── api-gateway/      # API Gateway module
│       └── cloudfront/       # CloudFront module
│
├── frontend/                  # Progressive Web App
│   ├── index.html            # Main page
│   ├── app.js                # JavaScript logic
│   ├── styles.css            # Styling
│   ├── manifest.json         # PWA manifest
│   └── service-worker.js     # Offline support
│
├── handler.py                 # Receipt processing Lambda
├── generate_presigned_url.py  # Upload URL Lambda
├── deploy.sh                  # Automated deployment
├── DEPLOYMENT.md              # Deployment guide
└── README.md                  # This file
```

## 🔧 Development

### Local Testing

```bash
# Build Docker images locally
cd docker
./build.sh all

# Test Lambda locally (requires AWS SAM)
sam local invoke receipt-ingest -e test-event.json
```

### Update Lambda Functions

```bash
# After code changes
cd docker
./build.sh all --push

# Update via Terraform
cd ../terraform
terraform apply -target=module.lambda_receipt_ingest
```

### View Logs

```bash
# Receipt processing logs
aws logs tail /aws/lambda/receipt-organizer-dev-receipt-ingest --follow

# API logs
aws logs tail /aws/apigateway/receipt-organizer-dev-api --follow
```

## 🎓 Key Learnings

- **Terraform Modules** - Built reusable infrastructure components
- **Docker for Lambda** - Containerized Python functions for consistency
- **Bedrock Integration** - Used Claude for AI-powered insights
- **Cost Optimization** - Implemented S3 lifecycle rules, DynamoDB on-demand
- **IaC Best Practices** - Separate modules, variables, and environments
- **PWA Development** - Camera access, offline support, home screen install

## 🚧 Roadmap

- [ ] Monthly summary email reports
- [ ] Custom domain with Route53
- [ ] GitHub Actions CI/CD pipeline
- [ ] Multi-user support with Cognito
- [ ] Export to CSV/Excel
- [ ] Budget alerts via SNS
- [ ] Mobile app (React Native)

## 📝 License

MIT License - feel free to use for your own projects!

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## 📧 Contact

**Joseph Venturi**
- Portfolio: [josephventuri.io](https://josephventuri.io)
- GitHub: [@josephventuri](https://github.com/josephventuri)
- Project: [aws-receipt-organizer](https://github.com/josephventuri/aws-receipt-organizer)

---

⭐ **Star this repo if you found it helpful!**
