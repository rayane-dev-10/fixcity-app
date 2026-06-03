from django import forms
from .forms import MyUserChangeForm, MyUserCreationForm
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from leaflet.admin import LeafletGeoAdmin
from .models import (
    OTP,
    Utilisateur,
    ServicePublique,
    IncidentUrbain,
    Categorie,

)    
# Register your models here.
@admin.register(Utilisateur)
class MyUserAdmin(UserAdmin):
    add_form=MyUserCreationForm
    form = MyUserChangeForm
    list_display = ('id', 'first_name', 'last_name', 'email','password', 'is_citoyen','is_agent','is_staff','is_active')
    search_fields = ('nom', 'prenom', 'email')
    list_filter = ('is_citoyen','is_agent','is_staff','is_active')
    ordering = ('email',)
    fieldsets = (
        (None, {'fields': ('first_name','last_name','email', 'password','service')}),
        ('Permissions', {'fields': ('is_active', 'is_staff','is_superuser','is_agent', 'groups', 'user_permissions')}),
        ('Dates', {'fields': ('last_login', 'date_joined')}),
    )
    #pour l'ajout d'un utilisateur via l'admin
    add_fieldsets=(
        (None, {
            'classes': ('wide',),
            'fields': ('first_name','last_name','email', 'password','service')
        }),
        ('Permissions',{'fields':('is_citoyen','is_agent','is_staff'),})
    )
       
    class Media:
        css = {
            'all': ('css/admin_custom.css',) # On indique à Django de charger ce fichier CSS
        }
    

    
@admin.register(Categorie)
class CategorieIncidentAdmin(admin.ModelAdmin):
    list_display = ('id', 'nom')
    search_fields = ('nom',)



@admin.register(IncidentUrbain)
class IncidentUrbainAdmin(LeafletGeoAdmin):
    list_display = (
        'id',
        'url_image',
        'localisation',
        'commune',
        'wilaya',
        'statut',
        'categorie',
        'citoyen',
        'service',
        'date_signalement'
    )
    list_filter = ('statut', 'commune', 'wilaya', 'categorie')
    list_display_links=('id',)
    ordering = ('date_signalement',)
    class Media:
        css = {
            'all': ('css/admin_custom.css',) # On indique à Django de charger ce fichier CSS
         }


@admin.register(ServicePublique)
class ServicePubliqueAdmin(LeafletGeoAdmin):
    list_display = ('id', 'nom', 'localisation', 'commune', 'wilaya','get_categories')
    list_filter = ('commune', 'wilaya')
    
    class Media:
        css = {
            'all': ('css/admin_custom.css',) # On indique à Django de charger ce fichier CSS
         }
        

    def get_categories(self, obj):
        return ", ".join([categorie.nom for categorie in obj.categories.all()])

    get_categories.short_description = 'Catégories'

@admin.register(OTP)
class OTPAdmin(admin.ModelAdmin):
    list_display = ('id','email', 'hached_otp','created_at', 'expires_at')
    list_filter = ('email',)
    search_fields = ('email',)     
