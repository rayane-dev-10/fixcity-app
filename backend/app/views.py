from .models import Admin, Citoyen, Siege, Signalement, User,CategorieIncident
from .serializers import SignalementSerializer, UserSerializer
from rest_framework.decorators import api_view ,permission_classes,authentication_classes
from rest_framework.permissions import IsAuthenticated,AllowAny
from .permission import IsCitoyenUser,IsAppAdminUser
from rest_framework.response import Response
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework import status
from rest_framework_simplejwt.views import TokenObtainPairView
from .serializers import MyTokenObtainPairSerializer
from django.contrib.gis.geos import Point
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
    data =request.data
    id_categorie=CategorieIncident.objects.get(nom=data['categorie']).id
    data['categorie']=id_categorie
    serializer = SignalementSerializer(data=data,context={'request': request})
    if serializer.is_valid():
        serializer.save()
        #signalement=serializer.instance
        #admin=Admin.objects.get(siege=signalement.siege)
        #envoyer_notification(admin.id)
        
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)    


@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated,IsCitoyenUser])
def liste_signalements(request):
    signalements = Signalement.objects.filter(citoyen=request.user.citoyen.id)
    serializer = SignalementSerializer(signalements, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated,IsAppAdminUser])
def liste_signalements_Siege(request):
    try:
        admin=Admin.objects.get(id=request.user)
    except Admin.DoesNotExist:
        return Response({"detail": "Admin non trouvé."}, status=status.HTTP_404_NOT_FOUND)
        
    signalements = Signalement.objects.filter(siege=admin.siege)
    serializer = SignalementSerializer(signalements, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated,IsAppAdminUser])
def get_signalement_by_id(request, signalement_id):
    try:
        signalement = Signalement.objects.get(id=signalement_id)
        serializer = SignalementSerializer(signalement)
        return Response(serializer.data, status=status.HTTP_200_OK)
    except Signalement.DoesNotExist:
        return Response({"detail": "Signalement non trouvé."}, status=status.HTTP_404_NOT_FOUND)


@api_view(['GET'])
@permission_classes([IsAuthenticated,IsCitoyenUser])
def liste_signalements_proches(request):
    lat=request.query_params.get('lat')
    lon=request.query_params.get('long')
    point = Point(float(lon), float(lat))
    signalements = Signalement.objects.filter(localisation__distance_lte=(point, 1000))  #filtre les signalements dans un rayon de 1 km
    if signalements.exists():
        serializer = SignalementSerializer(signalements, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
    else:
        return Response({"detail": "Aucun signalement trouvé dans les environs."}, status=status.HTTP_404_NOT_FOUND)


@api_view(['PATCH'])
@permission_classes([IsAuthenticated,IsAppAdminUser])
def update_statut_signalement(request, signalement_id):
    try:
        signalement = Signalement.objects.get(id=signalement_id)
    except Signalement.DoesNotExist:
        return Response({"detail": "Signalement non trouvé."}, status=status.HTTP_404_NOT_FOUND)
     
    signalement.statut = request.data.get('statut')
    signalement.save()
    #envoyer_notification(signalement.citoyen)
    serializer = SignalementSerializer(signalement)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated,IsAppAdminUser])
def get_statistiques_siege(request):
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
@permission_classes([IsAuthenticated])
def get_user_profile(request):
    if(request.user.role=='citoyen'):
        try:
            citoyen = Citoyen.objects.get(user=request.user)
        except Citoyen.DoesNotExist:
            return Response({"detail": "Citoyen non trouvé."}, status=status.HTTP_404_NOT_FOUND)
        
        serializer = UserSerializer(citoyen.user)
        nbr_signalements_resolus=Signalement.objects.filter(citoyen=request.user.id, statut='RESOLU').count()
        data=serializer.data.copy()
        data['signalements_resolus']=str(nbr_signalements_resolus)
        return Response(data, status=status.HTTP_200_OK) 
    elif(request.user.role=='admin'):
        try:
            admin=Admin.objects.get(user=request.user)
        except Admin.DoesNotExist:
            return Response({"detail": "Admin non trouvé."}, status=status.HTTP_404_NOT_FOUND)
        
        serializer = UserSerializer(admin.user)
        return Response(serializer.data, status=status.HTTP_200_OK)
    else:
        return Response({"detail": "Rôle User non reconnu."}, status=status.HTTP_400_BAD_REQUEST)
   


