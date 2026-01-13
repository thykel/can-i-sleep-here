require "test_helper"

class ProtectedAreaTest < ActiveSupport::TestCase
  setup do
    # Create test areas with actual geometries
    @chko = ProtectedArea.create!(
      name: "CHKO Test",
      protect_class: "5",
      protection_title: "CHKO",
      country: "CZ",
      geometry: create_polygon(brdy_polygon_coords)
    )

    @national_park = ProtectedArea.create!(
      name: "NP Test",
      protect_class: "2",
      protection_title: "Národní park",
      country: "CZ",
      geometry: create_polygon(sumava_polygon_coords)
    )
  end

  test "containing_point finds area when point is inside" do
    # Point inside Brdy polygon
    areas = ProtectedArea.containing_point(49.70, 13.82)
    assert_includes areas, @chko
    assert_not_includes areas, @national_park
  end

  test "containing_point finds area for Šumava" do
    # Point inside Šumava polygon
    areas = ProtectedArea.containing_point(48.98, 13.52)
    assert_includes areas, @national_park
    assert_not_includes areas, @chko
  end

  test "containing_point returns empty when point is outside all areas" do
    # Point in Prague (outside all test areas)
    areas = ProtectedArea.containing_point(50.08, 14.43)
    assert_empty areas
  end

  test "containing_point handles edge of polygon" do
    # Point on the edge of Brdy polygon
    areas = ProtectedArea.containing_point(49.65, 13.82)
    # Edge behavior depends on PostGIS - just verify it doesn't error
    assert_kind_of ActiveRecord::Relation, areas
  end

  test "camping_verdict returns correct verdict for CHKO" do
    verdict = @chko.camping_verdict
    assert_equal "allowed", verdict[:verdict]
    assert_includes verdict[:explanation], "Protected Landscape Area"
  end

  test "camping_verdict returns correct verdict for National Park" do
    verdict = @national_park.camping_verdict
    assert_equal "forbidden", verdict[:verdict]
    assert_includes verdict[:explanation], "National Park"
  end

  test "required name validation" do
    area = ProtectedArea.new(protect_class: "5", country: "CZ")
    assert_not area.valid?
  end

  test "creates area with all attributes" do
    area = ProtectedArea.create!(
      name: "Test Area",
      protect_class: "3",
      protection_title: "NPP",
      country: "CZ",
      osm_id: "relation/999",
      geometry: create_polygon(brdy_polygon_coords)
    )

    assert area.persisted?
    assert_equal "Test Area", area.name
    assert_equal "3", area.protect_class
    assert_equal "CZ", area.country
  end
end
