from django.db import models

class TaskResult(models.Model):
    name = models.CharField(max_length=100)
    status = models.CharField(max_length=20, default='pending')
    result = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.name} - {self.status}"