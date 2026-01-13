class CampingRules
  VERDICTS = {
    allowed: "allowed",
    forbidden: "forbidden",
    gray: "gray",
    unsupported: "unsupported"
  }.freeze

  # Czech protection categories based on Act 114/1992 Coll.
  # Priority: Use protection_title (Czech category name) over IUCN protect_class
  # Rules based on Czech legal practice and 2008 Hyťha case precedent
  CZECH_CATEGORIES = {
    # Strictest - National Nature Reserves (Národní přírodní rezervace)
    # Entry often requires permit, camping strictly prohibited
    npr: {
      patterns: [ /národní přírodní rezervace/i, /\bNPR\b/ ],
      verdict: VERDICTS[:forbidden],
      explanation: "This is a National Nature Reserve (NPR - Národní přírodní rezervace). Bivouacking is prohibited. Rules here are stricter than in regular nature reserves."
    },
    # National Natural Monuments (Národní přírodní památka)
    # Protected geological/natural features, camping prohibited
    npp: {
      patterns: [ /národní přírodní památka/i, /\bNPP\b/ ],
      verdict: VERDICTS[:forbidden],
      explanation: "This is a National Natural Monument (NPP - Národní přírodní památka). Bivouacking is prohibited. Rules here are stricter than in regular nature monuments."
    },
    # National Parks (Národní park)
    # First zone: must stay on marked trails, camping prohibited except designated spots
    np: {
      patterns: [ /národní park/i, /\bNP\b/ ],
      verdict: VERDICTS[:forbidden],
      explanation: "This is a National Park (NP - Národní park). In the first zone, you must stay on marked trails and camping is prohibited. Use designated overnight spots (nocovište) - e.g., NP Šumava has several."
    },
    # Nature Reserves (Přírodní rezervace)
    # Stricter rules - should be avoided for camping
    pr: {
      patterns: [ /přírodní rezervace/i, /\bPR\b/ ],
      verdict: VERDICTS[:forbidden],
      explanation: "This is a Nature Reserve (PR - Přírodní rezervace). Rules are stricter here - exclude this area from your camping plans."
    },
    # Natural Monuments (Přírodní památka)
    # Stricter rules - should be avoided for camping
    pp: {
      patterns: [ /přírodní památka/i, /\bPP\b/ ],
      verdict: VERDICTS[:forbidden],
      explanation: "This is a Natural Monument (PP - Přírodní památka). Rules are stricter here - exclude this area from your camping plans."
    },
    # Protected Landscape Areas (Chráněná krajinná oblast)
    # Bivouacking allowed based on 2008 Hyťha case precedent
    chko: {
      patterns: [ /chráněná krajinná oblast/i, /\bCHKO\b/ ],
      verdict: VERDICTS[:allowed],
      explanation: "This is a Protected Landscape Area (CHKO - Chráněná krajinná oblast). Bivouacking is allowed here (confirmed by 2008 legal precedent). Stay one night, arrive late, leave early, leave no trace."
    }
  }.freeze

  # Fallback rules by IUCN protect_class (if protection_title doesn't match)
  RULES_BY_CLASS = {
    "CZ" => {
      "1a" => { verdict: VERDICTS[:forbidden], explanation: "Strict Nature Reserve. Bivouacking prohibited." },
      "1b" => { verdict: VERDICTS[:forbidden], explanation: "Wilderness Area. Bivouacking prohibited." },
      "2" => { verdict: VERDICTS[:forbidden], explanation: "National Park. Use designated overnight spots only." },
      "3" => { verdict: VERDICTS[:forbidden], explanation: "Nature Monument. Stricter rules apply - avoid camping here." },
      "4" => { verdict: VERDICTS[:forbidden], explanation: "Nature Reserve. Stricter rules apply - avoid camping here." },
      "5" => { verdict: VERDICTS[:allowed], explanation: "Protected Landscape Area (CHKO). Bivouacking is allowed." }
    }
  }.freeze

  DEFAULT_RULE = {
    verdict: VERDICTS[:gray],
    explanation: "No specific rules found for this area. Check local regulations."
  }.freeze

  OUTSIDE_PROTECTED_AREA = {
    verdict: VERDICTS[:allowed],
    explanation: "No protected area here. Bivouacking in forests is tolerated. In urban areas, municipal ordinances may prohibit outdoor sleeping. On private land, owner consent is recommended."
  }.freeze

  OUTSIDE_CZECHIA = {
    verdict: VERDICTS[:unsupported],
    explanation: "This location is outside Czechia. We currently only support camping rules for the Czech Republic."
  }.freeze

  IN_MILITARY_AREA = {
    verdict: VERDICTS[:forbidden],
    explanation: "This is a Military Training Area (Vojenský újezd). Entry is strictly prohibited without permission from the military authority. Trespassing is a criminal offense."
  }.freeze

  class << self
    def verdict_for_area(area)
      return DEFAULT_RULE unless area

      # First, try to match by Czech protection_title or name prefix
      category = detect_czech_category(area.protection_title, area.name)
      return CZECH_CATEGORIES[category] if category

      # Fallback to IUCN protect_class
      verdict_by_class(area.country, area.protect_class)
    end

    def verdict_by_class(country, protect_class)
      return DEFAULT_RULE unless country && protect_class

      country_rules = RULES_BY_CLASS[country]
      return DEFAULT_RULE unless country_rules

      country_rules[protect_class] || DEFAULT_RULE
    end

    def detect_czech_category(protection_title, name = nil)
      # Order matters: check more specific patterns first (NPR before PR, NPP before PP)
      [:npr, :npp, :np, :pr, :pp, :chko].each do |category|
        patterns = CZECH_CATEGORIES[category][:patterns]
        if protection_title.present? && patterns.any? { |pattern| protection_title.match?(pattern) }
          return category
        end
      end

      # Fallback: check name prefix (e.g., "NPR Xyz", "PP Abc")
      if name.present?
        return :npr if name.match?(/\ANPR\s/i)
        return :npp if name.match?(/\ANPP\s/i)
        return :pr if name.match?(/\APR\s/i)
        return :pp if name.match?(/\APP\s/i)
      end

      nil
    end

    def check_location(lat, lng)
      country = detect_country(lat, lng)

      # Return unsupported for locations outside Czechia
      if country != "CZ"
        return {
          lat: lat,
          lng: lng,
          country: country,
          areas: [],
          military_area: nil,
          verdict: OUTSIDE_CZECHIA[:verdict],
          explanation: OUTSIDE_CZECHIA[:explanation]
        }
      end

      # Check military areas first (highest restriction)
      military_area = MilitaryArea.military_area_for_point(lat, lng)
      if military_area
        return {
          lat: lat,
          lng: lng,
          country: country,
          areas: [],
          military_area: {
            name: military_area.name,
            coords: extract_military_coords(military_area.id)
          },
          verdict: IN_MILITARY_AREA[:verdict],
          explanation: IN_MILITARY_AREA[:explanation]
        }
      end

      areas = ProtectedArea.containing_point(lat, lng).to_a

      if areas.empty?
        return {
          lat: lat,
          lng: lng,
          country: country,
          areas: [],
          military_area: nil,
          verdict: OUTSIDE_PROTECTED_AREA[:verdict],
          explanation: OUTSIDE_PROTECTED_AREA[:explanation]
        }
      end

      verdicts = areas.map { |area| verdict_for_area(area) }
      most_restrictive = most_restrictive_verdict(verdicts)

      primary_area = areas.find do |area|
        verdict_for_area(area)[:verdict] == most_restrictive[:verdict]
      end

      {
        lat: lat,
        lng: lng,
        country: primary_area&.country || "CZ",
        areas: areas.map { |a| serialize_area(a) },
        military_area: nil,
        verdict: most_restrictive[:verdict],
        explanation: most_restrictive[:explanation]
      }
    end

    private

    def most_restrictive_verdict(verdicts)
      priority = [ VERDICTS[:forbidden], VERDICTS[:gray], VERDICTS[:allowed] ]
      verdicts.min_by { |v| priority.index(v[:verdict]) || 999 }
    end

    def serialize_area(area)
      category = detect_czech_category(area.protection_title, area.name)
      {
        name: area.name,
        protect_class: area.protect_class,
        protection_title: area.protection_title,
        czech_category: category&.to_s&.upcase,
        type: "protected_area",
        coords: extract_coords(area.geometry)
      }
    end

    def extract_coords(geometry)
      return [] unless geometry

      case geometry.geometry_type.to_s
      when "MultiPolygon"
        # Return array of polygons, each with simplified coords
        geometry.map { |polygon| simplify_coords(polygon_coords(polygon)) }
      when "Polygon"
        # Return single polygon wrapped in array for consistent format
        [simplify_coords(polygon_coords(geometry))]
      else
        []
      end
    end

    def polygon_coords(polygon)
      polygon.exterior_ring&.points&.map { |p| [p.y, p.x] } || []
    end

    def simplify_coords(coords)
      return coords if coords.length <= 200

      step = (coords.length / 100.0).ceil
      coords.each_with_index.select { |_, i| i % step == 0 }.map(&:first)
    end

    def extract_military_coords(military_area_id)
      result = ActiveRecord::Base.connection.exec_query(
        "SELECT ST_AsGeoJSON(geometry::geometry) as geojson FROM military_areas WHERE id = $1",
        "SQL",
        [military_area_id]
      )

      return [] if result.empty? || result[0]["geojson"].nil?

      geojson = JSON.parse(result[0]["geojson"])
      coords_data = geojson["coordinates"]

      case geojson["type"]
      when "MultiPolygon"
        coords_data.map { |polygon| simplify_coords(polygon.first.map { |c| [c[1], c[0]] }) }
      when "Polygon"
        [simplify_coords(coords_data.first.map { |c| [c[1], c[0]] })]
      else
        []
      end
    rescue ActiveRecord::StatementInvalid, JSON::ParserError => e
      Rails.logger.error("Error extracting military coords: #{e.message}")
      []
    end

    def detect_country(lat, lng)
      CountryBoundary.country_for_point(lat, lng) || "Unknown"
    end
  end
end
