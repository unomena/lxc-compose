from django.contrib import admin
from django.urls import path
from api import views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', views.index, name='index'),
    path('api/health/', views.health, name='health'),
    path('api/task/submit/', views.submit_task, name='submit_task'),
    path('api/task/status/<str:task_id>/', views.task_status, name='task_status'),
    path('api/tasks/', views.list_tasks, name='list_tasks'),
]