from django.utils import timezone

from django.contrib.gis.db import models
from .enums import Wilaya, Commune, Statut
# Create your models here.
from django.contrib.auth.models import BaseUserManager,AbstractUser


class MyUserManager(BaseUserManager):
    def create_user(self, email, password, **extra_fields):
        if not email or not password:
            raise ValueError("L'adresse email et mot de passe sont obligatoires")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)

        return self.create_user(email, password, **extra_fields)



class Categorie(models.Model):
    nom = models.CharField(max_length=100,unique=True)

    def __str__(self):
        return self.nom



class ServicePublique(models.Model):
    nom = models.CharField(max_length=100)
    localisation = models.PointField(srid=4326) 
    commune = models.CharField(max_length=40, choices=Commune.choices)
    wilaya = models.CharField(max_length=40, choices=Wilaya.choices)
    categories=models.ManyToManyField('Categorie')

    def __str__(self):
        return self.nom    

class Utilisateur(AbstractUser):
    username=None
    email = models.EmailField(unique=True)
    is_citoyen=models.BooleanField(default=False)
    is_agent=models.BooleanField(default=False)
    service = models.OneToOneField(ServicePublique, on_delete=models.CASCADE, related_name='agent',null=True,blank=True,default=None)

    # On définit l'email comme identifiant principal à la place de username
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name','last_name'] 

    objects = MyUserManager()

    def __str__(self):
        return self.email
   

        

class IncidentUrbain(models.Model):
    localisation = models.PointField(srid=4326)
    adresseLisible = models.CharField(max_length=255)
    commune = models.CharField(max_length=40, choices=Commune.choices)
    wilaya = models.CharField(max_length=40, choices=Wilaya.choices)
    url_image = models.URLField()
    description = models.TextField(blank=True,null=True,default="")
    statut = models.CharField(max_length=20, choices=Statut.choices, default=Statut.NOUVEAU)
    date_signalement = models.DateTimeField(auto_now_add=True)
    categorie = models.ForeignKey(Categorie, on_delete=models.CASCADE)
    citoyen = models.ForeignKey(Utilisateur, on_delete=models.CASCADE)
    service = models.ForeignKey(ServicePublique, on_delete=models.CASCADE)


class OTP(models.Model):
    email=models.EmailField()
    hached_otp = models.CharField(max_length=128, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(null=True)


    def is_expired(self):
        return timezone.now() >= self.expires_at
    
    def setExpiration(self, minutes):
        self.expires_at = self.created_at + timezone.timedelta(minutes=minutes)


    
    