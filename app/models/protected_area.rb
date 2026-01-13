class ProtectedArea < ApplicationRecord
  validates :name, presence: true

  scope :containing_point, ->(lat, lng) {
    where(
      "ST_Covers(geometry, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography)",
      lng, lat
    )
  }

  def camping_verdict
    CampingRules.verdict_for_area(self)
  end
end
