# FROM nginx:alpine
# COPY src/index.html /usr/share/nginx/html/index.html
# EXPOSE 80

# Use a Python base image
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Copy requirements file and install dependencies
COPY src/requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY src/app.py .

# Expose the port the app runs on (must match app.run() and Task Def)
EXPOSE 80

# Command to run the application
CMD ["python", "app.py"]