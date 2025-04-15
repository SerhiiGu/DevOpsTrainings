#!/bin/bash

# Wait for DB
echo "Waiting for PostgreSQL..."
while ! nc -z $SQL_HOST $SQL_PORT; do
  sleep 0.5
done


echo "PostgreSQL started"

# Run migrations and start app
python manage.py migrate
python manage.py collectstatic --noinput
exec "$@"

