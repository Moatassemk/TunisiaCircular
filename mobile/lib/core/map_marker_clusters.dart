class ProjectedMapMarker {
  const ProjectedMapMarker({
    required this.item,
    required this.x,
    required this.y,
  });
  final Map<String, dynamic> item;
  final double x;
  final double y;
}

List<List<ProjectedMapMarker>> clusterMapMarkers(
  Iterable<ProjectedMapMarker> markers, {
  required double cellSize,
}) {
  if (cellSize <= 0) throw ArgumentError.value(cellSize, 'cellSize');
  final cells = <String, List<ProjectedMapMarker>>{};
  for (final marker in markers) {
    final key =
        '${(marker.x / cellSize).floor()}:${(marker.y / cellSize).floor()}';
    cells.putIfAbsent(key, () => []).add(marker);
  }
  return cells.values.toList(growable: false);
}
