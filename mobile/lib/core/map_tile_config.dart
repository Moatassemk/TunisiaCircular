const mapTileProvider = String.fromEnvironment(
  'MAP_TILE_PROVIDER',
  defaultValue: 'osm',
);
const mapTileApiKey = String.fromEnvironment('MAP_TILE_API_KEY');
const mapTileUrlTemplate = String.fromEnvironment(
  'MAP_TILE_URL_TEMPLATE',
  defaultValue: mapTileProvider == 'maptiler'
      ? 'https://api.maptiler.com/maps/streets-v4/256/{z}/{x}/{y}.png?key={key}'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);
const mapTileAttribution = String.fromEnvironment(
  'MAP_TILE_ATTRIBUTION',
  defaultValue: mapTileProvider == 'maptiler'
      ? '© MapTiler · © OpenStreetMap contributors'
      : '© OpenStreetMap contributors',
);
const mapTileUserAgent = String.fromEnvironment(
  'MAP_TILE_USER_AGENT',
  defaultValue: 'CLAC/1.0',
);

String mapTileUrl(int zoom, int x, int y) => mapTileUrlTemplate
    .replaceAll('{z}', '$zoom')
    .replaceAll('{x}', '$x')
    .replaceAll('{y}', '$y')
    .replaceAll('{key}', mapTileApiKey);

bool get mapTileProviderConfigured =>
    mapTileProvider != 'maptiler' || mapTileApiKey.isNotEmpty;
