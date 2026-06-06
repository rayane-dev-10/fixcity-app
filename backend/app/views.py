from .services import send_email,generate_unique_otp

from .models import IncidentUrbain, Utilisateur,OTP
from .serializers import IncidentUrbainSerializer, UtilisateurSerializer
from rest_framework.decorators import api_view ,permission_classes,authentication_classes
from rest_framework.permissions import IsAuthenticated,AllowAny
from .permission import IsCitoyen,IsAgent
from rest_framework.response import Response
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework import status
from rest_framework_simplejwt.views import TokenObtainPairView
from .serializers import MyTokenObtainPairSerializer
from django.contrib.gis.geos import Point
from .enums import Statut
from django.contrib.auth.hashers import check_password
from django.core.cache import cache
# Create your views here.

@api_view(['POST'])
@permission_classes([AllowAny])
def register(request):
    serializer = UtilisateurSerializer(data=request.data)
    if serializer.is_valid():
        serializer.validated_data['is_citoyen'] = True  
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class MyTokenObtainPairView(TokenObtainPairView):
    serializer_class = MyTokenObtainPairSerializer


@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsCitoyen])
def creer_incident(request):
    serializer = IncidentUrbainSerializer(data=request.data,context={'request': request})
    if serializer.is_valid():
        serializer.save()  
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)    


@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsCitoyen])
def liste_incidents(request):
    cache_key = f"reports_data_for_user_{request.user.id}"
    cached_data = cache.get(cache_key)
    if cached_data is not None:
        return Response(cached_data, status=status.HTTP_200_OK)
    
    incidents = IncidentUrbain.objects.filter(citoyen=request.user)
    serializer = IncidentUrbainSerializer(incidents, many=True)
    cache.set(cache_key, serializer.data, timeout=300)  # on met les données en cache pendant 5 minutes
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsAgent])
def liste_incidents_Service(request):
    try:
        agent=Utilisateur.objects.get(id=request.user.id)
    except Utilisateur.DoesNotExist:
        return Response({"detail": "Agent non trouvé."}, status=status.HTTP_404_NOT_FOUND)

    cache_key = f"service_reports_data_{agent.service.id}"
    cached_data = cache.get(cache_key)
    if cached_data is not None:
        return Response(cached_data, status=status.HTTP_200_OK)
        
    incidents = IncidentUrbain.objects.filter(service=agent.service)
    serializer = IncidentUrbainSerializer(incidents, many=True)
    data=serializer.data.copy()
    latitude=agent.service.localisation.y
    longitude=agent.service.localisation.x
    data.append(str(latitude))
    data.append(str(longitude))

    cache.set(cache_key, data, timeout=300)  # on met les données en cache pendant 5 minutes

    return Response(data, status=status.HTTP_200_OK)

@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsAgent])
def get_incident(request, incident_id):
    try:
        incident = IncidentUrbain.objects.get(id=incident_id)
        serializer = IncidentUrbainSerializer(incident)
        return Response(serializer.data, status=status.HTTP_200_OK)
    except IncidentUrbain.DoesNotExist:
        return Response({"detail": "Incident non trouvé."}, status=status.HTTP_404_NOT_FOUND)


@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsCitoyen])
def liste_incidents_proches(request):
    lat=request.query_params.get('lat')
    lon=request.query_params.get('long')
    if lat is None or lon is None:
        return Response({"message":"latitude et/ou longitude non fournis"},status=status.HTTP_400_BAD_REQUEST)
    
    cache_key = f"nearby_reports_data_for_user_{request.user.id}_lat_{lat}_lon_{lon}"
    cached_data = cache.get(cache_key)
    if cached_data is not None:
        return Response(cached_data, status=status.HTTP_200_OK)
    
    point = Point(float(lon), float(lat),srid=4326)

    '''filtrer les signalements dans un rayon de 10 km,
    puis enlever ceux qui appartiennent au citoyen lui meme'''
    incidents = IncidentUrbain.objects.filter(localisation__distance_lte=(point, 10000)).exclude(citoyen=request.user)
    if incidents.exists(): 
       serializer = IncidentUrbainSerializer(incidents, many=True)
       cache.set(cache_key, serializer.data, timeout=300)  # on met les données en cache pendant 5 minutes
       return Response(serializer.data, status=status.HTTP_200_OK)
    else:    
       return Response({"detail": "Aucun incident proche n'est trouvé"}, status=status.HTTP_404_NOT_FOUND)


@api_view(['PATCH'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsAgent])
def update_statut_incident(request, incident_id):
    try:
        incident = IncidentUrbain.objects.get(id=incident_id)
    except IncidentUrbain.DoesNotExist:
        return Response({"detail": "Incident non trouvé."}, status=status.HTTP_404_NOT_FOUND)
    
    if (request.data.get('statut')) and (request.data.get('statut') in Statut.labels):
        statut=request.data.get('statut')
        
        for value,libelle in Statut.choices:
            if libelle==statut:
                code_statut=value

        incident.statut=code_statut
        incident.save()
        if statut=="En cours de traitement":
            etat=send_email(incident.citoyen.email,context="mise_a_jour_statut_incident_en_cours",incident_id=incident.id)
        elif statut=="Résolu":
            etat=send_email(incident.citoyen.email,context="mise_a_jour_statut_incident_resolu",incident_id=incident.id)
        else:
            pass

        serializer = IncidentUrbainSerializer(incident)
        #on supprime les données en cache pour rafraichir les données lors de la prochaine requete get
        cache.delete(f"service_reports_data_{request.user.service.id}")
        cache.delete(f"reports_data_for_user_{incident.citoyen.id}")
        cache.delete_pattern(f"nearby_reports_data_for_user_{incident.citoyen.id}_lat_*_lon_*")
        cache.delete(f"user_profile_data_{incident.citoyen.id}") #mettre a jour les données du profil du citoyen
        cache.delete(f"user_profile_data_{request.user.id}")# mettre a jour les données du profil de l'agent
        return Response(serializer.data, status=status.HTTP_200_OK)
    else:
        return Response({"message":"statut non indiqué ou invalide"},status=status.HTTP_400_BAD_REQUEST)



@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def user_profile(request):
    cache_key = f"user_profile_data_{request.user.id}"
    cached_data = cache.get(cache_key)
    if cached_data is not None:
        return Response(cached_data, status=status.HTTP_200_OK)
    if(request.user.is_citoyen):
        citoyen = Utilisateur.objects.get(id=request.user.id)        
        serializer = UtilisateurSerializer(citoyen)
        nbr_signalements_resolus=IncidentUrbain.objects.filter(citoyen=request.user, statut='RESOLU').count()
        data=serializer.data.copy()
        data['signalements_resolus']=str(nbr_signalements_resolus)
        cache.set(cache_key, data, timeout=300)  # on met les données en cache pendant 5 minutes
        return Response(data, status=status.HTTP_200_OK) 
    elif(request.user.is_agent):
        agent = Utilisateur.objects.get(id=request.user.id)
        serializer = UtilisateurSerializer(agent)
        data = serializer.data.copy()
        signalements_pas_traites = IncidentUrbain.objects.filter(
            service=agent.service,
            statut=Statut.NOUVEAU
        ).count()

        signalements_en_cours = IncidentUrbain.objects.filter(
            service=agent.service,
            statut=Statut.EN_COURS
        ).count()

        signalements_resolus = IncidentUrbain.objects.filter(
            service=agent.service,
            statut=Statut.RESOLU
        ).count()

        data['signalements_pas_traites'] = str(signalements_pas_traites)
        data['signalements_en_cours'] = str(signalements_en_cours)
        data['signalements_resolus'] = str(signalements_resolus)
        data['service_public'] = agent.service.nom
        data['wilaya'] = agent.service.get_wilaya_display()
        data['commune'] = agent.service.get_commune_display()

        cache.set(cache_key, data, timeout=300)  # on met les données en cache pendant 5 minutes
        return Response(data, status=status.HTTP_200_OK)
    else:
        return Response({"message":"Role utilisateur inconnu"},status=status.HTTP_400_BAD_REQUEST)
          

@api_view(['POST'])
@permission_classes([AllowAny])
def register_otp_view(request):
    email=request.data.get('email')
    if email is None:
        return Response({"message":"email non fourni"},status=status.HTTP_400_BAD_REQUEST)
    
    if Utilisateur.objects.filter(email=email).exists():
        return Response({"message":"un utilisateur est déjà enregistré avec cet email"},status=status.HTTP_400_BAD_REQUEST)
    else:
        otp, hached_otp = generate_unique_otp()
        otpInstance=OTP.objects.create(email=email,hached_otp=hached_otp)
        otpInstance.setExpiration(minutes=10)
        otpInstance.save()
        etat=send_email(email,context="email_verification",otp=otp)
        if etat:
            return Response({"message":"mail envoyé avec succès"},status=status.HTTP_200_OK)
        else:
            return Response({"message":"erreur lors de l'envoi du mail"},status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([AllowAny])
def password_reset_otp_view(request):
    email=request.data.get('email')
    if email is None:
        return Response({"message":"email non fourni"},status=status.HTTP_400_BAD_REQUEST)
    
    otp, hached_otp = generate_unique_otp()
    try :
        utilisateur=Utilisateur.objects.get(email=email)
        otpInstance=OTP.objects.create(email=utilisateur.email,hached_otp=hached_otp)
        otpInstance.setExpiration(minutes=10)
        otpInstance.save()
        etat=send_email(email,context="password_reset",otp=otp)
        if etat:
            return Response({"message":"mail envoyé avec succès"},status=status.HTTP_200_OK)
        else:
            return Response({"message":"erreur lors de l'envoi du mail"},status=status.HTTP_500_INTERNAL_SERVER_ERROR)   
    except Utilisateur.DoesNotExist:
        return Response({"message":"Utilisateur non trouvé"},status=status.HTTP_404_NOT_FOUND)       
        

    
    
@api_view(['POST'])
@permission_classes([AllowAny])
def verify_otp_view(request):
    otp_input=request.data.get('otp')
    email=request.data.get('email')
    if  otp_input is None or email is None:
        return Response({"message":"otp et/ou email non fournis"},status=status.HTTP_400_BAD_REQUEST)
    
    try:
        otp=OTP.objects.filter(email=email).latest('created_at')
        if otp.is_expired():
            otp.delete()
            return Response({"message":"OTP expiré"},status=status.HTTP_400_BAD_REQUEST)
        else:
            if check_password(otp_input, otp.hached_otp):
                otp.delete()
                return Response({"message":"OTP valide"},status=status.HTTP_200_OK)
            else:
                return Response({"message":"OTP invalide"},status=status.HTTP_400_BAD_REQUEST)
    except OTP.DoesNotExist:
        return Response({"message":"OTP invalide"},status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def password_reset_view(request):
    email=request.data.get('email')
    new_password=request.data.get('password')
    if email is None or new_password is None:
        return Response({"message":"email et/ou nouveau mot de passe non fournis"},status=status.HTTP_400_BAD_REQUEST)
    
    try: 
        utilisateur=Utilisateur.objects.get(email=email)
        utilisateur.set_password(new_password)
        utilisateur.save()
        return Response({"message":"Mot de passe réinitialisé avec succès"},status=status.HTTP_200_OK)
    except Utilisateur.DoesNotExist:
        return Response({"message":"Utilisateur non trouvé"},status=status.HTTP_404_NOT_FOUND)    
    
    



    





    
