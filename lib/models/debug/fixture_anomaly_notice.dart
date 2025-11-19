class FixtureAnomalyNotice {
  const FixtureAnomalyNotice({
    required this.fixtureId,
    required this.messages,
    required this.logPath,
    required this.timestamp,
  });

  final String fixtureId;
  final List<String> messages;
  final String logPath;
  final DateTime timestamp;
}
