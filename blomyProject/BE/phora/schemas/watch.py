from datetime import date, datetime

from pydantic import BaseModel, Field


class Gtl1HeartRateSummary(BaseModel):
    resting: float = 0
    avg: float = 0
    min: float = 0
    max: float = 0


class Gtl1SleepSummary(BaseModel):
    totalMinutes: int = 0
    deepMinutes: int = 0
    lightMinutes: int = 0
    awakeMinutes: int = 0


class Gtl1TemperatureSummary(BaseModel):
    avg: float = 0


class Gtl1StressSummary(BaseModel):
    avg: float = 0


class Gtl1BloodOxygenSummary(BaseModel):
    avg: float = 0
    min: float = 0


class Gtl1DailyHealthData(BaseModel):
    date: date
    steps: int = 0
    caloriesKcal: float = 0
    distanceMeters: float = 0
    heartRate: Gtl1HeartRateSummary = Field(default_factory=Gtl1HeartRateSummary)
    sleep: Gtl1SleepSummary = Field(default_factory=Gtl1SleepSummary)
    bloodOxygen: Gtl1BloodOxygenSummary = Field(default_factory=Gtl1BloodOxygenSummary)
    temperature: Gtl1TemperatureSummary = Field(default_factory=Gtl1TemperatureSummary)
    stress: Gtl1StressSummary = Field(default_factory=Gtl1StressSummary)
    sourceDevice: str | None = None
    syncTimestamp: str | None = None
    raw: dict = Field(default_factory=dict)


class WatchSyncRequest(BaseModel):
    device_type: str
    synced_at: datetime
    days: list[Gtl1DailyHealthData] = Field(default_factory=list)
