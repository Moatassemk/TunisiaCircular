import 'package:flutter/material.dart';

import 'map_tile_config.dart';

/// Browser-native image loading lets OSM receive a normal browser User-Agent
/// and referrer. Keep attribution visible in the map screen.
class OsmTile extends StatelessWidget {
  const OsmTile({
    required this.zoom,
    required this.x,
    required this.y,
    super.key,
  });
  final int zoom;
  final int x;
  final int y;

  @override
  Widget build(BuildContext context) => Image.network(
    mapTileUrl(zoom, x, y),
    fit: BoxFit.cover,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => Container(
      color: const Color(0xffe4ece6),
      alignment: Alignment.center,
      child: const Icon(Icons.map_outlined, color: Color(0xffa8b5ab)),
    ),
    loadingBuilder: (context, child, progress) => progress == null
        ? child
        : Container(
            color: const Color(0xffe4ece6),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
  );
}
