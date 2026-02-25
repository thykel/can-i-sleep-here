class ProtectedZone < ApplicationRecord
  scope :containing_point, ->(lat, lng) {
    where(
      "ST_Covers(geometry, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography)",
      lng, lat
    )
  }

  def self.zone_for_point(lat, lng, kat: nil)
    scope = containing_point(lat, lng)
    scope = scope.where(kat: kat) if kat
    scope.first
  end
end
