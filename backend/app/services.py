from .models import Organisation ,Siege, UserDevice
from django.contrib.gis.db.models.functions import Distance
from firebase_admin import messaging
def get_siege_plus_proche(validated_data,localisation):
    organisations=Organisation.objects.filter(categories=validated_data["categorie"])
    sieges = Siege.objects.filter(organisation__in=organisations,
                                  commune=validated_data["commune"]).annotate(
        distance=Distance('localisation', localisation)
    ).order_by('distance')
    
    if not sieges.exists():
        sieges = Siege.objects.filter(organisation__in=organisations).annotate(
            distance=Distance('localisation', localisation)
        ).order_by('distance')

    return sieges.first()


def completer_champs_signalement(request,validated_data,localisation):

    validated_data['citoyen']=request.user.citoyen
    validated_data['siege']=get_siege_plus_proche(validated_data,localisation)

    return validated_data



def envoyer_notification(tokens, title, body):
    

    # Construction du message
    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        tokens=tokens,
    )

    # Envoi
    try:
        response = messaging.send_multicast(message)
        # Si certains tokens sont invalides, on les supprime de la base de données
        if response.failure_count > 0:
            tokens_to_delete = []
            for index, resp in enumerate(response.responses):
                # Si le token est invalide ou n'est plus enregistré(expiré), on l'ajoute a la liste des tokens à supprimer
                if not resp.success:
                    if resp.exception.code in ['invalid-registration-token', 'registration-token-not-registered']:
                        tokens_to_delete.append(tokens[index])
    
            if tokens_to_delete:
                deleteUserDevices(tokens_to_delete)

    except Exception as e:
        pass         



def deleteUserDevices(tokens):
    UserDevice.objects.filter(deviceToken__in=tokens).delete()





