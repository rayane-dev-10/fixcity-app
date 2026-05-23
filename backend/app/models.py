from django.contrib.gis.db import models
from django.contrib.gis.db import models
from .enums import Wilaya, Commune, StatutSignalement
# Create your models here.
from django.contrib.auth.models import BaseUserManager,AbstractUser


class MyUserManager(BaseUserManager):
    def create_user(self, email, password, **extra_fields):
        if not email or not password:
            raise ValueError("L'adresse mail et mot de passe sont obligatoires")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)

        '''if extra_fields.get('is_staff') is not True:
            raise ValueError('Le superuser doit avoir is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Le superuser doit avoir is_superuser=True.')'''

        return self.create_user(email, password, **extra_fields)

class User(AbstractUser):
    username=None
    email = models.EmailField(unique=True)
    is_citoyen=models.BooleanField(default=False)
    is_app_admin=models.BooleanField(default=False) 

    # On définit l'email comme identifiant principal à la place de username
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name','last_name'] 

    objects = MyUserManager()

    def __str__(self):
        return self.email
   

class Organisation(models.Model):
    nom = models.CharField(max_length=100,unique=True)
    categories=models.ManyToManyField('CategorieIncident')

    def __str__(self):
        return self.nom
    
    


class CategorieIncident(models.Model):
    nom = models.CharField(max_length=100,unique=True)

    def __str__(self):
        return self.nom


class Siege(models.Model):
    nom = models.CharField(max_length=100,unique=True)
    localisation = models.PointField(srid=4326) 
    commune = models.CharField(max_length=40, choices=Commune.choices)
    wilaya = models.CharField(max_length=40, choices=Wilaya.choices)
    organisation = models.ForeignKey(Organisation, on_delete=models.CASCADE)

    def __str__(self):
        return self.nom


class Admin(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    siege = models.OneToOneField(Siege, on_delete=models.CASCADE, related_name='admin')# related_name permet d'accéder à l'admin d'un siège à partir du modèle Siege (siege.admin)



class Citoyen(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)

    def __str__(self):
        return str(self.user.email)



class Signalement(models.Model):
    localisation = models.PointField(srid=4326)
    adresseLisible = models.CharField(max_length=255)
    commune = models.CharField(max_length=40, choices=Commune.choices)
    wilaya = models.CharField(max_length=40, choices=Wilaya.choices)
    url_image = models.URLField()
    description = models.TextField(blank=True,null=True,default="")
    statut = models.CharField(max_length=20, choices=StatutSignalement.choices, default=StatutSignalement.EN_COURS)
    date_envoi = models.DateTimeField(auto_now_add=True)
    categorie = models.ForeignKey(CategorieIncident, on_delete=models.CASCADE)
    citoyen = models.ForeignKey(Citoyen, on_delete=models.CASCADE)
    siege = models.ForeignKey(Siege, on_delete=models.CASCADE)



class UserDevice(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    deviceToken = models.TextField(unique=True) 
    type = models.CharField(max_length=10, choices=(('android', 'Android'), ('ios', 'iOS')))
    created_at = models.DateTimeField(auto_now_add=True)



    
    