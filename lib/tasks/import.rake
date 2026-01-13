namespace :import do
  desc "Import all GeoJSON data (country boundary, protected areas, national parks, military areas)"
  task all: :environment do
    Rake::Task["import:country_boundary"].invoke
    Rake::Task["import:protected_areas"].invoke
    Rake::Task["import:national_parks"].invoke
    Rake::Task["import:military_areas"].invoke
    puts "\nAll imports complete!"
  end

  desc "Import country boundary from GeoJSON file"
  task country_boundary: :environment do
    file_path = ENV["BOUNDARY_PATH"] || Rails.root.join("data", "czech_boundary.geojson")

    unless File.exist?(file_path)
      puts "Error: File not found at #{file_path}"
      exit 1
    end

    puts "Reading GeoJSON from #{file_path}..."
    geojson = JSON.parse(File.read(file_path))
    feature = geojson["features"].first
    properties = feature["properties"]
    geometry_data = feature["geometry"]

    code = properties["ISO3166-1"] || "CZ"
    name = properties["name"] || "Czechia"

    puts "Importing boundary for #{name} (#{code})..."

    geometry_json = geometry_data.to_json

    CountryBoundary.where(code: code).delete_all

    ActiveRecord::Base.connection.exec_query(
      <<~SQL,
        INSERT INTO country_boundaries (code, name, geometry, created_at, updated_at)
        VALUES ($1, $2, ST_SetSRID(ST_GeomFromGeoJSON($3), 4326)::geography, NOW(), NOW())
      SQL
      "SQL",
      [ code, name, geometry_json ]
    )

    puts "Successfully imported #{name} boundary!"
  end

  desc "Import protected areas from GeoJSON file"
  task protected_areas: :environment do
    file_path = ENV["GEOJSON_PATH"] || Rails.root.join("data", "protected_areas.geojson")

    unless File.exist?(file_path)
      puts "Error: File not found at #{file_path}"
      puts "Set GEOJSON_PATH environment variable or ensure file exists"
      exit 1
    end

    puts "Reading GeoJSON from #{file_path}..."
    file_content = File.read(file_path)

    puts "Parsing GeoJSON..."
    geojson = RGeo::GeoJSON.decode(file_content, geo_factory: geo_factory)

    unless geojson
      puts "Error: Failed to parse GeoJSON"
      exit 1
    end

    puts "Found #{geojson.count} features to import"

    # Clear existing data
    puts "Clearing existing protected areas..."
    ProtectedArea.delete_all

    imported = 0
    skipped = 0
    errors = 0

    geojson.each_with_index do |feature, index|
      properties = feature.properties
      geometry = feature.geometry

      unless geometry
        skipped += 1
        next
      end

      multi_geometry = case geometry.geometry_type.to_s
      when "Polygon"
        geo_factory.multi_polygon([ geometry ])
      when "MultiPolygon"
        geometry
      else
        puts "  Skipping #{properties['name']}: unsupported geometry type #{geometry.geometry_type}"
        skipped += 1
        next
      end

      begin
        ProtectedArea.create!(
          name: properties["name"] || "Unknown",
          protect_class: properties["protect_class"],
          protection_title: properties["protection_title"],
          country: "CZ",
          osm_id: properties["@id"],
          geometry: multi_geometry
        )
        imported += 1

        if (imported % 100).zero?
          puts "  Imported #{imported} areas..."
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
        puts "  Error importing #{properties['name']}: #{e.message}"
        errors += 1
      end
    end

    puts "\nImport complete!"
    puts "  Imported: #{imported}"
    puts "  Skipped: #{skipped}"
    puts "  Errors: #{errors}"
  end

  desc "Import national parks from GeoJSON file (appends to existing data)"
  task national_parks: :environment do
    file_path = ENV["NP_PATH"] || Rails.root.join("data", "national_parks.geojson")

    unless File.exist?(file_path)
      puts "Error: File not found at #{file_path}"
      exit 1
    end

    puts "Reading GeoJSON from #{file_path}..."
    file_content = File.read(file_path)
    geojson = RGeo::GeoJSON.decode(file_content, geo_factory: geo_factory)

    puts "Found #{geojson.count} features"

    imported = 0
    skipped = 0

    geojson.each do |feature|
      properties = feature.properties
      geometry = feature.geometry
      name = properties["name"]

      # Skip non-Czech parks
      unless name&.match?(/Národní park|Krkonošský|NP Podyjí|Klidová zóna/i)
        puts "  Skipping foreign: #{name}"
        skipped += 1
        next
      end

      # Skip if already exists
      if ProtectedArea.exists?(osm_id: properties["@id"])
        puts "  Already exists: #{name}"
        skipped += 1
        next
      end

      unless geometry
        skipped += 1
        next
      end

      multi_geometry = case geometry.geometry_type.to_s
      when "Polygon"
        geo_factory.multi_polygon([ geometry ])
      when "MultiPolygon"
        geometry
      else
        puts "  Skipping #{name}: unsupported geometry type #{geometry.geometry_type}"
        skipped += 1
        next
      end

      begin
        ProtectedArea.create!(
          name: name,
          protect_class: properties["protect_class"] || "2",
          protection_title: properties["protection_title"].presence || "národní park",
          country: "CZ",
          osm_id: properties["@id"],
          geometry: multi_geometry
        )
        puts "  Imported: #{name}"
        imported += 1
      rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
        puts "  Error importing #{name}: #{e.message}"
      end
    end

    puts "\nImport complete!"
    puts "  Imported: #{imported}"
    puts "  Skipped: #{skipped}"
  end

  desc "Import military areas from GeoJSON file"
  task military_areas: :environment do
    file_path = ENV["MILITARY_PATH"] || Rails.root.join("data", "military_areas.geojson")

    unless File.exist?(file_path)
      puts "Error: File not found at #{file_path}"
      puts ""
      puts "To get military area data, run this Overpass query at https://overpass-turbo.eu/"
      puts "and export as GeoJSON:"
      puts ""
      puts "  [out:json][timeout:60];"
      puts "  area['ISO3166-1'='CZ']->.cz;"
      puts "  ("
      puts "    relation['boundary'='military'](area.cz);"
      puts "  );"
      puts "  out geom;"
      puts ""
      exit 1
    end

    puts "Reading GeoJSON from #{file_path}..."
    geojson = JSON.parse(File.read(file_path))
    features = geojson["features"] || []

    puts "Found #{features.count} military area features to import"

    # Clear existing data
    puts "Clearing existing military area data..."
    MilitaryArea.delete_all

    imported = 0
    skipped = 0
    errors = 0

    features.each_with_index do |feature, index|
      properties = feature["properties"] || {}
      geometry_data = feature["geometry"]

      unless geometry_data && %w[Polygon MultiPolygon].include?(geometry_data["type"])
        skipped += 1
        next
      end

      osm_id = properties["@id"] || "military_#{index}"
      name = properties["name"] || "Unknown Military Area"

      # Convert MultiPolygon to Polygon if needed (take first polygon)
      if geometry_data["type"] == "MultiPolygon"
        geometry_data = {
          "type" => "Polygon",
          "coordinates" => geometry_data["coordinates"].first
        }
      end

      geometry_json = geometry_data.to_json

      begin
        ActiveRecord::Base.connection.exec_query(
          <<~SQL,
            INSERT INTO military_areas (osm_id, name, geometry, created_at, updated_at)
            VALUES ($1, $2, ST_SetSRID(ST_GeomFromGeoJSON($3), 4326)::geography, NOW(), NOW())
            ON CONFLICT (osm_id) DO NOTHING
          SQL
          "SQL",
          [ osm_id, name, geometry_json ]
        )
        imported += 1
        puts "  Imported: #{name}"
      rescue ActiveRecord::StatementInvalid, JSON::ParserError => e
        puts "  Error importing #{name}: #{e.message}" if errors < 10
        errors += 1
      end
    end

    puts "\nImport complete!"
    puts "  Imported: #{imported}"
    puts "  Skipped: #{skipped}"
    puts "  Errors: #{errors}"
    puts "  Total in DB: #{MilitaryArea.count}"
  end

  private

  def geo_factory
    @geo_factory ||= RGeo::Geographic.spherical_factory(srid: 4326)
  end
end
