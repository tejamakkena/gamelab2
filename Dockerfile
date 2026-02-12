
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y     build-essential     curl     software-properties-common     git     && rm -rf /var/lib/apt/lists/*

# Copy project files
COPY . /app

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install development dependencies
RUN pip install --no-cache-dir -r dev-requirements.txt

# Add development tools
RUN pip install     pylint     pytest     coverage     bandit

# Set environment variables
ENV FLASK_APP=app.py
ENV FLASK_ENV=development

# Expose application port
EXPOSE 5000

# Run the application
CMD ["flask", "run", "--host=0.0.0.0"]
