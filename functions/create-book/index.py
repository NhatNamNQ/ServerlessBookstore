import boto3
import json
import base64
import io
import cgi
import os
import urllib.request
from urllib.parse import urlparse
from decimal import Decimal

s3 = boto3.client('s3')
client = boto3.resource('dynamodb')
runtime_region = os.environ.get('AWS_REGION', 'ap-southeast-1')

SOURCE_BUCKET = os.environ.get('SOURCE_BUCKET', 'bookstore-dev-book-images-source')
DEST_BUCKET = os.environ.get('DESTINATION_BUCKET', 'bookstore-dev-book-images-resized')
TABLE_NAME = os.environ.get('TABLE_NAME', 'bookstore-dev-books')

def get_data_from_request_body(content_type, body):
    fp = io.BytesIO(base64.b64decode(body))
    environ = {"REQUEST_METHOD": "POST"}
    headers = {
        "content-type": content_type,
        "content-length": len(body),
    }

    fs = cgi.FieldStorage(fp=fp, environ=environ, headers=headers) 
    return [fs, None]

def download_image_from_url(image_url):
    """Download image từ URL sử dụng urllib"""
    try:
        with urllib.request.urlopen(image_url, timeout=10) as response:
            return response.read()
    except Exception as e:
        print(f"Error downloading image: {str(e)}")
        return None

def get_filename_from_url(image_url):
    """Extract filename từ URL"""
    parsed_url = urlparse(image_url)
    filename = os.path.basename(parsed_url.path)
    return filename if filename else 'image.jpg'

def lambda_handler(event, context):
    try:
        print(f"DEBUG EVENT: {json.dumps(event, default=str)}")
        
        # Safe header access
        headers = event.get('headers') or {}
        content_type = headers.get('Content-Type', '') or headers.get('content-type', '') or 'application/json'
        
        # Safe body access
        body = event.get('body')
        is_base64 = event.get('isBase64Encoded', False)
        
        print(f"Content-Type: {content_type}")
        print(f"Body exists: {body is not None}")

        # Check body exists
        if not body:
            if 'id' in event and 'name' in event:
                body = json.dumps(event)
            else:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'No request body found'}),
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    }
                }

        # Handle JSON
        if 'application/json' in content_type:
            if isinstance(body, str):
                book_item = json.loads(body)
            else:
                book_item = body
            
            # ✅ FIX: Convert price to Decimal
            if book_item.get('price'):
                book_item['price'] = Decimal(str(book_item['price']))
            
            # Handle image URL
            if book_item.get('image') and book_item['image'].startswith('http'):
                print(f"Downloading image from: {book_item['image']}")
                image_data = download_image_from_url(book_item['image'])
                if image_data:
                    filename = get_filename_from_url(book_item['image'])
                    s3.put_object(Bucket=SOURCE_BUCKET, Key=filename, Body=image_data)
                    book_item['image'] = f"https://{DEST_BUCKET}.s3.{runtime_region}.amazonaws.com/{filename}"
        
        # Handle Multipart Form Data
        elif 'multipart/form-data' in content_type:
            if is_base64 and isinstance(body, str):
                body_bytes = base64.b64decode(body)
            elif isinstance(body, str):
                body_bytes = body.encode('utf-8')
            else:
                body_bytes = body
            
            fp = io.BytesIO(body_bytes)
            environ = {"REQUEST_METHOD": "POST"}
            headers_dict = {"content-type": content_type}
            
            fs = cgi.FieldStorage(fp=fp, environ=environ, headers=headers_dict)
            
            book_item = {
                "id": fs.getvalue('id', ''),
                "rv_id": int(fs.getvalue('rv_id', 0)),
                "name": fs.getvalue('name', ''),
                "author": fs.getvalue('author', ''),
                "price": Decimal(str(fs.getvalue('price', 0))),  # ✅ Convert to Decimal
                "category": fs.getvalue('category', ''),
                "description": fs.getvalue('description', ''),
            }
            
            # Handle image file
            if 'image' in fs and fs['image'].filename:
                image_data = fs['image'].value
                filename = fs['image'].filename
                s3.put_object(Bucket=SOURCE_BUCKET, Key=filename, Body=image_data)
                book_item['image'] = f"https://{DEST_BUCKET}.s3.{runtime_region}.amazonaws.com/{filename}"
        
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Unsupported Content-Type: {content_type}'}),
                'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'}
            }

        # Save to DynamoDB
        table = client.Table(TABLE_NAME)
        table.put_item(Item=book_item)

        return {
            'statusCode': 201,
            'body': json.dumps(book_item, default=str),  # ✅ default=str để serialize Decimal
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET,PUT,POST,DELETE,OPTIONS'
            },
        }

    except KeyError as e:
        print(f"KeyError: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': f'Missing field: {str(e)}'}),
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'}
        }
    
    except json.JSONDecodeError as e:
        print(f"JSON error: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': f'Invalid JSON: {str(e)}'}),
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'}
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)}),
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'}
        }
