import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'map_tile_config.dart';

class OsmTile extends StatefulWidget {
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
  State<OsmTile> createState() => _OsmTileState();
}

class _OsmTileState extends State<OsmTile> {
  late Future<Uint8List> tile;

  @override
  void initState() {
    super.initState();
    tile = _TileCache.load(widget.zoom, widget.x, widget.y);
  }

  @override
  void didUpdateWidget(covariant OsmTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoom != widget.zoom ||
        oldWidget.x != widget.x ||
        oldWidget.y != widget.y) {
      tile = _TileCache.load(widget.zoom, widget.x, widget.y);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: tile,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      }
      return Container(
        color: const Color(0xffe4ece6),
        child: Center(
          child: snapshot.hasError
              ? const Icon(Icons.map_outlined, color: Color(0xffa8b5ab))
              : const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
        ),
      );
    },
  );
}

class _TileCache {
  static final Map<String, Future<Uint8List>> _pending = {};
  static final HttpClient _client = HttpClient();

  static Future<Uint8List> load(int zoom, int x, int y) async {
    final key = '$zoom/$x/$y';
    final existing = _pending[key];
    if (existing != null) return existing;
    final request = _load(key, zoom, x, y);
    _pending[key] = request;
    try {
      return await request;
    } finally {
      if (identical(_pending[key], request)) _pending.remove(key);
    }
  }

  static Future<Uint8List> _load(String key, int zoom, int x, int y) async {
    final directory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}clac-map-tiles',
    );
    await directory.create(recursive: true);
    final safeKey = mapTileUrl(
      zoom,
      x,
      y,
    ).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
    final imageFile = File(
      '${directory.path}${Platform.pathSeparator}$safeKey.png',
    );
    final metadataFile = File(
      '${directory.path}${Platform.pathSeparator}$safeKey.json',
    );
    Map<String, dynamic> metadata = {};
    if (await metadataFile.exists()) {
      try {
        metadata =
            jsonDecode(await metadataFile.readAsString())
                as Map<String, dynamic>;
      } catch (_) {
        metadata = {};
      }
    }

    final imageExists = await imageFile.exists();
    if (imageExists) {
      final expiry = DateTime.tryParse(metadata['expiresAt']?.toString() ?? '');
      if (expiry != null && expiry.isAfter(DateTime.now())) {
        return imageFile.readAsBytes();
      }
      await imageFile.delete();
      if (await metadataFile.exists()) await metadataFile.delete();
    }

    final request = await _client.getUrl(Uri.parse(mapTileUrl(zoom, x, y)));
    request.headers.set(HttpHeaders.userAgentHeader, mapTileUserAgent);
    if (imageExists && metadata['etag'] != null) {
      request.headers.set(
        HttpHeaders.ifNoneMatchHeader,
        metadata['etag'].toString(),
      );
    }
    if (imageExists && metadata['lastModified'] != null) {
      request.headers.set(
        HttpHeaders.ifModifiedSinceHeader,
        metadata['lastModified'].toString(),
      );
    }
    final response = await request.close();
    if (response.statusCode == HttpStatus.notModified && imageExists) {
      final bytes = await imageFile.readAsBytes();
      final renewedMetadata = _metadata(response.headers, previous: metadata);
      if (renewedMetadata['cacheable'] == true) {
        await _writeMetadata(metadataFile, renewedMetadata);
      } else {
        await imageFile.delete();
        if (await metadataFile.exists()) await metadataFile.delete();
      }
      return bytes;
    }
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Map tile request failed (${response.statusCode})');
    }
    final bytes = await response
        .fold<BytesBuilder>(
          BytesBuilder(),
          (builder, chunk) => builder..add(chunk),
        )
        .then((builder) => builder.takeBytes());
    final cacheMetadata = _metadata(response.headers);
    if (cacheMetadata['cacheable'] == true) {
      await imageFile.writeAsBytes(bytes, flush: true);
      await _writeMetadata(metadataFile, cacheMetadata);
    } else {
      if (imageExists) await imageFile.delete();
      if (await metadataFile.exists()) await metadataFile.delete();
    }
    return bytes;
  }

  static Map<String, dynamic> _metadata(
    HttpHeaders headers, {
    Map<String, dynamic> previous = const {},
  }) {
    final cacheControl = headers.value(HttpHeaders.cacheControlHeader) ?? '';
    final noStore = cacheControl.toLowerCase().contains('no-store');
    final maxAge = RegExp(
      r'(?:^|,\s*)max-age=(\d+)',
      caseSensitive: false,
    ).firstMatch(cacheControl)?.group(1);
    DateTime? expires;
    if (maxAge != null) {
      expires = DateTime.now().add(
        Duration(seconds: int.tryParse(maxAge) ?? 0),
      );
    } else {
      final expiresHeader = headers.value(HttpHeaders.expiresHeader);
      if (expiresHeader != null) {
        try {
          expires = HttpDate.parse(expiresHeader);
        } catch (_) {
          expires = null;
        }
      }
    }
    expires ??= DateTime.now();
    if (cacheControl.toLowerCase().contains('no-cache')) {
      expires = DateTime.now();
    }
    final explicitFreshness =
        maxAge != null || headers.value(HttpHeaders.expiresHeader) != null;
    return {
      'cacheable': !noStore && explicitFreshness,
      'expiresAt': expires.toIso8601String(),
      'etag': headers.value(HttpHeaders.etagHeader) ?? previous['etag'],
      'lastModified':
          headers.value(HttpHeaders.lastModifiedHeader) ??
          previous['lastModified'],
    };
  }

  static Future<void> _writeMetadata(
    File file,
    Map<String, dynamic> metadata,
  ) async {
    await file.writeAsString(jsonEncode(metadata), flush: true);
  }
}
