FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN chmod +x entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]

# CMD ["gunicorn", "todo_project.wsgi:application", "--bind", "0.0.0.0:8000"]
CMD ["gunicorn", "todo_project.wsgi:application", "--bind 0.0.0.0:8000", "--workers 3", "--worker-class gthread", "--threads 4", "--timeout 10", "--log-level debug"]
