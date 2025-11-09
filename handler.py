import json
import os
import boto3
import uuid
from datetime import datetime, timedelta
import urllib.parse
from decimal import Decimal
from collections import defaultdict

# Environment variables (matching Lambda configuration)
DYNAMODB_TABLE = os.environ.get('TABLE_NAME', 'jv-aro-dev-usw1-receipts')
SES_SENDER_EMAIL = os.environ.get('SES_FROM', 'your-email@example.com')
SES_RECIPIENT_EMAIL = os.environ.get('SES_TO', 'recipient@example.com')
SES_REGION = os.environ.get('SES_REGION', 'us-west-2')

# Initialize AWS clients
s3 = boto3.client('s3')
textract = boto3.client('textract')
dynamodb = boto3.resource('dynamodb')
ses = boto3.client('ses', region_name=SES_REGION)
bedrock = boto3.client('bedrock-runtime', region_name='us-west-2')

def handler(event, context):
    """Main Lambda handler to process uploaded receipt."""
    try:
        # Get the S3 bucket and key from the event
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'])

        print(f"Processing receipt from {bucket}/{key}")

        # Verify the object exists
        s3.head_object(Bucket=bucket, Key=key)

        # Step 1: Process receipt with Textract
        receipt_data = process_receipt_with_textract(bucket, key)

        # Step 2: Store results in DynamoDB
        store_receipt_in_dynamodb(receipt_data)

        # Step 3: Get spending history and calculate analytics
        print("Retrieving spending history...")
        spending_history = get_spending_history(days=30)
        print(f"Found {len(spending_history)} receipts in last 30 days")

        # Step 4: Calculate analytics
        print("Calculating spending analytics...")
        analytics = calculate_spending_analytics(receipt_data, spending_history)

        # Step 5: Generate AI insights
        print("Generating AI insights with Bedrock...")
        ai_insights = generate_ai_insights(receipt_data, analytics)

        # Step 6: Send email notification with insights
        send_email_notification(receipt_data, ai_insights)

        return {
            'statusCode': 200,
            'body': json.dumps('Receipt processed successfully!')
        }
    except Exception as e:
        print(f"Error processing receipt: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def process_receipt_with_textract(bucket, key):
    """Process receipt using Textract's AnalyzeExpense operation."""
    try:
        response = textract.analyze_expense(
            Document={
                'S3Object': {
                    'Bucket': bucket,
                    'Name': key
                }
            }
        )
        print("Textract analyze_expense call successful")
    except Exception as e:
        print(f"Textract analyze_expense call failed: {str(e)}")
        raise

    receipt_id = str(uuid.uuid4())
    receipt_data = {
        'receiptId': receipt_id,  # Changed to match DynamoDB schema
        'date': datetime.now().strftime('%Y-%m-%d'),
        'vendor': 'Unknown',
        'total': '0.00',
        'items': [],
        's3_path': f"s3://{bucket}/{key}"
    }

    if 'ExpenseDocuments' in response and response['ExpenseDocuments']:
        expense_doc = response['ExpenseDocuments'][0]

        for field in expense_doc.get('SummaryFields', []):
            field_type = field.get('Type', {}).get('Text', '')
            value = field.get('ValueDetection', {}).get('Text', '')

            if field_type == 'TOTAL':
                receipt_data['total'] = value
            elif field_type == 'INVOICE_RECEIPT_DATE':
                receipt_data['date'] = value
            elif field_type == 'VENDOR_NAME':
                receipt_data['vendor'] = value

        for group in expense_doc.get('LineItemGroups', []):
            for line_item in group.get('LineItems', []):
                item = {}
                for field in line_item.get('LineItemExpenseFields', []):
                    field_type = field.get('Type', {}).get('Text', '')
                    value = field.get('ValueDetection', {}).get('Text', '')

                    if field_type == 'ITEM':
                        item['name'] = value
                    elif field_type == 'PRICE':
                        item['price'] = value
                    elif field_type == 'QUANTITY':
                        item['quantity'] = value

                if 'name' in item:
                    receipt_data['items'].append(item)

    print(f"Extracted receipt data: {json.dumps(receipt_data)}")
    return receipt_data

def store_receipt_in_dynamodb(receipt_data):
    """Store the extracted receipt data in DynamoDB."""
    try:
        table = dynamodb.Table(DYNAMODB_TABLE)
        items_for_db = [
            {
                'name': item.get('name', 'Unknown Item'),
                'price': item.get('price', '0.00'),
                'quantity': item.get('quantity', '1')
            }
            for item in receipt_data['items']
        ]

        db_item = {
            'receiptId': receipt_data['receiptId'],  # Changed to match DynamoDB schema
            'date': receipt_data['date'],
            'vendor': receipt_data['vendor'],
            'total': receipt_data['total'],
            'items': items_for_db,
            's3_path': receipt_data['s3_path'],
            'processed_timestamp': datetime.now().isoformat()
        }

        table.put_item(Item=db_item)
        print(f"Receipt data stored in DynamoDB: {receipt_data['receiptId']}")
    except Exception as e:
        print(f"Error storing data in DynamoDB: {str(e)}")
        raise

def get_spending_history(days=30):
    """Retrieve spending history from DynamoDB for the last N days."""
    try:
        table = dynamodb.Table(DYNAMODB_TABLE)
        cutoff_date = (datetime.now() - timedelta(days=days)).isoformat()

        response = table.scan(
            FilterExpression='processed_timestamp > :cutoff',
            ExpressionAttributeValues={':cutoff': cutoff_date}
        )

        return response.get('Items', [])
    except Exception as e:
        print(f"Error retrieving spending history: {str(e)}")
        return []

def calculate_spending_analytics(current_receipt, history):
    """Calculate spending baselines and analytics."""
    try:
        # Clean vendor name
        current_vendor = ' '.join(current_receipt['vendor'].split())
        current_total = float(current_receipt['total'])

        # Group by vendor
        vendor_totals = defaultdict(list)
        item_prices = defaultdict(list)

        for receipt in history:
            vendor = ' '.join(receipt['vendor'].split())
            total = float(receipt['total'])
            vendor_totals[vendor].append(total)

            # Track item prices
            for item in receipt.get('items', []):
                item_name = item['name'].upper()
                try:
                    price = float(item['price'])
                    item_prices[item_name].append({
                        'price': price,
                        'vendor': vendor
                    })
                except:
                    pass

        # Calculate analytics
        analytics = {
            'current_total': current_total,
            'current_vendor': current_vendor,
            'total_receipts': len(history),
            'vendor_stats': {},
            'item_comparisons': [],
            'overall_average': sum(float(r['total']) for r in history) / len(history) if history else 0
        }

        # Vendor-specific stats
        for vendor, totals in vendor_totals.items():
            analytics['vendor_stats'][vendor] = {
                'count': len(totals),
                'average': sum(totals) / len(totals),
                'min': min(totals),
                'max': max(totals)
            }

        # Item price comparisons for current receipt
        for item in current_receipt.get('items', []):
            item_name = item['name'].upper()
            if item_name in item_prices:
                historical = item_prices[item_name]
                try:
                    current_price = float(item['price'])
                    avg_price = sum(h['price'] for h in historical) / len(historical)

                    # Find cheaper vendors
                    cheaper_vendors = [
                        h for h in historical
                        if h['price'] < current_price and h['vendor'] != current_vendor
                    ]

                    if cheaper_vendors:
                        cheapest = min(cheaper_vendors, key=lambda x: x['price'])
                        analytics['item_comparisons'].append({
                            'item': item['name'],
                            'current_price': current_price,
                            'cheaper_at': cheapest['vendor'],
                            'cheaper_price': cheapest['price'],
                            'savings': current_price - cheapest['price']
                        })
                except:
                    pass

        return analytics
    except Exception as e:
        print(f"Error calculating analytics: {str(e)}")
        return {}

def generate_ai_insights(receipt_data, analytics):
    """Use Bedrock/Claude to generate intelligent spending insights."""
    try:
        # Create prompt for Claude
        prompt = f"""You are a personal grocery spending analyst. Analyze this receipt and provide helpful, actionable insights.

Current Receipt:
- Vendor: {receipt_data['vendor']}
- Total: ${receipt_data['total']}
- Date: {receipt_data['date']}
- Items: {json.dumps(receipt_data['items'], indent=2)}

Historical Analytics:
- Total past receipts (last 30 days): {analytics.get('total_receipts', 0)}
- Overall average spend: ${analytics.get('overall_average', 0):.2f}
- Current vendor average: ${analytics.get('vendor_stats', {}).get(analytics.get('current_vendor', ''), {}).get('average', 0):.2f}

Item Price Comparisons:
{json.dumps(analytics.get('item_comparisons', []), indent=2)}

Provide 3-4 bullet points with:
1. A quick reaction to this purchase (over/under budget, good/bad timing)
2. Store comparison insights if available
3. Specific item-level savings opportunities
4. One actionable tip for next time

Be encouraging but honest. Use emojis sparingly. Keep it concise and friendly."""

        # Call Bedrock (using Claude 3.5 Sonnet)
        response = bedrock.invoke_model(
            modelId='anthropic.claude-3-5-sonnet-20240620-v1:0',
            contentType='application/json',
            accept='application/json',
            body=json.dumps({
                'anthropic_version': 'bedrock-2023-05-31',
                'max_tokens': 500,
                'messages': [
                    {
                        'role': 'user',
                        'content': prompt
                    }
                ]
            })
        )

        response_body = json.loads(response['body'].read())
        insights = response_body['content'][0]['text']

        print(f"AI Insights generated: {insights}")
        return insights

    except Exception as e:
        print(f"Error generating AI insights: {str(e)}")
        return "Unable to generate insights at this time. Check your spending history in the AWS console."

def send_email_notification(receipt_data, ai_insights=None):
    """Send an email notification with receipt details and AI insights."""
    try:
        # Clean vendor name for subject line (remove newlines and extra spaces)
        vendor_clean = ' '.join(receipt_data['vendor'].split())

        # Truncate vendor name if too long for subject
        if len(vendor_clean) > 50:
            vendor_clean = vendor_clean[:47] + '...'

        items_html = "".join(
            f"<li>{item.get('name', 'Unknown Item')} - ${item.get('price', 'N/A')} x {item.get('quantity', '1')}</li>"
            for item in receipt_data['items']
        ) or "<li>No items detected</li>"

        # Format AI insights for HTML
        insights_html = ""
        if ai_insights:
            # Convert markdown-style bullets to HTML
            insights_formatted = ai_insights.replace('\n', '<br>')
            insights_html = f"""
            <div style="background-color: #f0f9ff; border-left: 4px solid #3b82f6; padding: 15px; margin: 20px 0;">
                <h3 style="color: #1e40af; margin-top: 0;">💡 Spending Insights</h3>
                <div style="color: #1e3a8a; line-height: 1.6;">
                    {insights_formatted}
                </div>
            </div>
            """

        html_body = f"""
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; color: #333; }}
                .header {{ background-color: #3b82f6; color: white; padding: 20px; border-radius: 8px; }}
                .summary {{ background-color: #f9fafb; padding: 15px; border-radius: 8px; margin: 20px 0; }}
                .amount {{ font-size: 24px; font-weight: bold; color: #059669; }}
            </style>
        </head>
        <body>
            <div class="header">
                <h2 style="margin: 0;">Receipt Processed!</h2>
                <p style="margin: 5px 0 0 0; opacity: 0.9;">{vendor_clean} - {receipt_data['date']}</p>
            </div>

            {insights_html}

            <div class="summary">
                <p><strong>Total:</strong> <span class="amount">${receipt_data['total']}</span></p>
                <p><strong>Vendor:</strong> {receipt_data['vendor']}</p>
                <p><strong>Receipt ID:</strong> {receipt_data['receiptId']}</p>
            </div>

            <h3>Items Purchased:</h3>
            <ul>
                {items_html}
            </ul>

            <p style="color: #6b7280; font-size: 12px; margin-top: 30px;">
                Receipt stored securely in your account. View all receipts in your DynamoDB console.
            </p>
        </body>
        </html>
        """

        ses.send_email(
            Source=SES_SENDER_EMAIL,
            Destination={'ToAddresses': [SES_RECIPIENT_EMAIL]},
            Message={
                'Subject': {'Data': f"Receipt Processed: {vendor_clean} - ${receipt_data['total']}"},
                'Body': {'Html': {'Data': html_body}}
            }
        )
        print(f"Email notification sent to {SES_RECIPIENT_EMAIL}")
    except Exception as e:
        print(f"Error sending email notification: {str(e)}")
        print("Continuing execution despite email error")
