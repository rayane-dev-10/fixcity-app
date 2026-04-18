from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import(
MyTokenObtainPairView,
register,
creer_signalement,
liste_signalements,
liste_signalements_Siege,
liste_signalements_proches,
get_signalement_by_id,
get_user_profile,
get_statistiques_siege,
update_statut_signalement,
) 

urlpatterns = [
    path('app/token', MyTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('app/token/refresh', TokenRefreshView.as_view(), name='token_refresh'),
    path('app/register', register, name='register'),
    path('app/creer-signalement', creer_signalement, name='creer_signalement'),
    path('app/liste-signalements', liste_signalements, name='liste_signalements'),
    path('app/liste-signalements-siege', liste_signalements_Siege, name='liste_signalements_Siege'),
    path('app/get-signalement/<int:signalement_id>', get_signalement_by_id, name='get_signalement_by_id'),
    path('app/get-signalements-proches', liste_signalements_proches, name='get_signalement_proche'),
    path('app/get-user-profile', get_user_profile, name='get_user_profile'),
    path('app/get-statistiques-siege', get_statistiques_siege, name='get_statistiques_siege'),
    path('app/update-statut-signalement/<int:signalement_id>', update_statut_signalement, name='update_statut_signalement'),
]