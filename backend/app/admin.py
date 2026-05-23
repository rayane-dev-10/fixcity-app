from django import forms
from .forms import MyUserCreationForm
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from leaflet.admin import LeafletGeoAdmin
from .models import (
    User,
    Admin,
    Citoyen,
    Siege,
    Signalement,
    CategorieIncident,
    Organisation,

)    
# Register your models here.
@admin.register(User)
class MyUserAdmin(UserAdmin):
    add_form=MyUserCreationForm
    list_display = ('id', 'first_name', 'last_name', 'email','password', 'is_citoyen','is_app_admin','is_staff','is_superuser','is_active')
    search_fields = ('nom', 'prenom', 'email')
    list_filter = ('is_citoyen','is_app_admin','is_staff','is_superuser')
    ordering = ('email',)
    fieldsets = (
        (None, {'fields': ('first_name','last_name','email', 'password')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Dates', {'fields': ('last_login', 'date_joined')}),
    )
    #pour l'ajout d'un utilisateur via l'admin
    add_fieldsets=(
        (None, {
            'classes': ('wide',),
            'fields': ('first_name','last_name','email', 'password')
        }),
        ('Permissions',{'fields':('is_citoyen','is_app_admin','is_staff'),})
    )

    def get_form(self, request, obj=None, **kwargs):
        form = super().get_form(request, obj, **kwargs)
        # On vérifie si le champ password existe dans le formulaire
        if 'password' in form.base_fields:
            # On remplace le widget par défaut par un champ "Password"
            form.base_fields['password'].widget = forms.PasswordInput()
        return form
    

@admin.register(Organisation)
class OrganisationAdmin(admin.ModelAdmin):
    list_display = ('id', 'nom','get_categories')
    list_filter=('categories',)

    def get_categories(self, obj):#fonction pour afficher les categories d'une organisation
        return ", ".join([cat.nom for cat in obj.categories.all()])
    
    get_categories.short_description = "Catégories"
    

@admin.register(CategorieIncident)
class CategorieIncidentAdmin(admin.ModelAdmin):
    list_display = ('id', 'nom')
    search_fields = ('nom',)


@admin.register(Admin)
class AdminAdmin(admin.ModelAdmin):
    list_display = ('id', 'siege')


@admin.register(Citoyen)
class CitoyenAdmin(admin.ModelAdmin):
    list_display = ('id','user')


@admin.register(Signalement)
class SignalementAdmin(LeafletGeoAdmin):
    list_display = (
        'id',
        'url_image',
        'localisation',
        'commune',
        'wilaya',
        'statut',
        'categorie',
        'citoyen',
        'siege',
        'date_envoi'
    )
    list_filter = ('statut', 'commune', 'wilaya', 'categorie')
    list_display_links=('url_image',)
    ordering = ('-date_envoi',)


@admin.register(Siege)
class SiegeAdmin(LeafletGeoAdmin):
    list_display = ('id', 'nom', 'localisation', 'commune', 'wilaya', 'organisation')
    list_filter = ('commune', 'wilaya')
