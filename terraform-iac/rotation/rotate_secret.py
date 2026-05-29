import boto3
import json


def lambda_handler(event, context):
    client = boto3.client("secretsmanager")
    arn = event["SecretId"]
    client.put_secret_value(
        SecretId=arn,
        SecretString=json.dumps({"token": "REPLACE_ME"}),
    )
    return {"statusCode": 200, "body": "rotation placeholder complete"}
