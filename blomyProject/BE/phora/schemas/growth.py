from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ShareInsightCardResponse(BaseModel):
    title: str
    value: str
    subtitle: str | None = None
    accent: str | None = None


class ShareInsightResponse(BaseModel):
    share_id: str
    title: str
    subtitle: str
    summary: str
    privacy_note: str
    deep_link_url: str
    cards: list[ShareInsightCardResponse] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)


class ShareSectionOptionResponse(BaseModel):
    id: str
    title: str
    subtitle: str
    description: str
    selected_by_default: bool = True


class ShareAudienceOptionResponse(BaseModel):
    id: str
    title: str
    subtitle: str


class ShareMethodOptionResponse(BaseModel):
    id: str
    title: str
    subtitle: str


class ShareCycleCountOptionResponse(BaseModel):
    value: int = Field(ge=1, le=12)
    label: str


class ShareInsightConfigResponse(BaseModel):
    screen_title: str
    screen_subtitle: str
    hero_title: str
    hero_body: str
    privacy_note: str
    sections: list[ShareSectionOptionResponse] = Field(default_factory=list)
    audiences: list[ShareAudienceOptionResponse] = Field(default_factory=list)
    methods: list[ShareMethodOptionResponse] = Field(default_factory=list)
    cycle_count_options: list[ShareCycleCountOptionResponse] = Field(
        default_factory=list
    )
    default_audience: str
    default_method: str
    default_cycle_count: int = Field(ge=1, le=12)


class ShareEventRequest(BaseModel):
    share_id: str
    event: Literal["share_opened", "share_exported_png", "share_sheet_opened", "share_completed", "share_cancelled"]
    channel: str | None = None
    deep_link_id: str | None = None


class GrowthActionResponse(BaseModel):
    status: str = "ok"


class ShareGenerateRequest(BaseModel):
    section_ids: list[str] = Field(default_factory=list)
    audience: Literal["doctor", "partner"]
    method: Literal["secure_link", "pdf_report", "email"]
    cycle_count: int = Field(default=3, ge=1, le=12)


class ShareGeneratedSectionResponse(BaseModel):
    id: str
    title: str
    summary: str


class ShareGenerateResponse(BaseModel):
    share_id: str
    audience: str
    method: str
    title: str
    subtitle: str
    privacy_note: str
    secure_link_url: str
    share_text: str
    email_subject: str
    email_body: str
    report_file_name: str
    report_pdf_base64: str
    sections: list[ShareGeneratedSectionResponse] = Field(default_factory=list)


class FriendUserSummary(BaseModel):
    id: str
    display_name: str
    first_name: str | None = None


class FriendConnectionResponse(BaseModel):
    id: str
    status: str
    compare_enabled: bool
    compare_permission_granted_by_me: bool
    compare_permission_granted_by_friend: bool
    created_at: datetime
    updated_at: datetime
    friend: FriendUserSummary


class FriendNetworkResponse(BaseModel):
    friends: list[FriendConnectionResponse] = Field(default_factory=list)
    incoming_requests: list[FriendConnectionResponse] = Field(default_factory=list)
    outgoing_requests: list[FriendConnectionResponse] = Field(default_factory=list)


class FriendRequestCreateRequest(BaseModel):
    email: str = Field(min_length=3)


class ComparisonPermissionUpdateRequest(BaseModel):
    enabled: bool


class ComparisonMetricResponse(BaseModel):
    label: str
    mine: str
    friend: str
    summary: str


class ComparisonSummaryResponse(BaseModel):
    friend: FriendUserSummary
    compare_enabled: bool
    headline: str
    summary: str
    similarities: list[str] = Field(default_factory=list)
    differences: list[str] = Field(default_factory=list)
    metrics: list[ComparisonMetricResponse] = Field(default_factory=list)
    safe_notice: str


class ReferralClaimRequest(BaseModel):
    referral_code: str = Field(min_length=4, max_length=32)
    source: str | None = None
    deep_link_id: str | None = None


class ReferralStatusResponse(BaseModel):
    referral_code: str
    invite_link: str
    qualified_invites_count: int
    rewarded_milestones: int
    invites_until_next_reward: int
    next_reward_days: int = 30
    total_premium_days_earned: int
    reward_progress_target: int = 5
    claimed_referral_code: str | None = None
    claimed_inviter_name: str | None = None
