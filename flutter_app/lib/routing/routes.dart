/// Zentrale Liste aller Routen-Pfade. 1:1 zur Next.js-App-Router-Struktur.
/// Wenn ein Pfad in der Web-App umbenannt wird, hier ebenfalls anpassen.
class Routes {
  Routes._();

  // Public
  static const root = '/';
  static const landing = '/landing';
  static const login = '/login';
  static const register = '/register';
  static const auth = '/auth'; // ?mode=login|register
  static const download = '/download';
  static const search = '/search';
  static const spenden = '/spenden';
  static const unsubscribe = '/unsubscribe';
  static const liveEnded = '/live-ended';
  static const app = '/app';

  // Legal
  static const about = '/about';
  static const agb = '/agb';
  static const datenschutz = '/datenschutz';
  static const impressum = '/impressum';
  static const kontakt = '/kontakt';
  static const haftungsausschluss = '/haftungsausschluss';
  static const nutzungsbedingungen = '/nutzungsbedingungen';
  static const communityGuidelines = '/community-guidelines';

  // Dashboard
  static const dashboard = '/dashboard';
  static const dashboardCreate = '/dashboard/create';
  static const dashboardNotifications = '/dashboard/notifications';
  static const dashboardMessages = '/dashboard/messages';
  static const dashboardChat = '/dashboard/chat';
  static const dashboardMatching = '/dashboard/matching';
  static const dashboardMap = '/dashboard/map';
  static const dashboardPosts = '/dashboard/posts';
  static const dashboardOrganizations = '/dashboard/organizations';
  static const dashboardOrganizationsSuggest = '/dashboard/organizations/suggest';
  static const dashboardInteractions = '/dashboard/interactions';
  static const dashboardAnimals = '/dashboard/animals';
  static const dashboardAnimalsCreate = '/dashboard/animals/create';
  static const dashboardCrisis = '/dashboard/crisis';
  static const dashboardCrisisCreate = '/dashboard/crisis/create';
  static const dashboardCrisisResources = '/dashboard/crisis/resources';
  static const dashboardMentalSupport = '/dashboard/mental-support';
  static const dashboardMentalSupportCreate = '/dashboard/mental-support/create';
  static const dashboardGroups = '/dashboard/groups';
  static const dashboardGroupsCreate = '/dashboard/groups/create';
  static const dashboardEvents = '/dashboard/events';
  static const dashboardEventsCreate = '/dashboard/events/create';
  static const dashboardBoard = '/dashboard/board';
  static const dashboardChallenges = '/dashboard/challenges';
  static const dashboardChallengesCreate = '/dashboard/challenges/create';
  static const dashboardSharing = '/dashboard/sharing';
  static const dashboardSharingCreate = '/dashboard/sharing/create';
  static const dashboardTimebank = '/dashboard/timebank';
  static const dashboardMarketplace = '/dashboard/marketplace';
  static const dashboardMarketplaceCreate = '/dashboard/marketplace/create';
  static const dashboardSupply = '/dashboard/supply';
  static const dashboardSupplyFarmAdd = '/dashboard/supply/farm/add';
  static const dashboardHarvest = '/dashboard/harvest';
  static const dashboardHarvestCreate = '/dashboard/harvest/create';
  static const dashboardRescuer = '/dashboard/rescuer';
  static const dashboardRescuerCreate = '/dashboard/rescuer/create';
  static const dashboardHousing = '/dashboard/housing';
  static const dashboardHousingCreate = '/dashboard/housing/create';
  static const dashboardMobility = '/dashboard/mobility';
  static const dashboardMobilityCreate = '/dashboard/mobility/create';
  static const dashboardJobs = '/dashboard/jobs';
  static const dashboardWiki = '/dashboard/wiki';
  static const dashboardWikiCreate = '/dashboard/wiki/create';
  static const dashboardKnowledge = '/dashboard/knowledge';
  static const dashboardKnowledgeCreate = '/dashboard/knowledge/create';
  static const dashboardSkills = '/dashboard/skills';
  static const dashboardSkillsCreate = '/dashboard/skills/create';
  static const dashboardCalendar = '/dashboard/calendar';
  static const dashboardCommunity = '/dashboard/community';
  static const dashboardCommunityCreate = '/dashboard/community/create';
  static const dashboardProfile = '/dashboard/profile';
  static const dashboardSettings = '/dashboard/settings';
  static const dashboardInvite = '/dashboard/invite';
  static const dashboardBadges = '/dashboard/badges';
  static const dashboardWarnungen = '/dashboard/warnungen';
  static const dashboardWarnungenFood = '/dashboard/warnungen/food';
  static const dashboardAdmin = '/dashboard/admin';
}
