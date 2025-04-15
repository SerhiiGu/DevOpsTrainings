#!/bin/bash

# Wait for DB
echo "Waiting for PostgreSQL..."
while ! python -c "import psycopg2; psycopg2.connect(host='$DB_HOST', port=$DB_PORT, dbname='$DB_NAME', user='$DB_USER', password='$DB_PASSWORD')" > /dev/null 2>&1; do
  sleep 0.5
done

echo "PostgreSQL started"

# Make, run migrations and start app
python manage.py makemigrations
python manage.py migrate
python manage.py collectstatic --noinput
exec "$@"

