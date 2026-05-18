import os
import json
import boto3

sns_client = boto3.client('sns')

def handler(event, context):
    print("--- EMAIL DIAGNOSTIC ROUTER ACTIVATED ---")
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
    
    detail = event.get('detail', {})
    alarm_name = detail.get('alarmName', 'Unknown Incident Outage')
    new_state = detail.get('state', {}).get('value', 'UNKNOWN')
    reason = detail.get('state', {}).get('reason', 'No operational summary provided.')
    
    email_body = (
        f"🚨 MAJOR INCIDENT CRITICAL ALERT 🚨\n"
        f"=========================================\n\n"
        f"A critical system threshold breach has occurred within production boundaries.\n\n"
        f"--- INCIDENT METADATA ---\n"
        f"📌 Alarm Name        : {alarm_name}\n"
        f"⚠️ Current Status    : {new_state}\n"
        f"🌐 Target Region      : {event.get('region', 'N/A')}\n"
        f"🆔 AWS Account ID     : {event.get('account', 'N/A')}\n"
        f"⏰ Trigger Timestamp  : {event.get('time', 'N/A')}\n\n"
        f"--- DIAGNOSTIC SUMMARY ---\n"
        f"{reason}\n\n"
        f"=========================================\n"
        f"Actions Taken: Automated Remediation Runbooks have been concurrently invoked.\n"
        f"Source: Event-Driven Infrastructure Response Engine (Managed via Terraform & Verified via GitHub Actions CI)"
    )
    
    try:
        response = sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=f"🚨 MIM [CRITICAL]: {alarm_name} transitioned to {new_state}",
            Message=email_body
        )
        print(f"Successfully published alert. Message ID: {response['MessageId']}")
        return {"status": "success", "message_id": response['MessageId']}
    except Exception as e:
        print(f"ERROR: Failed to transmit diagnostic notification: {str(e)}")
        raise e