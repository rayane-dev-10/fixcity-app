from .services import envoyer_notification

from .models import Admin, Citoyen, Siege, Signalement, User,CategorieIncident, UserDevice
from .serializers import UserDeviceSerializer, SignalementSerializer, UserDeviceSerializer, UserSerializer
from rest_framework.decorators import api_view ,permission_classes,authentication_classes
from rest_framework.permissions import IsAuthenticated,AllowAny
from .permission import IsCitoyenUser,IsAppAdminUser
from rest_framework.response import Response
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework import status
from rest_framework_simplejwt.views import TokenObtainPairView
from .serializers import MyTokenObtainPairSerializer
from django.contrib.gis.geos import Point
from .enums import StatutSignalement
# Create your views here.

@api_view(['POST'])
@permission_classes([AllowAny])
def register(request):
    serializer = UserSerializer(data=request.data)
    if serializer.is_valid():
        serializer.validated_data['is_citoyen'] = True  
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class MyTokenObtainPairView(TokenObtainPairView):
    serializer_class = MyTokenObtainPairSerializer


@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsCitoyenUser])
def creer_signalement(request):
    serializer = SignalementSerializer(data=request.data,context={'request': request})
    if serializer.is_valid():
        serializer.save()
        signalement=serializer.instance
        admin=Admin.objects.get(siege=signalement.siege)

        # On récupère tous les tokens des appareils associés à l'utilisateur
        Devicetokens = list(UserDevice.objects.filter(user=signalement.siege.admin.user).values_list('deviceToken', flat=True))
        # Si des tokens existent, on envoie une notification à l'utilisateur pour l'informer d'un nouveau signalement
        if Devicetokens:
            envoyer_notification(Devicetokens, "Nouveau signalement", f"Un nouveau signalement vous a été envoyé : {signalement.description[:50]}...")
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)    


@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsCitoyenUser])
def liste_signalements(request):
    signalements = Signalement.objects.filter(citoyen=request.user.citoyen)
    serializer = SignalementSerializer(signalements, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsAppAdminUser])
def liste_signalements_Siege(request):
    try:
        admin=Admin.objects.get(user=request.user)
    except Admin.DoesNotExist:
        return Response({"detail": "Admin non trouvé."}, status=status.HTTP_404_NOT_FOUND)
        
    signalements = Signalement.objects.filter(siege=admin.siege)
    serializer = SignalementSerializer(signalements, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsAppAdminUser])
def get_signalement(request, signalement_id):
    try:
        signalement = Signalement.objects.get(id=signalement_id)
        serializer = SignalementSerializer(signalement)
        return Response(serializer.data, status=status.HTTP_200_OK)
    except Signalement.DoesNotExist:
        return Response({"detail": "Signalement non trouvé."}, status=status.HTTP_404_NOT_FOUND)


@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsCitoyenUser])
def liste_signalements_proches(request):
    lat=request.query_params.get('lat')
    lon=request.query_params.get('long')
    if lat is None or lon is None:
        return Response({"message":"latitude et/ou longitude non fournis"},status=status.HTTP_400_BAD_REQUEST)
    
    point = Point(float(lon), float(lat),srid=4326)

    '''filtrer les signalements dans un rayon de 1 km,
    puis enlever ceux qui appartiennent au citoyen lui meme'''
    signalements = Signalement.objects.filter(localisation__distance_lte=(point, 1000)).exclude(citoyen=request.user.citoyen)
    if signalements.exists(): 
       serializer = SignalementSerializer(signalements, many=True)
       return Response(serializer.data, status=status.HTTP_200_OK)
    else:    
       return Response({"detail": "Aucun signalement proche n'est trouvé"}, status=status.HTTP_404_NOT_FOUND)


@api_view(['PATCH'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsAppAdminUser])
def update_statut_signalement(request, signalement_id):
    try:
        signalement = Signalement.objects.get(id=signalement_id)
    except Signalement.DoesNotExist:
        return Response({"detail": "Signalement non trouvé."}, status=status.HTTP_404_NOT_FOUND)
    
    if (request.data.get('statut')) and (request.data.get('statut') in StatutSignalement.labels):
        statut=request.data.get('statut')
        
        for value,libelle in StatutSignalement.choices:
            if libelle==statut:
                statut=value

        signalement.statut=statut
        signalement.save()
        # On récupère tous les tokens des appareils associés à l'utilisateur
        Devicetokens = list(UserDevice.objects.filter(user=signalement.citoyen.user).values_list('deviceToken', flat=True))
        # Si des tokens existent, on envoie une notification à l'utilisateur pour l'informer du changement de statut de son signalement
        if Devicetokens:
            envoyer_notification(Devicetokens,"Signalement résolu",f"Cher citoyen, nous vous informons de la résolution de votre signalement : {signalement.description[:50]}...")

        serializer = SignalementSerializer(signalement)
        return Response(serializer.data, status=status.HTTP_200_OK)
    else:
        return Response({"message":"statut non indiqué ou invalide"},status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsAppAdminUser])
def statistiques_siege(request):
    try:
        admin=Admin.objects.get(user=request.user)
    except Admin.DoesNotExist:
        return Response({"detail": "Admin non trouvé."}, status=status.HTTP_404_NOT_FOUND)

    siege=admin.siege
    total_signalements = Signalement.objects.filter(siege=siege).count()
    signalements_en_cours = Signalement.objects.filter(siege=siege, statut='EN_COURS').count()
    signalements_resolus = Signalement.objects.filter(siege=siege, statut='RESOLU').count()
    
    data = {
        "total_signalements": str(total_signalements),
        "signalements_en_cours": str(signalements_en_cours),
        "signalements_resolus": str(signalements_resolus)
    }
    
    return Response(data, status=status.HTTP_200_OK)

@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def user_profile(request):
    if(request.user.is_citoyen):
        try:
            citoyen = Citoyen.objects.get(user=request.user)
        except Citoyen.DoesNotExist:
            return Response({"detail": "Citoyen non trouvé."}, status=status.HTTP_404_NOT_FOUND)
        
        serializer = UserSerializer(citoyen.user)
        nbr_signalements_resolus=Signalement.objects.filter(citoyen=request.user.id, statut='RESOLU').count()
        data=serializer.data.copy()
        data['signalements_resolus']=str(nbr_signalements_resolus)
        return Response(data, status=status.HTTP_200_OK) 
    elif(request.user.is_app_admin):
        try:
            admin=Admin.objects.get(user=request.user)
        except Admin.DoesNotExist:
            return Response({"detail": "Admin non trouvé."}, status=status.HTTP_404_NOT_FOUND)
        
        serializer = UserSerializer(admin.user)
        return Response(serializer.data, status=status.HTTP_200_OK)
    else:
        return Response({"detail": "Rôle Utilisateur non reconnu."}, status=status.HTTP_400_BAD_REQUEST)
   



@api_view(['POST','DELETE'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def user_device_view(request):
    if request.method == 'POST':
        data=request.data.copy()
        data['user']=request.user.id
        serializer = UserDeviceSerializer(data=data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
    
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    elif request.method == 'DELETE':
        UserDevices=UserDevice.objects.filter(user=request.user)
        if UserDevices.exists():
            UserDevices.delete()
            return Response({"detail": "User device tokens deleted successfully."}, status=status.HTTP_200_OK)
        else:
            return Response({"detail": "No user device tokens found."}, status=status.HTTP_404_NOT_FOUND)

    





    
