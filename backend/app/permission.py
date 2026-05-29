from rest_framework import permissions

class IsCitoyen(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_citoyen
    

class IsAgent(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_agent   