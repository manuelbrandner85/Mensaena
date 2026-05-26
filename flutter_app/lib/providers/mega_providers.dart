/// SKILL: mensaena-features
/// Riverpod-Provider für Phase-2-12 Mega-Features.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mega_models.dart';
import '../repositories/mega_repositories.dart';

// F36 Follows
final isFollowingProvider =
    FutureProvider.family.autoDispose<bool, String>((ref, otherUserId) async {
  return FollowsRepository.isFollowing(otherUserId);
});
final followCountsProvider = FutureProvider.family
    .autoDispose<({int followers, int following}), String>((ref, userId) async {
  return FollowsRepository.counts(userId);
});

// F37 Profile-Views
final myWeeklyViewsProvider = FutureProvider.autoDispose<int>((ref) async {
  return ProfileViewsRepository.myWeeklyViews();
});

// F47 Daily-Challenges
final todayChallengesProvider =
    FutureProvider.autoDispose<List<DailyChallenge>>((ref) async {
  return DailyChallengesRepository.todayChallenges();
});

// F71 Thank-You-Cards
final thankYouCardsProvider =
    FutureProvider.autoDispose<List<ThankYouCard>>((ref) async {
  return ThankYouCardsRepository.received();
});

// F72 Community-Polls
final activeCommunityPollsProvider =
    FutureProvider.autoDispose<List<CommunityPoll>>((ref) async {
  return CommunityPollsRepository.listActive();
});
final pollVoteCountsProvider =
    FutureProvider.family.autoDispose<Map<int, int>, String>((ref, pollId) async {
  return CommunityPollsRepository.voteCounts(pollId);
});
final myPollVoteProvider =
    FutureProvider.family.autoDispose<int?, String>((ref, pollId) async {
  return CommunityPollsRepository.myVote(pollId);
});

// F59 Stories
final activeStoriesProvider =
    FutureProvider.autoDispose<List<Story>>((ref) async {
  return StoriesRepository.active();
});

// F69 Mentorships
final myMentorshipsProvider =
    FutureProvider.autoDispose<List<Mentorship>>((ref) async {
  return MentorshipsRepository.mine();
});

// F16 Livestream-Messages
final livestreamMessagesProvider =
    StreamProvider.family.autoDispose<List<LivestreamMessage>, String>(
        (ref, roomId) {
  return LivestreamMessagesRepository.watch(roomId);
});

// F84 Livestream-Gifts
final livestreamGiftsProvider =
    StreamProvider.family.autoDispose<List<Map<String, dynamic>>, String>(
        (ref, roomId) {
  return LivestreamGiftsRepository.watch(roomId);
});

// F46 Leaderboard
final leaderboardProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return LeaderboardRepository.topThisWeek();
});
