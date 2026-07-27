import json
from datetime import datetime, timezone


def lambda_handler(event, context):
    """Small working FaaS endpoint used to verify the AWS Lambda deployment."""
    request_context = event.get("requestContext", {}) if isinstance(event, dict) else {}
    http_context = request_context.get("http", {})

    response = {
        "service": "devcloud-faas",
        "status": "ready",
        "request_id": getattr(context, "aws_request_id", None),
        "method": http_context.get("method", "UNKNOWN"),
        "path": event.get("rawPath", "/") if isinstance(event, dict) else "/",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(response),
    }
