from rest_framework import permissions

class IsCitoyenUser(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_citoyen
    

class IsAppAdminUser(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_app_admin   