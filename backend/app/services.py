from config import settings
import random
from .models import ServicePublique
from django.contrib.gis.db.models.functions import Distance
from django.core.mail import send_mail
from django.contrib.auth.hashers import make_password
from django.template.loader import render_to_string
from django.core.mail import EmailMultiAlternatives
from .models import Utilisateur
def get_service_publique(validated_data,localisation):

    services=ServicePublique.objects.filter(categories=validated_data["categorie"],commune=validated_data["commune"]).annotate(
        distance=Distance('localisation', localisation)
    ).order_by('distance')

    if services.exists():
        return services.first()
    else:
        service=ServicePublique.objects.filter(categories=validated_data["categorie"]).annotate(
        distance=Distance('localisation', localisation)
        ).order_by('distance').first()
        return service

    


def completer_champs_incident(request,validated_data,localisation):

    validated_data['citoyen']=request.user
    validated_data['service']=get_service_publique(validated_data,localisation)

    return validated_data


def send_email(email,context,otp=None,incident_id=None):
    if otp is not None and context=="email_verification":
        html_content = render_to_string(
        "mails/confirm-mail-adress.html",
        {
            "otp": otp,
        }
        )

        email_message=EmailMultiAlternatives(
            subject="Confirmez votre adresse mail",
            body="",
            from_email=settings.EMAIL_HOST_USER,
            to=[email],
        )

        email_message.attach_alternative(html_content, "text/html")
        try:
            email_message.send()
            return True
        except Exception as e:
            return False

        
    elif otp is not None and context=="password_reset":
        utilisateur=Utilisateur.objects.get(email=email)
        html_content = render_to_string(
        "mails/reset-password.html",
        {   "userFirstName":utilisateur.first_name,
            "otp": otp,
        }
        )

        email_message=EmailMultiAlternatives(
            subject="Réinitialisation de votre mot de passe",
            body="",
            from_email=settings.EMAIL_HOST_USER,
            to=[email],
        )

        email_message.attach_alternative(html_content, "text/html")
        try:
            email_message.send()
            return True
        except Exception as e:
            return False    

    elif context=="mise_a_jour_statut_incident_en_cours":
        utilisateur=Utilisateur.objects.get(email=email)
        html_content = render_to_string(
        "mails/statut-en_cours-message.html",
        {
            "userFirstName":utilisateur.first_name,
            "incidentId": incident_id
        }
        )

        email_message=EmailMultiAlternatives(
            subject="Mise à jour de votre signalement – En cours de traitement",
            body="",
            from_email=settings.EMAIL_HOST_USER,
            to=[email],
        )

        email_message.attach_alternative(html_content, "text/html")
        try:
            email_message.send()
            return True
        except Exception as e:
            return False 
        
    else:
        utilisateur=Utilisateur.objects.get(email=email)
        html_content = render_to_string(
        "mails/statut-resolu-message.html",
        {
            "userFirstName":utilisateur.first_name,
            "incidentId": incident_id
        }
        )

        email_message=EmailMultiAlternatives(
            subject="Mise à jour de votre signalement – Résolu",
            body="",
            from_email=settings.EMAIL_HOST_USER,
            to=[email],
        )

        email_message.attach_alternative(html_content, "text/html")
        try:
            email_message.send()
            return True
        except Exception as e:
            return False
            
    


            
def generate_unique_otp():
    otp = str(random.randint(100000, 999999))
    hached_otp=make_password(otp)
    return otp, hached_otp

    
    






