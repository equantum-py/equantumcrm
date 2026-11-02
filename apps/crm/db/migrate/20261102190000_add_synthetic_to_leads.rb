# Marks test or demo records so dashboards never count them as real
# opportunities. Existing rows keep their data: the column starts false and
# nothing is backfilled; titles prefixed [DEMO] or [SINTÉTICO] are excluded by
# the Lead.real scope without being rewritten.
class AddSyntheticToLeads < ActiveRecord::Migration[8.1]
  def change
    add_column :leads, :synthetic, :boolean, null: false, default: false
    add_index :leads, :synthetic, where: "synthetic"
  end
end
