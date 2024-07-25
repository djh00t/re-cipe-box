FROM python:3.9-slim

# Install necessary dependencies
RUN pip install fastapi uvicorn requests sqlalchemy pymysql alembic

# Set environment variables
ENV TMDB_API_KEY=""
ENV MYSQL_HOST=""
ENV MYSQL_PORT=""
ENV MYSQL_USER=""
ENV MYSQL_PASSWORD=""
ENV MYSQL_DB=""

# Copy the application code
COPY . /app

# Set the working directory
WORKDIR /app

# Expose port 8000
EXPOSE 8000

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
