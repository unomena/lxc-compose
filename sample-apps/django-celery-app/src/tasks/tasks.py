from celery import shared_task
from django.core.cache import cache
from django.utils import timezone
import time
import random

@shared_task
def sample_task(task_name):
    """Sample task that simulates work and stores result in database"""
    # Simulate some work
    time.sleep(random.randint(2, 5))
    
    # Store in cache
    cache.set(f'task_{task_name}', {
        'status': 'completed',
        'timestamp': timezone.now().isoformat(),
        'result': f'Task {task_name} completed successfully!'
    }, timeout=300)
    
    return f"Task {task_name} completed at {timezone.now()}"

@shared_task
def database_task(record_count=10):
    """Task that interacts with database"""
    from tasks.models import TaskResult
    
    results = []
    for i in range(record_count):
        result = TaskResult.objects.create(
            name=f"Task_{i}",
            status="completed",
            result=f"Processed record {i}"
        )
        results.append(result.id)
        time.sleep(0.5)
    
    return f"Created {len(results)} task records"

@shared_task
def periodic_cleanup():
    """Periodic task to clean old records"""
    from tasks.models import TaskResult
    from datetime import timedelta
    
    cutoff = timezone.now() - timedelta(hours=24)
    deleted = TaskResult.objects.filter(created_at__lt=cutoff).delete()
    return f"Cleaned up {deleted[0]} old records"