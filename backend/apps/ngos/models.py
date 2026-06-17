from django.db import models


class NGO(models.Model):
    name = models.CharField(max_length=255)
    registration_no = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    address = models.CharField(max_length=255, blank=True)
    contact = models.CharField(max_length=100, blank=True)
    logo = models.ImageField(upload_to="ngo_logos/", blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "ngos"
        ordering = ["name"]
        verbose_name = "NGO"
        verbose_name_plural = "NGOs"

    def __str__(self):
        return self.name
