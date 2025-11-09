# Use AWS Lambda Python 3.11 base image
FROM public.ecr.aws/lambda/python:3.11

# Copy requirements
COPY requirements.txt ${LAMBDA_TASK_ROOT}/

# Install dependencies
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Copy function code
COPY generate_presigned_url.py ${LAMBDA_TASK_ROOT}/

# Set the CMD to your handler
CMD ["generate_presigned_url.handler"]
