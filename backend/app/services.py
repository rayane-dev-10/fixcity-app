from .models import CategorieIncident,Organisation ,Siege
from django.contrib.gis.db.models.functions import Distance
def get_siege_plus_proche(validated_data):
    categorie=CategorieIncident.objects.get(nom=validated_data['categorie'])
    organisations=Organisation.objects.filter(categories=categorie)
    sieges = Siege.objects.filter(organisation__in=organisations).annotate(
        distance=Distance('localisation', validated_data['localisation'])
    ).order_by('distance')

    return sieges.first()


def Completer_champs(request,validated_data):
    validated_data['citoyen']=request.user.citoyen
    validated_data['siege']=get_siege_plus_proche(validated_data)

    return validated_data