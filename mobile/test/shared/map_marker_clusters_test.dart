import 'package:clac_mobile/shared/map_marker_clusters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups nearby map pins and keeps distant pins separate', () {
    final markers = [
      const ProjectedMapMarker(item: {'id': 'a'}, x: 20, y: 20),
      const ProjectedMapMarker(item: {'id': 'b'}, x: 35, y: 30),
      const ProjectedMapMarker(item: {'id': 'c'}, x: 160, y: 140),
    ];

    final groups = clusterMapMarkers(markers, cellSize: 44);

    expect(groups, hasLength(2));
    expect(groups.map((group) => group.length).toSet(), {1, 2});
  });

  test('rejects invalid cluster sizes', () {
    expect(() => clusterMapMarkers(const [], cellSize: 0), throwsArgumentError);
  });
}
