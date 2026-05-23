from rest_framework import serializers
from django.contrib.auth.hashers import make_password 
from .models import User,Citoyen,Signalement,CategorieIncident, UserDevice
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .services import completer_champs_signalement
from .enums import Wilaya,Commune
from django.contrib.gis.geos.point import Point
from django.shortcuts import get_object_or_404
from rest_framework.exceptions import AuthenticationFailed
class MyTokenObtainPairSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        data = super().validate(attrs)
        user=self.user
        if user.is_staff or user.is_superuser :
            raise AuthenticationFailed("Authentification échouée! vous n'avez pas le droit d'acceder à l'application mobile.")
        
        return data
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)

        # ajouter des informations personnalisées au token
        token['is_citoyen'] = user.is_citoyen
        token['is_app_admin']=user.is_app_admin
        return token


class UserSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['id', 'email', 'password', 'first_name', 'last_name', 'is_citoyen']
        read_only_fields = ['id','is_citoyen']

    def create(self, validated_data):
        password= validated_data.pop('password')
        user =User.objects.create_user(password=password,**validated_data)
        Citoyen.objects.create(user=user)
        return user        


class SignalementSerializer(serializers.ModelSerializer):
    latitude=serializers.FloatField(write_only=True)
    longitude=serializers.FloatField(write_only=True)
    wilaya = serializers.CharField(write_only=True)
    commune=serializers.CharField(write_only=True)
    nom_commune=serializers.CharField(source='get_commune_display', read_only=True)
    nom_wilaya = serializers.CharField(source='get_wilaya_display', read_only=True)
    date_envoi=serializers.DateTimeField(format='%d/%m/%Y à %H:%M',read_only=True)
    citoyen=serializers.SlugRelatedField(read_only=True,slug_field='user.email')
    siege=serializers.SlugRelatedField(read_only=True,slug_field='nom')
    categorie=serializers.SlugRelatedField(queryset=CategorieIncident.objects.all(),slug_field='nom')
    #champs calclués pour les renvoyer dans la reponse http
    lat = serializers.SerializerMethodField()
    long = serializers.SerializerMethodField()
    class Meta:
        model = Signalement
        fields = ['id','latitude', 'longitude','lat','long','commune','nom_wilaya','nom_commune', 'wilaya','url_image', 'description', 'statut', 'date_envoi', 'categorie', 'citoyen', 'siege']
        read_only_fields = ['id','lat','long','date_envoi', 'statut']


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
        validated_data = completer_champs_signalement(self.context.get('request'),validated_data,localisation)   

        signalement=Signalement.objects.create(localisation=localisation,
                                               commune=self.get_commune_value(validated_data['commune']),
                                               wilaya=self.get_wilaya_value(validated_data['wilaya']),
                                               url_image=validated_data.get('url_image'),
                                               description=validated_data.get('description'),
                                               date_envoi=validated_data.get('date_envoi'),
                                               categorie=validated_data.get('categorie'),
                                               citoyen=validated_data.get('citoyen'),
                                               siege=validated_data.get('siege'))


        return signalement    
    

    def get_lat(self, obj):
        return obj.localisation.y


    def get_long(self, obj):
        return obj.localisation.x


      
class UserDeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserDevice
        fields = ['id', 'user', 'deviceToken','type']
        read_only_fields = ['id']


    def create_or_update(self, validated_data):
        user = validated_data.get('user')
        deviceToken = validated_data.get('deviceToken')
        type = validated_data.get('type')
    
        user_device, created = UserDevice.objects.update_or_create(
            deviceToken=deviceToken,
            defaults={'type': type, 'user': user}
        )

        return user_device     


    def save (self, **kwargs):
        validated_data = self.validated_data
        return self.create_or_update(validated_data)
                