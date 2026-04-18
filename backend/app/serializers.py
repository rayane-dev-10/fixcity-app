from rest_framework_gis.serializers import GeoFeatureModelSerializer
from rest_framework import serializers
from django.contrib.auth.hashers import make_password 
from .models import User,Citoyen,Admin,Signalement
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .services import Completer_champs
from django.contrib.gis.geos.point import Point


class MyTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)

        # ajouter des informations personnalisées au token
        token['is_citoyen'] = user.is_citoyen
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


class SignalementSerializer(GeoFeatureModelSerializer):
    latitude=serializers.FloatField(write_only=True)
    longitude=serializers.FloatField(write_only=True)
    class Meta:
        model = Signalement
        geo_field = "localisation"
        fields = ['id', 'localisation', 'latitude', 'longitude', 'commune', 'wilaya', 'url_image', 'description', 'statut', 'date_envoi', 'categorie', 'citoyen', 'siege']
        read_only_fields = ['id','localisation', 'date_envoi', 'statut','citoyen','siege']
        depth = 1

    def create(self, validated_data):
        lon = validated_data.pop('longitude')
        lat = validated_data.pop('latitude')

        validated_data['localisation'] = Point(float(lon), float(lat), srid=4326)

        validated_data = Completer_champs(self.context.get('request'),validated_data)

        return super().create(validated_data)    


      
        