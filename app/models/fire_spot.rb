class FireSpot < ApplicationRecord
  scope :near_point, ->(lat, lng, radius_m) {
    where(
      "ST_DWithin(geometry, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ?)",
      lng, lat, radius_m
    )
  }
end
