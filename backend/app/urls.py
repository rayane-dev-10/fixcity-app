from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import(
MyTokenObtainPairView,
register,
creer_signalement,
liste_signalements,
liste_signalements_Siege,
liste_signalements_proches,
get_signalement,
user_device_view,
user_profile,
statistiques_siege,
update_statut_signalement,
) 

urlpatterns = [
    path('app/token', MyTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('app/token/refresh', TokenRefreshView.as_view(), name='token_refresh'),
    path('app/register', register, name='register'),
    path('app/creer-signalement', creer_signalement, name='creer_signalement'),
    path('app/liste-signalements', liste_signalements, name='liste_signalements'),
    path('app/liste-signalements-siege', liste_signalements_Siege, name='liste_signalements_Siege'),
    path('app/signalement/<int:id>', get_signalement, name='signalement'),
    path('app/signalements-proches/', liste_signalements_proches, name='signalement_proche'),
    path('app/user-profile', user_profile, name='get_user_profile'),
    path('app/statistiques-siege', statistiques_siege, name='get_statistiques_siege'),
    path('app/update-statut-signalement/<int:signalement_id>', update_statut_signalement, name='update_statut_signalement'),
    path('app/user-device', user_device_view, name='user_device_view'),
]