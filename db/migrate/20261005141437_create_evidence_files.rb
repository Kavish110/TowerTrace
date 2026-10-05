class CreateEvidenceFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :evidence_files do |t|
      t.references :case, null: false, foreign_key: { on_delete: :restrict }
      t.string :original_filename, null: false
      t.string :sha256, null: false
      t.string :detected_format
      t.string :status, null: false, default: "pending"
      t.datetime :uploaded_at, null: false

      t.timestamps
    end

    add_index :evidence_files, [ :case_id, :sha256 ]
    add_check_constraint :evidence_files, "sha256 ~ '^[0-9a-f]{64}$'", name: "evidence_files_sha256_hex"
    add_check_constraint :evidence_files, "status IN ('pending', 'importing', 'imported', 'failed')",
      name: "evidence_files_status_known"
  end
end
