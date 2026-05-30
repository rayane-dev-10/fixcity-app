from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import(
MyTokenObtainPairView,
get_incident,
password_reset_otp_view,
password_reset_view,
register,
creer_incident,
liste_incidents,
liste_incidents_Service,
liste_incidents_proches,
get_incident,
register_otp_view,
user_profile,
update_statut_incident,
verify_otp_view,
) 

urlpatterns = [
    path('app/token', MyTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('app/token/refresh', TokenRefreshView.as_view(), name='token_refresh'),
    path('app/register/confirm', register, name='register'),
    path('app/creer-incident', creer_incident, name='creer_incident'),
    path('app/liste-incidents', liste_incidents, name='liste_incidents'),
    path('app/liste-incidents-service', liste_incidents_Service, name='liste_incidents_Service'),
    path('app/incident/<int:id>', get_incident, name='incident'),
    path('app/incidents-proches', liste_incidents_proches, name='incident_proche'),
    path('app/user-profile', user_profile, name='get_user_profile'),
    path('app/update-incident/<int:incident_id>', update_statut_incident, name='update_statut_incident'),
    path('app/register/send-otp', register_otp_view, name='email_verification'),
    path('app/register/verify-otp', verify_otp_view, name='verify_email'),
    path('app/password-reset/send-otp', password_reset_otp_view, name='password_reset_request'),
    path('app/password-reset/verify-otp', verify_otp_view, name='password_reset_confirm'),
    path('app/password-reset/confirm', password_reset_view, name='password_reset_complete'),
]