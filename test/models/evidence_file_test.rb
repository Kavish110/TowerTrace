require "test_helper"

class EvidenceFileTest < ActiveSupport::TestCase
  # Reference value from `shasum -a 256 test/fixtures/files/alpha_sample.csv`.
  ALPHA_SAMPLE_SHA256 = "0f1bfb41ab1073b4631c8214bb98bf3e88f2173007607cf9fff76fc0138c8adf".freeze

  setup do
    @kase = cases(:riverside)
    @path = file_fixture("alpha_sample.csv")
  end

  def ingest(path = @path, kase: @kase)
    File.open(path, "rb") do |io|
      EvidenceFile.ingest!(kase: kase, io: io, filename: path.basename.to_s, content_type: "text/csv")
    end
  end

  test "ingest records the SHA256 of the uploaded bytes" do
    assert_equal ALPHA_SAMPLE_SHA256, ingest.sha256
  end

  test "ingest stores the original bytes unchanged" do
    evidence_file = ingest
    assert_equal File.binread(@path), evidence_file.original.download
    assert_equal ALPHA_SAMPLE_SHA256, evidence_file.stored_sha256
  end

  test "ingest records filename, upload time and pending status" do
    freeze_time do
      evidence_file = ingest
      assert_equal "alpha_sample.csv", evidence_file.original_filename
      assert_equal Time.current, evidence_file.uploaded_at
      assert evidence_file.pending?
      assert_nil evidence_file.detected_format
    end
  end

  test "sha256_of streams input larger than one chunk" do
    data = Random.new(1).bytes(EvidenceFile::HASH_CHUNK_BYTES * 2 + 17)
    io = StringIO.new(data)
    assert_equal Digest::SHA256.hexdigest(data), EvidenceFile.sha256_of(io)
    assert_equal 0, io.pos, "IO should be rewound for the upload that follows"
  end

  test "the same bytes uploaded twice keep separate records with the same hash" do
    first = ingest
    second = ingest
    assert_not_equal first.id, second.id
    assert_equal first.sha256, second.sha256
  end

  test "sha256, filename, upload time and case cannot be changed" do
    evidence_file = ingest
    assert_raises(ActiveRecord::ReadonlyAttributeError) { evidence_file.sha256 = "0" * 64 }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { evidence_file.original_filename = "other.csv" }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { evidence_file.uploaded_at = 1.day.ago }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { evidence_file.case_id = cases(:empty).id }
  end

  test "the original cannot be replaced" do
    evidence_file = ingest
    replaced = evidence_file.original.attach(io: StringIO.new("tampered"), filename: "alpha_sample.csv")

    assert_not replaced
    assert_includes evidence_file.errors[:original], "cannot be replaced once uploaded"
    assert_equal File.binread(@path), evidence_file.reload.original.download
  end

  test "verify_stored_copy! marks the file failed and raises on a hash mismatch" do
    evidence_file = ingest
    def evidence_file.stored_sha256 = "f" * 64

    assert_raises(EvidenceFile::IntegrityError) { evidence_file.verify_stored_copy! }
    assert evidence_file.reload.failed?
  end

  test "requires an attached original" do
    evidence_file = EvidenceFile.new(case: @kase, original_filename: "x.csv", sha256: ALPHA_SAMPLE_SHA256,
      uploaded_at: Time.current)
    assert_not evidence_file.valid?
    assert_includes evidence_file.errors[:original], "can't be blank"
  end

  test "rejects a malformed sha256" do
    evidence_file = EvidenceFile.new(sha256: "ABC")
    evidence_file.validate
    assert evidence_file.errors.of_kind?(:sha256, :invalid)
  end

  test "rejects an unknown status" do
    evidence_file = EvidenceFile.new(status: "lost")
    evidence_file.validate
    assert evidence_file.errors.of_kind?(:status, :inclusion)
  end

  test "database rejects an unknown status" do
    evidence_file = ingest
    assert_raises(ActiveRecord::StatementInvalid) { evidence_file.update_column(:status, "lost") }
  end

  test "database rejects a malformed sha256" do
    now = Time.current
    assert_raises(ActiveRecord::StatementInvalid) do
      EvidenceFile.insert!({ case_id: @kase.id, original_filename: "x.csv", sha256: "not-a-hash",
        uploaded_at: now, created_at: now, updated_at: now })
    end
  end

  test "a case with evidence cannot be deleted" do
    ingest
    assert_not @kase.destroy
    assert @kase.errors.of_kind?(:base, :"restrict_dependent_destroy.has_many")
    assert Case.exists?(@kase.id)
  end
end
