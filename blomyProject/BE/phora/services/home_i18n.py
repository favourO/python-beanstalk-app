from __future__ import annotations

SUPPORTED_LANGUAGES = {"en", "es", "fr", "de", "pt"}

STRINGS: dict[str, dict[str, str]] = {
    "en": {
        # Quick actions
        "qa_log_period": "Log Period",
        "qa_log_cramps": "Log Cramps",
        "qa_log_mood": "Log Mood",
        "qa_log_discharge": "Log Discharge",
        "qa_log_sleep": "Log Sleep",
        "qa_log_workout": "Log Workout",
        # Wearable body signal states
        "bss_connect_title": "Connect wearable",
        "bss_connect_message": "Connect a wearable to show temperature, heart rate, HRV, and sleep readings here.",
        "bss_connect_action": "Connect wearable",
        "bss_readings_title": "Wearable readings",
        "bss_readings_message": "Showing the latest readings synced from your connected device.",
        "bss_awaiting_title": "Waiting for readings",
        "bss_awaiting_message": "Your wearable is connected. Sync your device to show body signals here.",
        # Alerts
        "alert_prediction_improves": "Prediction accuracy improves as you log more cycles.",
        "alert_connect_wearable": "Connect a wearable to improve cycle and recovery insights.",
        "alert_sync_health_data": "Your wearable is connected, but no recent body signals were found.",
        # Disclaimers
        "cycle_awareness_disclaimer": (
            "Vyla provides wellness and cycle awareness insights only. Predictions are estimates and "
            "should not be used for contraception, diagnosis, or treatment."
        ),
        "signal_check_disclaimer": (
            "If this reading is unusual for you or you feel unwell, consider speaking with a healthcare "
            "professional."
        ),
    },
    "de": {
        "qa_log_period": "Periode erfassen",
        "qa_log_cramps": "Krämpfe erfassen",
        "qa_log_mood": "Stimmung erfassen",
        "qa_log_discharge": "Ausfluss erfassen",
        "qa_log_sleep": "Schlaf erfassen",
        "qa_log_workout": "Training erfassen",
        "bss_connect_title": "Wearable verbinden",
        "bss_connect_message": "Verbinde ein Wearable, um Temperatur, Herzfrequenz, HRV und Schlafmesswerte anzuzeigen.",
        "bss_connect_action": "Wearable verbinden",
        "bss_readings_title": "Wearable-Messwerte",
        "bss_readings_message": "Zeigt die neuesten Messwerte an, die von deinem verbundenen Gerät synchronisiert wurden.",
        "bss_awaiting_title": "Warten auf Messwerte",
        "bss_awaiting_message": "Dein Wearable ist verbunden. Synchronisiere dein Gerät, um Körpersignale anzuzeigen.",
        "alert_prediction_improves": "Die Vorhersagegenauigkeit verbessert sich, je mehr Zyklen du erfasst.",
        "alert_connect_wearable": "Verbinde ein Wearable, um Zyklus- und Erholungseinblicke zu verbessern.",
        "alert_sync_health_data": "Dein Wearable ist verbunden, aber es wurden keine aktuellen Körpersignale gefunden.",
        "cycle_awareness_disclaimer": (
            "Vyla bietet nur Wellness- und Zyklusbewusstheits-Einblicke an. Vorhersagen sind Schätzungen und "
            "sollten nicht zur Verhütung, Diagnose oder Behandlung verwendet werden."
        ),
        "signal_check_disclaimer": (
            "Wenn dieser Wert ungewöhnlich für dich ist oder du dich unwohl fühlst, solltest du eine Fachkraft "
            "für Gesundheit aufsuchen."
        ),
    },
    "es": {
        "qa_log_period": "Registrar período",
        "qa_log_cramps": "Registrar cólicos",
        "qa_log_mood": "Registrar estado de ánimo",
        "qa_log_discharge": "Registrar flujo",
        "qa_log_sleep": "Registrar sueño",
        "qa_log_workout": "Registrar entrenamiento",
        "bss_connect_title": "Conectar dispositivo wearable",
        "bss_connect_message": "Conecta un wearable para ver temperatura, frecuencia cardíaca, VFC y lecturas de sueño aquí.",
        "bss_connect_action": "Conectar wearable",
        "bss_readings_title": "Lecturas del wearable",
        "bss_readings_message": "Mostrando las últimas lecturas sincronizadas desde tu dispositivo conectado.",
        "bss_awaiting_title": "Esperando lecturas",
        "bss_awaiting_message": "Tu wearable está conectado. Sincroniza tu dispositivo para mostrar señales corporales aquí.",
        "alert_prediction_improves": "La precisión de la predicción mejora a medida que registras más ciclos.",
        "alert_connect_wearable": "Conecta un wearable para mejorar los insights de ciclo y recuperación.",
        "alert_sync_health_data": "Tu wearable está conectado, pero no se encontraron señales corporales recientes.",
        "cycle_awareness_disclaimer": (
            "Vyla proporciona solo insights de bienestar y conciencia del ciclo. Las predicciones son estimaciones y "
            "no deben utilizarse para anticoncepción, diagnóstico o tratamiento."
        ),
        "signal_check_disclaimer": (
            "Si esta lectura es inusual para ti o no te sientes bien, considera hablar con un profesional de la salud."
        ),
    },
    "fr": {
        "qa_log_period": "Enregistrer règles",
        "qa_log_cramps": "Enregistrer crampes",
        "qa_log_mood": "Enregistrer humeur",
        "qa_log_discharge": "Enregistrer pertes",
        "qa_log_sleep": "Enregistrer sommeil",
        "qa_log_workout": "Enregistrer entraînement",
        "bss_connect_title": "Connecter un wearable",
        "bss_connect_message": "Connectez un wearable pour afficher la température, la fréquence cardiaque, la VFC et les données de sommeil ici.",
        "bss_connect_action": "Connecter un wearable",
        "bss_readings_title": "Données du wearable",
        "bss_readings_message": "Affichage des dernières données synchronisées depuis votre appareil connecté.",
        "bss_awaiting_title": "En attente de données",
        "bss_awaiting_message": "Votre wearable est connecté. Synchronisez votre appareil pour afficher les signaux corporels ici.",
        "alert_prediction_improves": "La précision des prédictions s'améliore au fur et à mesure que vous enregistrez plus de cycles.",
        "alert_connect_wearable": "Connectez un wearable pour améliorer les insights sur le cycle et la récupération.",
        "alert_sync_health_data": "Votre wearable est connecté, mais aucun signal corporel récent n'a été trouvé.",
        "cycle_awareness_disclaimer": (
            "Vyla fournit uniquement des insights de bien-être et de conscience du cycle. Les prédictions sont des estimations et "
            "ne doivent pas être utilisées pour la contraception, le diagnostic ou le traitement."
        ),
        "signal_check_disclaimer": (
            "Si cette lecture est inhabituelle pour vous ou si vous ne vous sentez pas bien, envisagez de consulter un professionnel de santé."
        ),
    },
    "pt": {
        "qa_log_period": "Registrar período",
        "qa_log_cramps": "Registrar cólicas",
        "qa_log_mood": "Registrar humor",
        "qa_log_discharge": "Registrar corrimento",
        "qa_log_sleep": "Registrar sono",
        "qa_log_workout": "Registrar treino",
        "bss_connect_title": "Conectar dispositivo vestível",
        "bss_connect_message": "Conecte um dispositivo vestível para exibir temperatura, frequência cardíaca, VFC e leituras de sono aqui.",
        "bss_connect_action": "Conectar dispositivo",
        "bss_readings_title": "Leituras do dispositivo",
        "bss_readings_message": "Exibindo as leituras mais recentes sincronizadas do seu dispositivo conectado.",
        "bss_awaiting_title": "Aguardando leituras",
        "bss_awaiting_message": "Seu dispositivo está conectado. Sincronize-o para exibir sinais corporais aqui.",
        "alert_prediction_improves": "A precisão da previsão melhora conforme você registra mais ciclos.",
        "alert_connect_wearable": "Conecte um dispositivo vestível para melhorar os insights de ciclo e recuperação.",
        "alert_sync_health_data": "Seu dispositivo está conectado, mas nenhum sinal corporal recente foi encontrado.",
        "cycle_awareness_disclaimer": (
            "A Vyla fornece apenas insights de bem-estar e consciência do ciclo. As previsões são estimativas e "
            "não devem ser usadas para contracepção, diagnóstico ou tratamento."
        ),
        "signal_check_disclaimer": (
            "Se esta leitura for incomum para você ou você não estiver se sentindo bem, considere falar com um profissional de saúde."
        ),
    },
}


def translate(locale: str, key: str) -> str:
    lang = locale.split("-")[0].split("_")[0].lower()
    if lang not in SUPPORTED_LANGUAGES:
        lang = "en"
    return STRINGS[lang].get(key, STRINGS["en"][key])
