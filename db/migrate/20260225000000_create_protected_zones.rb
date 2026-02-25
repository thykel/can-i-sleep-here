class CreateProtectedZones < ActiveRecord::Migration[8.1]
  def change
    create_table :protected_zones do |t|
      t.string :kat, null: false      # CHKO or NP
      t.string :nazev, null: false    # Area name (e.g. "Blaník")
      t.string :zona, null: false     # I, II, III, IV (CHKO) or A, B, C, D (NP)
      t.integer :objectid             # Source OBJECTID from GeoJSON
      t.st_geography :geometry

      t.timestamps
    end

    add_index :protected_zones, :geometry, using: :gist
    add_index :protected_zones, [ :kat, :nazev ]
  end
end
