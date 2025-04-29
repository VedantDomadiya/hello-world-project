import os
import json
import boto3
import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)

def get_db_credentials():
    """Retrieves database credentials from AWS Secrets Manager."""
    secret_name = os.environ.get("DB_SECRET_ARN") # Get ARN from env var set in Task Definition
    region_name = os.environ.get("AWS_REGION", "ap-south-1") # Get region

    if not secret_name:
        raise ValueError("DB_SECRET_ARN environment variable not set.")

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except Exception as e:
        print(f"Error retrieving secret: {e}")
        raise e
    else:
        # Decrypts secret using the associated KMS key.
        # Depending on whether the secret is a string or binary, one of these fields will be populated.
        if 'SecretString' in get_secret_value_response:
            secret = get_secret_value_response['SecretString']
            return json.loads(secret)
        else:
            # Handle binary secret if necessary (less common for simple credentials)
            # decoded_binary_secret = base64.b64decode(get_secret_value_response['SecretBinary'])
            raise ValueError("Secret format not supported (expected SecretString).")


@app.route('/')
def hello():
    return "<h1>Hello World from ECS (with DB check)!</h1><p>Visit /db-check to verify database connection.</p>"

@app.route('/db-check')
def db_check():
    """Attempts to connect to the database and returns status."""
    credentials = None
    connection = None
    try:
        print("Fetching DB credentials...")
        credentials = get_db_credentials()
        print("Credentials fetched successfully.")

        print(f"Attempting to connect to database '{credentials['dbname']}' at {credentials['host']}:{credentials['port']}...")

        connection = psycopg2.connect(
            host=credentials['host'],
            port=credentials['port'],
            dbname=credentials['dbname'],
            user=credentials['username'],
            password=credentials['password'],
            connect_timeout=5 # Add a timeout
        )

        # If connection is successful
        print("Database connection successful!")
        cursor = connection.cursor()
        cursor.execute("SELECT version();")
        db_version = cursor.fetchone()
        cursor.close()

        return jsonify({
            "status": "SUCCESS",
            "message": "Successfully connected to the database.",
            "db_version": db_version[0] if db_version else "N/A"
        })

    except ValueError as e:
         print(f"Configuration error: {e}")
         return jsonify({"status": "ERROR", "message": f"Configuration error: {e}"}), 500
    except psycopg2.OperationalError as e:
        print(f"Database connection failed: {e}")
        # Provide minimal error info externally for security
        error_detail = f"Could not connect to DB '{credentials.get('dbname', 'unknown')}' on host '{credentials.get('host', 'unknown')}'." if credentials else "Credentials missing."
        return jsonify({"status": "ERROR", "message": f"Database connection failed. Details: {error_detail}"}), 503 # Service Unavailable
    except Exception as e:
         print(f"An unexpected error occurred: {e}")
         return jsonify({"status": "ERROR", "message": f"An unexpected error occurred: {e}"}), 500
    finally:
        if connection:
            connection.close()
            print("Database connection closed.")


if __name__ == '__main__':
    # Run Flask on port 80 to match Task Definition and SG
    app.run(host='0.0.0.0', port=80)