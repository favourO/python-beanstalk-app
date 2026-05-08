from enum import Enum


class Goal(str, Enum):
    TRACK = "track"
    CONCEIVE = "conceive"
    AVOID = "avoid"


class WearableType(str, Enum):
    APPLE_WATCH = "apple_watch"
    GTL1 = "gtl1"
    MANUAL_BBT = "manual_bbt"
    NONE = "none"
    FITBIT = "fitbit"
    OURA = "oura"


class CyclePhase(str, Enum):
    MENSTRUAL = "menstrual"
    FOLLICULAR = "follicular"
    OVULATORY = "ovulatory"
    LUTEAL = "luteal"


class LogType(str, Enum):
    LH = "lh"
    BBT = "bbt"
    MUCUS = "mucus"
    SYMPTOM = "symptom"
    INTERCOURSE = "intercourse"
    PREGNANCY_TEST = "pregnancy_test"
    PERIOD = "period"


class ReproductiveStage(str, Enum):
    STANDARD = "standard"
    PERIMENOPAUSE_AWARE = "perimenopause_aware"
    POSTPARTUM = "postpartum"
