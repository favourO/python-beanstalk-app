class ShareInsightCardModel {
  const ShareInsightCardModel({
    required this.title,
    required this.value,
    this.subtitle,
    this.accent,
  });

  factory ShareInsightCardModel.fromJson(Map<String, dynamic> json) {
    return ShareInsightCardModel(
      title: (json['title'] as String?)?.trim() ?? '',
      value: (json['value'] as String?)?.trim() ?? '',
      subtitle: (json['subtitle'] as String?)?.trim(),
      accent: (json['accent'] as String?)?.trim(),
    );
  }

  final String title;
  final String value;
  final String? subtitle;
  final String? accent;
}

class ShareInsightModel {
  const ShareInsightModel({
    required this.shareId,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.privacyNote,
    required this.deepLinkUrl,
    required this.cards,
    required this.tags,
  });

  factory ShareInsightModel.fromJson(Map<String, dynamic> json) {
    final rawCards =
        (json['cards'] is List ? json['cards'] as List : const [])
            .whereType<Map>()
            .map(
              (item) => ShareInsightCardModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
    final rawTags =
        (json['tags'] is List ? json['tags'] as List : const [])
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
    return ShareInsightModel(
      shareId: (json['share_id'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      subtitle: (json['subtitle'] as String?)?.trim() ?? '',
      summary: (json['summary'] as String?)?.trim() ?? '',
      privacyNote: (json['privacy_note'] as String?)?.trim() ?? '',
      deepLinkUrl: (json['deep_link_url'] as String?)?.trim() ?? '',
      cards: rawCards,
      tags: rawTags,
    );
  }

  final String shareId;
  final String title;
  final String subtitle;
  final String summary;
  final String privacyNote;
  final String deepLinkUrl;
  final List<ShareInsightCardModel> cards;
  final List<String> tags;
}

class ShareSectionOptionModel {
  const ShareSectionOptionModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.selectedByDefault,
  });

  factory ShareSectionOptionModel.fromJson(Map<String, dynamic> json) {
    return ShareSectionOptionModel(
      id: (json['id'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      subtitle: (json['subtitle'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim() ?? '',
      selectedByDefault: json['selected_by_default'] != false,
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final bool selectedByDefault;
}

class ShareAudienceOptionModel {
  const ShareAudienceOptionModel({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  factory ShareAudienceOptionModel.fromJson(Map<String, dynamic> json) {
    return ShareAudienceOptionModel(
      id: (json['id'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      subtitle: (json['subtitle'] as String?)?.trim() ?? '',
    );
  }

  final String id;
  final String title;
  final String subtitle;
}

class ShareMethodOptionModel {
  const ShareMethodOptionModel({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  factory ShareMethodOptionModel.fromJson(Map<String, dynamic> json) {
    return ShareMethodOptionModel(
      id: (json['id'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      subtitle: (json['subtitle'] as String?)?.trim() ?? '',
    );
  }

  final String id;
  final String title;
  final String subtitle;
}

class ShareCycleCountOptionModel {
  const ShareCycleCountOptionModel({required this.value, required this.label});

  factory ShareCycleCountOptionModel.fromJson(Map<String, dynamic> json) {
    return ShareCycleCountOptionModel(
      value: (json['value'] as num?)?.toInt() ?? 1,
      label: (json['label'] as String?)?.trim() ?? '',
    );
  }

  final int value;
  final String label;
}

class ShareInsightConfigModel {
  const ShareInsightConfigModel({
    required this.screenTitle,
    required this.screenSubtitle,
    required this.heroTitle,
    required this.heroBody,
    required this.privacyNote,
    required this.sections,
    required this.audiences,
    required this.methods,
    required this.cycleCountOptions,
    required this.defaultAudience,
    required this.defaultMethod,
    required this.defaultCycleCount,
  });

  factory ShareInsightConfigModel.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) parser) {
      return (json[key] is List ? json[key] as List : const [])
          .whereType<Map>()
          .map((item) => parser(Map<String, dynamic>.from(item)))
          .toList();
    }

    return ShareInsightConfigModel(
      screenTitle: (json['screen_title'] as String?)?.trim() ?? '',
      screenSubtitle: (json['screen_subtitle'] as String?)?.trim() ?? '',
      heroTitle: (json['hero_title'] as String?)?.trim() ?? '',
      heroBody: (json['hero_body'] as String?)?.trim() ?? '',
      privacyNote: (json['privacy_note'] as String?)?.trim() ?? '',
      sections: parseList('sections', ShareSectionOptionModel.fromJson),
      audiences: parseList('audiences', ShareAudienceOptionModel.fromJson),
      methods: parseList('methods', ShareMethodOptionModel.fromJson),
      cycleCountOptions: parseList(
        'cycle_count_options',
        ShareCycleCountOptionModel.fromJson,
      ),
      defaultAudience: (json['default_audience'] as String?)?.trim() ?? '',
      defaultMethod: (json['default_method'] as String?)?.trim() ?? '',
      defaultCycleCount: (json['default_cycle_count'] as num?)?.toInt() ?? 3,
    );
  }

  final String screenTitle;
  final String screenSubtitle;
  final String heroTitle;
  final String heroBody;
  final String privacyNote;
  final List<ShareSectionOptionModel> sections;
  final List<ShareAudienceOptionModel> audiences;
  final List<ShareMethodOptionModel> methods;
  final List<ShareCycleCountOptionModel> cycleCountOptions;
  final String defaultAudience;
  final String defaultMethod;
  final int defaultCycleCount;
}

class ShareGeneratedSectionModel {
  const ShareGeneratedSectionModel({
    required this.id,
    required this.title,
    required this.summary,
  });

  factory ShareGeneratedSectionModel.fromJson(Map<String, dynamic> json) {
    return ShareGeneratedSectionModel(
      id: (json['id'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      summary: (json['summary'] as String?)?.trim() ?? '',
    );
  }

  final String id;
  final String title;
  final String summary;
}

class ShareGenerateResultModel {
  const ShareGenerateResultModel({
    required this.shareId,
    required this.audience,
    required this.method,
    required this.title,
    required this.subtitle,
    required this.privacyNote,
    required this.secureLinkUrl,
    required this.shareText,
    required this.emailSubject,
    required this.emailBody,
    required this.reportFileName,
    required this.reportPdfBase64,
    required this.sections,
  });

  factory ShareGenerateResultModel.fromJson(Map<String, dynamic> json) {
    final rawSections =
        (json['sections'] is List ? json['sections'] as List : const [])
            .whereType<Map>()
            .map(
              (item) => ShareGeneratedSectionModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
    return ShareGenerateResultModel(
      shareId: (json['share_id'] as String?)?.trim() ?? '',
      audience: (json['audience'] as String?)?.trim() ?? '',
      method: (json['method'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      subtitle: (json['subtitle'] as String?)?.trim() ?? '',
      privacyNote: (json['privacy_note'] as String?)?.trim() ?? '',
      secureLinkUrl: (json['secure_link_url'] as String?)?.trim() ?? '',
      shareText: (json['share_text'] as String?)?.trim() ?? '',
      emailSubject: (json['email_subject'] as String?)?.trim() ?? '',
      emailBody: (json['email_body'] as String?)?.trim() ?? '',
      reportFileName: (json['report_file_name'] as String?)?.trim() ?? '',
      reportPdfBase64: (json['report_pdf_base64'] as String?)?.trim() ?? '',
      sections: rawSections,
    );
  }

  final String shareId;
  final String audience;
  final String method;
  final String title;
  final String subtitle;
  final String privacyNote;
  final String secureLinkUrl;
  final String shareText;
  final String emailSubject;
  final String emailBody;
  final String reportFileName;
  final String reportPdfBase64;
  final List<ShareGeneratedSectionModel> sections;
}

class FriendSummary {
  const FriendSummary({
    required this.id,
    required this.displayName,
    this.firstName,
  });

  factory FriendSummary.fromJson(Map<String, dynamic> json) {
    return FriendSummary(
      id: (json['id'] as String?)?.trim() ?? '',
      displayName: (json['display_name'] as String?)?.trim() ?? 'Vyla friend',
      firstName: (json['first_name'] as String?)?.trim(),
    );
  }

  final String id;
  final String displayName;
  final String? firstName;
}

class FriendConnectionModel {
  const FriendConnectionModel({
    required this.id,
    required this.status,
    required this.compareEnabled,
    required this.comparePermissionGrantedByMe,
    required this.comparePermissionGrantedByFriend,
    required this.createdAt,
    required this.updatedAt,
    required this.friend,
  });

  factory FriendConnectionModel.fromJson(Map<String, dynamic> json) {
    return FriendConnectionModel(
      id: (json['id'] as String?)?.trim() ?? '',
      status: (json['status'] as String?)?.trim() ?? 'pending',
      compareEnabled: json['compare_enabled'] == true,
      comparePermissionGrantedByMe:
          json['compare_permission_granted_by_me'] == true,
      comparePermissionGrantedByFriend:
          json['compare_permission_granted_by_friend'] == true,
      createdAt:
          DateTime.tryParse((json['created_at'] as String?)?.trim() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((json['updated_at'] as String?)?.trim() ?? '') ??
          DateTime.now(),
      friend: FriendSummary.fromJson(
        Map<String, dynamic>.from((json['friend'] as Map?) ?? const {}),
      ),
    );
  }

  final String id;
  final String status;
  final bool compareEnabled;
  final bool comparePermissionGrantedByMe;
  final bool comparePermissionGrantedByFriend;
  final DateTime createdAt;
  final DateTime updatedAt;
  final FriendSummary friend;
}

class FriendNetworkModel {
  const FriendNetworkModel({
    required this.friends,
    required this.incomingRequests,
    required this.outgoingRequests,
  });

  factory FriendNetworkModel.fromJson(Map<String, dynamic> json) {
    List<FriendConnectionModel> parseList(String key) {
      return (json[key] is List ? json[key] as List : const [])
          .whereType<Map>()
          .map(
            (item) =>
                FriendConnectionModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    return FriendNetworkModel(
      friends: parseList('friends'),
      incomingRequests: parseList('incoming_requests'),
      outgoingRequests: parseList('outgoing_requests'),
    );
  }

  final List<FriendConnectionModel> friends;
  final List<FriendConnectionModel> incomingRequests;
  final List<FriendConnectionModel> outgoingRequests;
}

class ComparisonMetricModel {
  const ComparisonMetricModel({
    required this.label,
    required this.mine,
    required this.friend,
    required this.summary,
  });

  factory ComparisonMetricModel.fromJson(Map<String, dynamic> json) {
    return ComparisonMetricModel(
      label: (json['label'] as String?)?.trim() ?? '',
      mine: (json['mine'] as String?)?.trim() ?? '',
      friend: (json['friend'] as String?)?.trim() ?? '',
      summary: (json['summary'] as String?)?.trim() ?? '',
    );
  }

  final String label;
  final String mine;
  final String friend;
  final String summary;
}

class ComparisonSummaryModel {
  const ComparisonSummaryModel({
    required this.friend,
    required this.compareEnabled,
    required this.headline,
    required this.summary,
    required this.similarities,
    required this.differences,
    required this.metrics,
    required this.safeNotice,
  });

  factory ComparisonSummaryModel.fromJson(Map<String, dynamic> json) {
    return ComparisonSummaryModel(
      friend: FriendSummary.fromJson(
        Map<String, dynamic>.from((json['friend'] as Map?) ?? const {}),
      ),
      compareEnabled: json['compare_enabled'] == true,
      headline: (json['headline'] as String?)?.trim() ?? '',
      summary: (json['summary'] as String?)?.trim() ?? '',
      similarities:
          (json['similarities'] is List
                  ? json['similarities'] as List
                  : const [])
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
      differences:
          (json['differences'] is List ? json['differences'] as List : const [])
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
      metrics:
          (json['metrics'] is List ? json['metrics'] as List : const [])
              .whereType<Map>()
              .map(
                (item) => ComparisonMetricModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      safeNotice: (json['safe_notice'] as String?)?.trim() ?? '',
    );
  }

  final FriendSummary friend;
  final bool compareEnabled;
  final String headline;
  final String summary;
  final List<String> similarities;
  final List<String> differences;
  final List<ComparisonMetricModel> metrics;
  final String safeNotice;
}

class ReferralStatusModel {
  const ReferralStatusModel({
    required this.referralCode,
    required this.inviteLink,
    required this.qualifiedInvitesCount,
    required this.rewardedMilestones,
    required this.invitesUntilNextReward,
    required this.nextRewardDays,
    required this.totalPremiumDaysEarned,
    required this.rewardProgressTarget,
    this.claimedReferralCode,
    this.claimedInviterName,
  });

  factory ReferralStatusModel.fromJson(Map<String, dynamic> json) {
    return ReferralStatusModel(
      referralCode: (json['referral_code'] as String?)?.trim() ?? '',
      inviteLink: (json['invite_link'] as String?)?.trim() ?? '',
      qualifiedInvitesCount:
          (json['qualified_invites_count'] as num?)?.toInt() ?? 0,
      rewardedMilestones: (json['rewarded_milestones'] as num?)?.toInt() ?? 0,
      invitesUntilNextReward:
          (json['invites_until_next_reward'] as num?)?.toInt() ?? 0,
      nextRewardDays: (json['next_reward_days'] as num?)?.toInt() ?? 30,
      totalPremiumDaysEarned:
          (json['total_premium_days_earned'] as num?)?.toInt() ?? 0,
      rewardProgressTarget:
          (json['reward_progress_target'] as num?)?.toInt() ?? 5,
      claimedReferralCode: (json['claimed_referral_code'] as String?)?.trim(),
      claimedInviterName: (json['claimed_inviter_name'] as String?)?.trim(),
    );
  }

  final String referralCode;
  final String inviteLink;
  final int qualifiedInvitesCount;
  final int rewardedMilestones;
  final int invitesUntilNextReward;
  final int nextRewardDays;
  final int totalPremiumDaysEarned;
  final int rewardProgressTarget;
  final String? claimedReferralCode;
  final String? claimedInviterName;
}
