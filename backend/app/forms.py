from django import forms
from .models import User
class MyUserCreationForm(forms.ModelForm):
    # On définit le mot de passe manuellement pour avoir le type "password"
    password = forms.CharField(widget=forms.PasswordInput())

    class Meta:
        model = User
        fields = ("email", "first_name", "last_name", "is_citoyen", "is_app_admin")

    def save(self, commit=True):
        user = super().save(commit=False)
        # Indispensable pour que le mot de passe ne soit pas en clair en base
        user.set_password(self.cleaned_data["password"])
        if commit:
            user.save()
        return user