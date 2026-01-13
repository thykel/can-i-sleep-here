# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Rails API that determines wild camping and bivouacking legality for GPS coordinates in the Czech Republic. Uses PostGIS spatial queries to check if locations fall within protected areas, military zones, or country boundaries, then applies Czech legal rules to determine verdicts.

## Common Commands

### Development (Docker)
```bash
# Start containers
docker compose up -d

# Run migrations
docker compose exec api bin/rails db:migrate

# Import GeoJSON data (required first time)
docker compose exec api rake import:all

# Rails console
docker compose exec api bin/rails console

# View logs
docker compose logs -f api

# Run tests
docker compose exec api bin/rails test

# Run single test file
docker compose exec api bin/rails test test/services/camping_rules_test.rb

# Linting
docker compose exec api bin/rubocop
```

### Testing
```bash
# All tests
bin/rails test

# Specific test file
bin/rails test test/services/camping_rules_test.rb

# Specific test method
bin/rails test test/services/camping_rules_test.rb:42
```

### Code Quality
```bash
# RuboCop (follows rails-omakase style)
bin/rubocop

# Security checks
bin/brakeman
bin/bundler-audit
```

## Architecture

### Core Data Flow

1. **Request** → `CheckController#index` validates coordinates
2. **Country Detection** → `CountryBoundary.country_for_point(lat, lng)` using PostGIS ST_Covers
3. **Restriction Checks** (in priority order):
   - Military zones: `MilitaryArea.military_area_for_point(lat, lng)`
   - Protected areas: `ProtectedArea.containing_point(lat, lng)`
4. **Rule Application** → `CampingRules.verdict_for_area(area)` applies Czech legal rules
5. **Response** → JSON with verdict, explanation, and area details

### Spatial Queries (PostGIS)

All models (`ProtectedArea`, `MilitaryArea`, `CountryBoundary`) use PostGIS `ST_Covers` for point-in-polygon checks:
```ruby
scope :containing_point, ->(lat, lng) {
  where("ST_Covers(geometry, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography)", lng, lat)
}
```

### Camping Rules Logic (`app/services/camping_rules.rb`)

The core business logic applies Czech legal rules based on Act 114/1992 Coll. and the 2008 Hyťha case precedent.

**Czech Category Detection:**
- **Priority 1:** Match `protection_title` field (e.g., "Chráněná krajinná oblast")
- **Priority 2:** Match name prefix (e.g., "NPR Xyz", "CHKO Abc")
- **Fallback:** Use IUCN `protect_class` (numeric 1a-5)

**Verdict Hierarchy:**
1. `forbidden` - Strict prohibition (NPR, NPP, NP, PR, PP, Military)
2. `gray` - Tolerated but not officially permitted
3. `allowed` - Generally tolerated (CHKO, outside protected areas)
4. `unsupported` - Outside Czech Republic

**Key Method:** `most_restrictive_verdict(verdicts)` - When multiple areas overlap, the most restrictive verdict wins (e.g., if a location is in both a CHKO and NPR, the NPR's "forbidden" verdict takes precedence).

### Data Import (`lib/tasks/import.rake`)

Imports GeoJSON data into PostGIS-enabled tables:
- `rake import:country_boundary` - Czech boundary from `data/czech_boundary.geojson`
- `rake import:protected_areas` - Protected areas from `data/protected_areas.geojson`
- `rake import:national_parks` - National parks from `data/national_parks.geojson`
- `rake import:military_areas` - Military zones from `data/military_areas.geojson`
- `rake import:all` - Run all imports in order

**Important:** Protected areas are stored as `st_geography` MultiPolygons. Import converts Polygon → MultiPolygon for consistency.

### Frontend (`/map` endpoint)

Interactive Leaflet.js map that:
- Queries `/check?lat=X&lng=Y` on click
- Displays protected area boundaries from `/map/areas`
- Shows separate verdicts for bivouacking vs camping
- Supports URL parameters (`/map?lat=49.68&lng=13.82`)

## Database Schema

- `protected_areas` - PostGIS MultiPolygon geometries with GIST indexes
- `military_areas` - PostGIS Polygon geometries for restricted zones
- `country_boundaries` - Country border polygons for Czech Republic
- `forest_areas` - Unused table (forest data not yet implemented)

All spatial columns use SRID 4326 (WGS84) and have GIST indexes for performance.

## Testing Strategy

- Controller tests verify coordinate validation and API responses
- Service tests (`camping_rules_test.rb`) verify legal rule application
- Integration tests verify full check flow with PostGIS queries
- Model tests verify spatial scopes

When adding new protected area categories, update both `CampingRules::CZECH_CATEGORIES` and add corresponding test cases.
