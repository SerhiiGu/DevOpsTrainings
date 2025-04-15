import os

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME', 'todo_db'),
        'USER': os.getenv('DB_USER', 'todo_user'),
        'PASSWORD': os.getenv('DB_PASSWORD', 'todo_pass'),
        'HOST': os.getenv('DB_HOST', 'db'),
        'PORT': os.getenv('DB_PORT', 5432),
    }
}
