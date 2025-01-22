import json
import requests
import os  # Import to access environment variables


def lambda_handler(event, context):
    # Get environment variables
    S3_BUCKET_NAME = os.environ.get("S3_BUCKET_NAME", "test-lambda-bucket")
    LOAD_BALANCER_DNS_NAME = os.environ.get("LOAD_BALANCER_DNS_NAME", "tf-lb-20250121081808914600000014-0f567ae723c8ec89.elb.eu-west-1.amazonaws.com")

    # Extract parameters from the event
    app_resource = event.get("appResource", f"s3a://{S3_BUCKET_NAME}/scripts/submit_spark_job.py")
    main_class = event.get("mainClass", "org.apache.spark.examples.SparkPi")
    app_args = event.get("appArgs", [])
    
    # Spark job submission payload
    payload = {
        "action": "CreateSubmissionRequest",
        "appResource": app_resource,
        "clientSparkVersion": "3.3.1",  # Update based on your cluster version
        "mainClass": main_class,
        "appArgs": app_args,
        "environmentVariables": {
            "SPARK_ENV_LOADED": "1"
        },
        "sparkProperties": {
            "spark.driver.supervise": "false",
            "spark.app.name": "MySparkJob",
            "spark.eventLog.enabled": "true",
            "spark.submit.deployMode": "cluster",
            "spark.master": f"spark://{LOAD_BALANCER_DNS_NAME}:7077"
        }
    }
    
    # Submit the job to Spark REST API
    try:
        response = requests.post(f"http://{LOAD_BALANCER_DNS_NAME}:6066/v1/submissions/create", json=payload, timeout=30)
        response.raise_for_status()
        result = response.json()
        return {
            "statusCode": 200,
            "body": json.dumps(result)
        }
    except requests.exceptions.RequestException as e:
        return {
            "statusCode": 500,
            "body": f"Failed to submit Spark job: {str(e)}"
        }
