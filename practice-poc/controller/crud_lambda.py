import json
import boto3
from boto3.dynamodb.conditions import Key

# Initialize DynamoDB resource
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('demo_table')  # Replace with your table name

def lambda_handler(event, context):
    http_method = event['httpMethod']
    
    if http_method == 'GET':
        # Read item
        item_id = event['queryStringParameters']['id']
        response = table.get_item(Key={'id': item_id})
        return {
            'statusCode': 200,
            'body': json.dumps(response.get('Item', {}))
        }

    elif http_method == 'POST':
        # Create item
        item = json.loads(event['body'])
        table.put_item(Item=item)
        return {
            'statusCode': 201,
            'body': json.dumps({'message': 'Item created'})
        }

    elif http_method == 'PUT':
        # Update item
        item = json.loads(event['body'])
        table.put_item(Item=item)  # Overwrites existing item
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Item updated'})
        }

    elif http_method == 'DELETE':
        # Delete item
        item_id = event['queryStringParameters']['id']
        table.delete_item(Key={'id': item_id})
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Item deleted'})
        }

    else:
        return {
            'statusCode': 400,
            'body': json.dumps({'message': 'Unsupported method'})
        }
