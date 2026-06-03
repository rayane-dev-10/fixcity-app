from rest_framework import serializers
from .models import Utilisateur,IncidentUrbain,Categorie
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .services import completer_champs_incident
from .enums import Wilaya,Commune
from django.contrib.gis.geos.point import Point
from rest_framework.exceptions import AuthenticationFailed
class MyTokenObtainPairSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        data = super().validate(attrs)
        user=self.user
        if user.is_staff or user.is_superuser :
            raise AuthenticationFailed("email ou mot de passe incorrect")
        
        return data
    
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)

        # ajouter des informations personnalisées au token
        token['is_citoyen'] = user.is_citoyen
        token['is_agent']=user.is_agent
        return token


class UtilisateurSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = Utilisateur
        fields = ['id', 'email', 'password', 'first_name', 'last_name']
        read_only_fields = ['id']

    def create(self, validated_data):
        password= validated_data.pop('password')
        utilisateur =Utilisateur.objects.create_user(password=password,**validated_data)
        return utilisateur        


class IncidentUrbainSerializer(serializers.ModelSerializer):
    latitude=serializers.FloatField(write_only=True)
    longitude=serializers.FloatField(write_only=True)
    wilaya = serializers.CharField(write_only=True)
    commune=serializers.CharField(write_only=True)
    nom_commune=serializers.CharField(source='get_commune_display', read_only=True)
    nom_wilaya = serializers.CharField(source='get_wilaya_display', read_only=True)
    date_signalement=serializers.DateTimeField(format='%d/%m/%Y à %H:%M',read_only=True)
    citoyen=serializers.SlugRelatedField(read_only=True,slug_field='email')
    service=serializers.SlugRelatedField(read_only=True,slug_field='nom')
    categorie=serializers.SlugRelatedField(queryset=Categorie.objects.all(),slug_field='nom')
    #champs calclués pour les renvoyer dans la reponse http
    lat = serializers.SerializerMethodField()
    long = serializers.SerializerMethodField()
    class Meta:
        model = IncidentUrbain
        fields = ['id','latitude', 'longitude','lat','long','commune','nom_wilaya','nom_commune', 'wilaya','url_image', 'description', 'statut', 'date_signalement', 'categorie', 'citoyen', 'service']
        read_only_fields = ['id','lat','long', 'statut']


    def get_wilaya_value(self,nom_wilaya):
        for value,libelle in Wilaya.choices:
            if libelle==nom_wilaya:
                return value

        return None        

    def get_commune_value(self,nom_commune):
        for value,libelle in Commune.choices:
            if libelle==nom_commune:
                return value

        return None    

        
    def create(self, validated_data):
        localisation= Point(float(validated_data.get('longitude')), float(validated_data.get('latitude')), srid=4326)
        validated_data = completer_champs_incident(self.context.get('request'),validated_data,localisation)   

        incident=IncidentUrbain.objects.create(localisation=localisation,
                                                   commune=self.get_commune_value(validated_data['commune']),
                                                   wilaya=self.get_wilaya_value(validated_data['wilaya']),
                                                   url_image=validated_data.get('url_image'),
                                                   description=validated_data.get('description'),
                                                   date_signalement=validated_data.get('date_signalement'),
                                                   categorie=validated_data.get('categorie'),
                                                   citoyen=validated_data.get('citoyen'),
                                                   service=validated_data.get('service'))


        return incident    
    

    def get_lat(self, obj):
        return obj.localisation.y


    def get_long(self, obj):
        return obj.localisation.x
         