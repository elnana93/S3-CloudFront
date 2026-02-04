

import json
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("visitor-counter")

def lambda_handler(event, context):
    response = table.update_item(
        Key={"id": "visits"},
        UpdateExpression="ADD visit_count :inc",
        ExpressionAttributeValues={":inc": 1},
        ReturnValues="UPDATED_NEW"
    )

    count = int(response["Attributes"]["visit_count"])

    return {
        "statusCode": 200,
        "headers": {
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps({"visits": count})
    }
