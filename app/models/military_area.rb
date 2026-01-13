class MilitaryArea < ApplicationRecord
  validates :name, presence: true

  scope :containing_point, ->(lat, lng) {
    where(
      "ST_Covers(geometry, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography)",
      lng, lat
    )
  }

  def self.point_in_military_area?(lat, lng)
    containing_point(lat, lng).exists?
  end

  def self.military_area_for_point(lat, lng)
    containing_point(lat, lng).first
  end
end
