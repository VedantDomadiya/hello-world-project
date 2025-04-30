import os
import json
import boto3
import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)

def get_db_credentials():
    """Retrieves database credentials from AWS Secrets Manager."""
    secret_name = os.environ.get("DB_SECRET_ARN") # Get ARN from env var set in Task Definition
    region_name = os.environ.get("AWS_REGION", "ap-south-1") # Get region from env var

    print(f"Attempting to fetch secret ARN: {secret_name} in region: {region_name}") # Added print

    if not secret_name:
        raise ValueError("DB_SECRET_ARN environment variable not set.")

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        print(f"Calling Secrets Manager GetSecretValue for SecretId: {secret_name}") # Added print
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
        print("Successfully called GetSecretValue.") # Added print
    except Exception as e:
        print(f"Error retrieving secret: {e}")
        raise e
    else:
        if 'SecretString' in get_secret_value_response:
            secret = get_secret_value_response['SecretString']
            print("SecretString found, parsing JSON.") # Added print
            return json.loads(secret)
        else:
            # Handle binary secret if necessary
            print("Secret format not supported (expected SecretString).") # Added print
            raise ValueError("Secret format not supported (expected SecretString).")


@app.route('/')
def hello():
    return "<h1>Hello World from ECS (with DB check)!</h1><p>Visit /db-check to verify database connection.</p>"

@app.route('/db-check') 
def db_check():
    """Attempts to connect to the database using Secrets Manager and returns status."""
    credentials = None
    connection = None
    try:
        print("Fetching DB credentials via get_db_credentials...")
        credentials = get_db_credentials()
        print(f"Credentials fetched: User={credentials.get('username')}, Host={credentials.get('host')}, DB={credentials.get('dbname')}") # Added print, avoid printing password

        print(f"Attempting to connect to database '{credentials['dbname']}' at {credentials['host']}:{credentials['port']}...")

        connection = psycopg2.connect(
            host=credentials['host'],
            port=credentials['port'],
            dbname=credentials['dbname'],
            user=credentials['username'],
            password=credentials['password'],
            connect_timeout=5 # Add a timeout
        )

        print("Database connection successful!")
        cursor = connection.cursor()
        cursor.execute("SELECT version();")
        db_version = cursor.fetchone()
        cursor.close()
        print(f"DB Version: {db_version[0] if db_version else 'N/A'}") # Added print

        return jsonify({
            "status": "SUCCESS",
            "message": "Successfully connected to the database.",
            "db_version": db_version[0] if db_version else "N/A"
        })

    except ValueError as e:
        print(f"Configuration error (e.g., missing env var): {e}")
        return jsonify({"status": "ERROR", "message": f"Configuration error: {e}"}), 500
    except psycopg2.OperationalError as e:
        print(f"Database connection failed: {e}")
        error_detail = f"Could not connect to DB '{credentials.get('dbname', 'unknown')}' on host '{credentials.get('host', 'unknown')}'." if credentials else "Credentials missing or failed to fetch."
        return jsonify({"status": "ERROR", "message": f"Database connection failed. Details: {error_detail}"}), 503 # Service Unavailable
    except Exception as e:
        print(f"An unexpected error occurred during DB check: {e}")
        return jsonify({"status": "ERROR", "message": f"An unexpected error occurred: {e}"}), 500
    finally:
        if connection:
            connection.close()
            print("Database connection closed.")

# REMOVE THE OLD HARDCODED db_check FUNCTION BELOW THIS LINE

if __name__ == '__main__':
    # Run Flask on port 80 to match Task Definition and SG
    print("Starting Flask application on 0.0.0.0:80") # Added print
    app.run(host='0.0.0.0', port=80)


'''
@app.route('/db-check')
def db_check():
    """Attempts to connect to the database and returns status."""
    # Hardcoded RDS details
    db_config = {
        "host": "hello-world-dev-db.c1m2muqyuj90.ap-south-1.rds.amazonaws.com",
        "port": 5432,
        "dbname": "webappdb",
        "user": "dbadmin",
        "password": "fuFU4CYah4edCmL7"
    }

    connection = None
    try:
        print("Attempting to connect to database...")
        connection = psycopg2.connect(
            host=db_config["host"],
            port=db_config["port"],
            dbname=db_config["dbname"],
            user=db_config["user"],
            password=db_config["password"],
            connect_timeout=5  # Add a timeout
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
    except psycopg2.OperationalError as e:
        print(f"Database connection failed: {e}")
        error_detail = f"Could not connect to DB '{db_config['dbname']}' on host '{db_config['host']}'."
        return jsonify({"status": "ERROR", "message": f"Database connection failed. Details: {error_detail}"}), 503
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return jsonify({"status": "ERROR", "message": f"An unexpected error occurred: {e}"}), 500
    finally:
        if connection:
            connection.close()
            print("Database connection closed.")
'''
