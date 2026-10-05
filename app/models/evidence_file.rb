require "digest"

# An uploaded source file. The original bytes are evidence: they are stored
# untouched, hashed with SHA256 at upload, and never replaced or modified.
class EvidenceFile < ApplicationRecord
  class IntegrityError < StandardError; end

  HASH_CHUNK_BYTES = 1.megabyte

  belongs_to :case

  # dependent: false keeps the stored original even if this record is removed.
  has_one_attached :original, dependent: false

  enum :status, { pending: "pending", importing: "importing", imported: "imported", failed: "failed" },
    default: "pending", validate: true

  attr_readonly :case_id, :original_filename, :sha256, :uploaded_at

  validates :original_filename, :uploaded_at, presence: true
  validates :sha256, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :original, presence: true, on: :create
  validate :original_not_replaced, on: :update

  scope :recent_first, -> { order(uploaded_at: :desc, id: :desc) }

  # Hashes the upload, stores it, then re-reads the stored copy to confirm
  # the bytes on disk/S3 hash to the same value.
  def self.ingest!(kase:, io:, filename:, content_type: nil)
    sha256 = sha256_of(io)
    evidence_file = create!(
      case: kase,
      original_filename: filename,
      sha256: sha256,
      uploaded_at: Time.current,
      original: { io: io, filename: filename, content_type: content_type }
    )

    evidence_file.verify_stored_copy!
    evidence_file
  end

  def self.sha256_of(io)
    digest = Digest::SHA256.new
    io.rewind
    while (chunk = io.read(HASH_CHUNK_BYTES))
      digest.update(chunk)
    end
    io.rewind
    digest.hexdigest
  end

  def stored_sha256
    digest = Digest::SHA256.new
    original.blob.download { |chunk| digest.update(chunk) }
    digest.hexdigest
  end

  def stored_copy_intact?
    stored_sha256 == sha256
  end

  # Marks the file failed and raises if the stored bytes no longer hash to
  # the SHA256 recorded at upload.
  def verify_stored_copy!
    return true if stored_copy_intact?

    update!(status: :failed)
    raise IntegrityError, "Stored copy of #{original_filename} does not match SHA256 #{sha256}"
  end

  private
    def original_not_replaced
      errors.add(:original, "cannot be replaced once uploaded") if attachment_changes.key?("original")
    end
end
