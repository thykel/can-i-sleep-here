require "test_helper"

class CampingRulesTest < ActiveSupport::TestCase
  # Tests for detect_czech_category method
  test "detect_czech_category identifies NPR from full Czech name" do
    assert_equal :npr, CampingRules.detect_czech_category("Národní přírodní rezervace")
    assert_equal :npr, CampingRules.detect_czech_category("národní přírodní rezervace Boubínský prales")
  end

  test "detect_czech_category identifies NPP from Czech name" do
    assert_equal :npp, CampingRules.detect_czech_category("Národní přírodní památka")
    assert_equal :npp, CampingRules.detect_czech_category("národní přírodní památka Pravčická brána")
  end

  test "detect_czech_category identifies NP from Czech name" do
    assert_equal :np, CampingRules.detect_czech_category("Národní park Šumava")
    assert_equal :np, CampingRules.detect_czech_category("národní park")
  end

  test "detect_czech_category identifies PR from Czech name" do
    assert_equal :pr, CampingRules.detect_czech_category("Přírodní rezervace")
    assert_equal :pr, CampingRules.detect_czech_category("přírodní rezervace Pod Húrou")
  end

  test "detect_czech_category identifies PP from Czech name" do
    assert_equal :pp, CampingRules.detect_czech_category("Přírodní památka")
    assert_equal :pp, CampingRules.detect_czech_category("přírodní památka Skalní hrad")
  end

  test "detect_czech_category identifies CHKO from Czech name" do
    assert_equal :chko, CampingRules.detect_czech_category("Chráněná krajinná oblast")
    assert_equal :chko, CampingRules.detect_czech_category("chráněná krajinná oblast Brdy")
  end

  test "detect_czech_category prioritizes NPR over PR" do
    # NPR contains "přírodní rezervace" so we need to check the more specific one first
    assert_equal :npr, CampingRules.detect_czech_category("Národní přírodní rezervace Boubín")
  end

  test "detect_czech_category prioritizes NPP over PP" do
    assert_equal :npp, CampingRules.detect_czech_category("Národní přírodní památka")
  end

  test "detect_czech_category returns nil for unknown category" do
    assert_nil CampingRules.detect_czech_category("Unknown category")
    assert_nil CampingRules.detect_czech_category(nil)
  end

  # Tests for verdict_by_class method (IUCN class fallback)
  test "verdict_by_class returns forbidden for Czech strict nature reserve (1a)" do
    verdict = CampingRules.verdict_by_class("CZ", "1a")
    assert_equal "forbidden", verdict[:verdict]
  end

  test "verdict_by_class returns forbidden for Czech wilderness area (1b)" do
    verdict = CampingRules.verdict_by_class("CZ", "1b")
    assert_equal "forbidden", verdict[:verdict]
  end

  test "verdict_by_class returns forbidden for Czech national park (2)" do
    verdict = CampingRules.verdict_by_class("CZ", "2")
    assert_equal "forbidden", verdict[:verdict]
  end

  test "verdict_by_class returns forbidden for Czech class 3" do
    verdict = CampingRules.verdict_by_class("CZ", "3")
    assert_equal "forbidden", verdict[:verdict]
  end

  test "verdict_by_class returns forbidden for Czech nature reserve (4)" do
    verdict = CampingRules.verdict_by_class("CZ", "4")
    assert_equal "forbidden", verdict[:verdict]
  end

  test "verdict_by_class returns allowed for Czech CHKO (5)" do
    verdict = CampingRules.verdict_by_class("CZ", "5")
    assert_equal "allowed", verdict[:verdict]
  end

  test "verdict_by_class returns default for unknown protect_class" do
    verdict = CampingRules.verdict_by_class("CZ", "99")
    assert_equal "gray", verdict[:verdict]
    assert_includes verdict[:explanation], "No specific rules"
  end

  test "verdict_by_class returns default for unknown country" do
    verdict = CampingRules.verdict_by_class("XX", "5")
    assert_equal "gray", verdict[:verdict]
  end

  test "verdict_by_class handles nil country" do
    verdict = CampingRules.verdict_by_class(nil, "5")
    assert_equal "gray", verdict[:verdict]
  end

  test "verdict_by_class handles nil protect_class" do
    verdict = CampingRules.verdict_by_class("CZ", nil)
    assert_equal "gray", verdict[:verdict]
  end

  # Tests for verdict_for_area with Czech categories
  test "verdict_for_area uses protection_title when available" do
    area = ProtectedArea.new(
      name: "Test NPR",
      protect_class: "3",  # Wrong IUCN class
      protection_title: "Národní přírodní rezervace",
      country: "CZ"
    )
    verdict = CampingRules.verdict_for_area(area)
    assert_equal "forbidden", verdict[:verdict]
    assert_includes verdict[:explanation], "NPR"
  end

  test "verdict_for_area falls back to protect_class when no Czech category" do
    area = ProtectedArea.new(
      name: "Test Area",
      protect_class: "4",  # Nature Reserve - stricter rules
      protection_title: nil,
      country: "CZ"
    )
    verdict = CampingRules.verdict_for_area(area)
    assert_equal "forbidden", verdict[:verdict]
  end

  # Tests for check_location method
  test "check_location returns allowed when outside protected areas" do
    result = CampingRules.check_location(50.08, 14.43) # Prague area
    assert_equal "allowed", result[:verdict]
    assert_empty result[:areas]
    assert_equal 50.08, result[:lat]
    assert_equal 14.43, result[:lng]
  end

  test "check_location detects Czech Republic from coordinates" do
    result = CampingRules.check_location(50.08, 14.43)
    assert_equal "CZ", result[:country]
  end

  test "check_location returns Unknown for coordinates outside Czech Republic" do
    result = CampingRules.check_location(52.52, 13.40) # Berlin
    assert_equal "Unknown", result[:country]
  end

  test "check_location returns unsupported verdict for coordinates outside Czechia" do
    result = CampingRules.check_location(52.52, 13.40) # Berlin
    assert_equal "unsupported", result[:verdict]
    assert_includes result[:explanation], "outside Czechia"
    assert_empty result[:areas]
  end

  test "check_location returns unsupported for Austria (south of Czechia)" do
    result = CampingRules.check_location(48.20, 16.37) # Vienna
    assert_equal "unsupported", result[:verdict]
  end

  test "check_location returns unsupported for Poland (north of Czechia)" do
    result = CampingRules.check_location(51.50, 17.03) # Wroclaw area
    assert_equal "unsupported", result[:verdict]
  end

  test "check_location finds protected area and returns verdict" do
    # Create a test CHKO area - bivouacking is allowed here (2008 precedent)
    ProtectedArea.create!(
      name: "Test CHKO",
      protect_class: "5",
      country: "CZ",
      geometry: create_polygon(brdy_polygon_coords)
    )

    result = CampingRules.check_location(49.70, 13.82)

    assert_equal "allowed", result[:verdict]
    assert_equal 1, result[:areas].length
    assert_equal "Test CHKO", result[:areas].first[:name]
    assert_equal "5", result[:areas].first[:protect_class]
  end

  test "check_location returns most restrictive verdict for overlapping areas" do
    # Create overlapping areas with different protection classes
    geometry = create_polygon(brdy_polygon_coords)

    ProtectedArea.create!(
      name: "Outer CHKO",
      protect_class: "5",
      country: "CZ",
      geometry: geometry
    )

    ProtectedArea.create!(
      name: "Inner NPR",
      protect_class: "1a",
      country: "CZ",
      geometry: geometry
    )

    result = CampingRules.check_location(49.70, 13.82)

    assert_equal "forbidden", result[:verdict]
    assert_equal 2, result[:areas].length
  end

  test "check_location serializes areas correctly" do
    ProtectedArea.create!(
      name: "Test Area",
      protect_class: "4",
      protection_title: "Přírodní rezervace",
      country: "CZ",
      geometry: create_polygon(brdy_polygon_coords)
    )

    result = CampingRules.check_location(49.70, 13.82)

    area = result[:areas].first
    assert_equal "Test Area", area[:name]
    assert_equal "4", area[:protect_class]
    assert_equal "Přírodní rezervace", area[:protection_title]
    assert_equal "PR", area[:czech_category]
    assert_equal "protected_area", area[:type]
  end

  test "check_location returns correct verdict for NPR area" do
    ProtectedArea.create!(
      name: "Boubínský prales",
      protect_class: "3",  # OSM often has wrong class for NPR
      protection_title: "Národní přírodní rezervace",
      country: "CZ",
      geometry: create_polygon(brdy_polygon_coords)
    )

    result = CampingRules.check_location(49.70, 13.82)

    assert_equal "forbidden", result[:verdict]
    assert_includes result[:explanation], "NPR"
    assert_equal "NPR", result[:areas].first[:czech_category]
  end

  test "check_location returns forbidden for PR area (stricter rules)" do
    ProtectedArea.create!(
      name: "Local Reserve",
      protect_class: "3",  # May be wrong in OSM
      protection_title: "Přírodní rezervace",
      country: "CZ",
      geometry: create_polygon(brdy_polygon_coords)
    )

    result = CampingRules.check_location(49.70, 13.82)

    assert_equal "forbidden", result[:verdict]
    assert_equal "PR", result[:areas].first[:czech_category]
  end
end
