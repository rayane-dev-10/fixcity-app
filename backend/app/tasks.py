from datetime import datetime
from apscheduler.schedulers.background import BackgroundScheduler
def delete_expired_otps():
    from .models import OTP
    deleted_count, _ = OTP.objects.filter(expires_at__lte=datetime.now()).delete()
    print(f"[{datetime.now()}] Nettoyage effectué : {deleted_count} OTP(s) expiré(s) supprimé(s).")

def start_otp_cleanup():
    scheduler = BackgroundScheduler()
    # On planifie l'exécution toutes les 10 minutes
    scheduler.add_job(
        delete_expired_otps, 
        'interval',
        minutes=10,
        id='clean_expired_otps_job',
        replace_existing=True
    )
    scheduler.start()