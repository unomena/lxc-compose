from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.core.cache import cache
from django.utils import timezone
from tasks.tasks import sample_task, database_task
from tasks.models import TaskResult
import json

def index(request):
    """Main index page with task submission form"""
    return render(request, 'index.html')

def health(request):
    """Health check endpoint"""
    return JsonResponse({
        'status': 'healthy',
        'service': 'django-celery-sample',
        'timestamp': timezone.now().isoformat()
    })

@csrf_exempt
def submit_task(request):
    """Submit a task to Celery"""
    if request.method == 'POST':
        data = json.loads(request.body)
        task_type = data.get('type', 'sample')
        task_name = data.get('name', 'test_task')
        
        if task_type == 'sample':
            task = sample_task.delay(task_name)
        elif task_type == 'database':
            count = data.get('count', 5)
            task = database_task.delay(count)
        else:
            return JsonResponse({'error': 'Invalid task type'}, status=400)
        
        return JsonResponse({
            'task_id': task.id,
            'status': 'submitted',
            'message': f'Task {task_name} submitted successfully'
        })
    
    return JsonResponse({'error': 'POST method required'}, status=405)

def task_status(request, task_id):
    """Check task status"""
    from celery.result import AsyncResult
    
    result = AsyncResult(task_id)
    return JsonResponse({
        'task_id': task_id,
        'status': result.status,
        'result': str(result.result) if result.result else None
    })

def list_tasks(request):
    """List recent tasks from database"""
    tasks = TaskResult.objects.all()[:20]
    return JsonResponse({
        'tasks': [
            {
                'id': t.id,
                'name': t.name,
                'status': t.status,
                'result': t.result,
                'created': t.created_at.isoformat()
            } for t in tasks
        ]
    })