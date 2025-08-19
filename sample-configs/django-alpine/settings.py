# Database configuration
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'djangodb',
        'USER': 'djangouser',
        'PASSWORD': 'djangopass',
        'HOST': '10.0.3.30',
        'PORT': '5432',
    }
}

# Redis cache
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': 'redis://10.0.3.30:6379',
    }
}

# Celery configuration
CELERY_BROKER_URL = 'redis://10.0.3.30:6379/0'
CELERY_RESULT_BACKEND = 'redis://10.0.3.30:6379/0'

ALLOWED_HOSTS = ['*']
STATIC_ROOT = '/app/static'