from datetime import date, time as dt_time

from pydantic import BaseModel, Field


class PeriodLogPayload(BaseModel):
    start_date: date | None = None
    end_date: date | None = None
    intensity: str | None = None
    colour: str | None = None
    symptoms: list[str] = Field(default_factory=list)


class SymptomsLogPayload(BaseModel):
    mood: str | None = None
    energy_level: int | None = None
    physical: list[str] = Field(default_factory=list)
    pain_level: int | None = None
    sleep_quality: str | None = None
    notes: str | None = None


class TemperatureLogPayload(BaseModel):
    temperature_celsius: float | None = None
    measured_at: dt_time | None = None
    same_time_as_yesterday: bool = False
    uninterrupted_sleep: bool = False
    measured_before_getting_up: bool = False
    method: str | None = None
    illness_flag: bool = False
    alcohol_flag: bool = False
    stress_flag: bool = False
    travel_flag: bool = False
    unit: str | None = None


class LhTestLogPayload(BaseModel):
    result: str | None = None
    method: str | None = None
    image_url: str | None = None
    tested_at: dt_time | None = None


class CervicalMucusLogPayload(BaseModel):
    type: str | None = None
    amount: str | None = None
    notes: str | None = None


class IntimacyLogPayload(BaseModel):
    activity: str | None = None
    details: list[str] = Field(default_factory=list)
    time: dt_time | None = None
    notes: str | None = None


class DailyLogResponse(BaseModel):
    user_id: str
    date: date
    period: PeriodLogPayload | None = None
    symptoms: SymptomsLogPayload | None = None
    temperature: TemperatureLogPayload | None = None
    lh_test: LhTestLogPayload | None = None
    cervical_mucus: CervicalMucusLogPayload | None = None
    intimacy: IntimacyLogPayload | None = None
    notes: str | None = None


class DailyLogEnvelope(BaseModel):
    user_id: str | None = None
    date: date
    period: PeriodLogPayload | None = None
    symptoms: SymptomsLogPayload | None = None
    temperature: TemperatureLogPayload | None = None
    lh_test: LhTestLogPayload | None = None
    cervical_mucus: CervicalMucusLogPayload | None = None
    intimacy: IntimacyLogPayload | None = None
    notes: str | None = None


class SaveStatusResponse(BaseModel):
    status: str = "ok"
