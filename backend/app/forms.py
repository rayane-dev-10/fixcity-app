from django import forms
from .models import Utilisateur
class MyUserCreationForm(forms.ModelForm):
    # On définit le mot de passe manuellement pour avoir le type "password"
    password = forms.CharField(widget=forms.PasswordInput())
    
    class Meta:
        model = Utilisateur
        fields = ("email", "first_name", "last_name","is_staff", "is_citoyen", "is_agent")

    def save(self, commit=True):
        utilisateur = super().save(commit=False)
        utilisateur.set_password(self.cleaned_data["password"])#on hash le mot de passe avant de sauvegarder l'utilisateur
        if commit:
            utilisateur.save()
        return utilisateur