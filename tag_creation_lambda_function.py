import boto3
import json

ec2_client = boto3.client('ec2')

# Define the tags that should be applied
DEFAULT_TAGS = [
    {"Key": "Team", "Value": "Null"},
    {"Key": "Project", "Value": "Null"},
    {"Key": "Owner-Email", "Value": "Null"},
    {"Key": "TTL", "Value": "2"},
    {"Key": "CreatedThrough", "Value": "Null"},
    {"Key": "Manager-Email", "Value": "Null"}
]

def lambda_handler(event, context):
    try:
        print(f"Received event: {json.dumps(event)}")

        # Extract instance ID from event
        for record in event['detail']['responseElements']['instancesSet']['items']:
            instance_id = record['instanceId']
            print(f"Tagging instance: {instance_id}")

            # Apply tags
            ec2_client.create_tags(Resources=[instance_id], Tags=DEFAULT_TAGS)

            print(f"Successfully tagged instance {instance_id}")

    except Exception as e:
        print(f"Error tagging instance: {str(e)}")
