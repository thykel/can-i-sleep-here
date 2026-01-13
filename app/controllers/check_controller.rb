class CheckController < ApplicationController
  def index
    lat = params[:lat]&.to_f
    lng = params[:lng]&.to_f

    if lat.nil? || lng.nil? || lat.zero? || lng.zero?
      render json: {
        error: "Missing or invalid coordinates",
        usage: "GET /check?lat=49.82&lng=13.80"
      }, status: :bad_request
      return
    end

    unless valid_coordinates?(lat, lng)
      render json: {
        error: "Coordinates out of range",
        details: "lat must be between -90 and 90, lng must be between -180 and 180"
      }, status: :bad_request
      return
    end

    result = CampingRules.check_location(lat, lng)

    render json: result
  end

  private

  def valid_coordinates?(lat, lng)
    lat.between?(-90, 90) && lng.between?(-180, 180)
  end
end
