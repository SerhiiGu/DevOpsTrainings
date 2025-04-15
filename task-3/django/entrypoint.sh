#!/bin/bash

# Wait for DB
echo "Waiting for PostgreSQL..."
while ! python -c "import psycopg2; psycopg2.connect(host='$SQL_HOST', port=$SQL_PORT, dbname='postgres', user='postgres', password='password')" > /dev/null 2>&1; do
  sleep 0.5
done

echo "PostgreSQL started"

# Run migrations and start app
python manage.py migrate
python manage.py collectstatic --noinput
exec "$@"

