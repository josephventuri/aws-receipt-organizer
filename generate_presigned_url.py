import json
import boto3
import uuid
from datetime import datetime

# Initialize S3 client with explicit region and signature version
s3_client = boto3.client(
    's3',
    region_name='us-west-1',
    config=boto3.session.Config(signature_version='s3v4')
)
BUCKET_NAME = 'jv-aro-dev-usw1-receipts'

def handler(event, context):
    """Generate a pre-signed URL for uploading receipt images to S3."""

    # Enable CORS
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'POST,OPTIONS'
    }

    # Handle preflight OPTIONS request
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': headers,
            'body': ''
        }

    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        file_type = body.get('fileType', 'image/jpeg')

        # Generate unique filename
        timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
        unique_id = str(uuid.uuid4())[:8]
        file_extension = file_type.split('/')[-1]
        if file_extension == 'jpeg':
            file_extension = 'jpg'

        filename = f"receipts/{timestamp}-{unique_id}.{file_extension}"

        # Generate pre-signed URL (valid for 5 minutes)
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': filename,
                'ContentType': file_type
            },
            ExpiresIn=300  # 5 minutes
        )

        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'uploadUrl': presigned_url,
                'filename': filename
            })
        }

    except Exception as e:
        print(f"Error generating pre-signed URL: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }
