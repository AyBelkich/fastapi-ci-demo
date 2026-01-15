# 1) Start from a small Python image
FROM python:3.13-slim

# 2) Create a working folder inside the container
WORKDIR /app

# 3) Copy only requirements first (better caching)
COPY requirements.txt requirements.txt

# 4) Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# 5) Copy the rest of your code into the container
COPY . .

# 6) Run the API server
# IMPORTANT: host 0.0.0.0 makes it accessible outside the container
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
