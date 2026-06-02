from django.apps import AppConfig
import os
class AppConfig(AppConfig):
    name = 'app'

    def ready(self):
        if os.environ.get('RUN_MAIN') == 'true':  # S'assure que le code ne s'exécute qu'une seule fois lors du démarrage du serveur
            from .tasks import start_otp_cleanup  
            start_otp_cleanup()
