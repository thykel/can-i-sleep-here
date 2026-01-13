class CountryBoundary < ApplicationRecord
  validates :code, presence: true, uniqueness: true

  scope :containing_point, ->(lat, lng) {
    where(
      "ST_Covers(geometry, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography)",
      lng, lat
    )
  }

  def self.country_for_point(lat, lng)
    containing_point(lat, lng).pick(:code)
  end
end
