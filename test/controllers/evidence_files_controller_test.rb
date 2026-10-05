require "test_helper"

class EvidenceFilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @kase = cases(:riverside)
  end

  def upload(*names)
    files = names.map { |name| fixture_file_upload(name) }
    post case_evidence_files_url(@kase), params: { evidence: { files: files } }
  end

  test "uploads a file and lists it with its hash" do
    assert_difference("@kase.evidence_files.count", 1) { upload("alpha_sample.csv") }
    assert_redirected_to case_url(@kase)

    follow_redirect!
    assert_select ".flash-notice", "Uploaded 1 file."
    assert_select "#evidence_files td a", "alpha_sample.csv"
    assert_select "#evidence_files td.mono", EvidenceFileTest::ALPHA_SAMPLE_SHA256
  end

  test "uploads several files at once" do
    assert_difference("@kase.evidence_files.count", 2) { upload("alpha_sample.csv", "notes.txt") }
    follow_redirect!
    assert_select ".flash-notice", "Uploaded 2 files."
  end

  test "ignores the blank entry Rails adds to multiple file fields" do
    post case_evidence_files_url(@kase),
      params: { evidence: { files: [ "", fixture_file_upload("notes.txt") ] } }
    assert_equal 1, @kase.evidence_files.count
  end

  test "rejects a submission with no files" do
    assert_no_difference("EvidenceFile.count") do
      post case_evidence_files_url(@kase), params: { evidence: { files: [ "" ] } }
    end
    assert_redirected_to case_url(@kase)
    follow_redirect!
    assert_select ".flash-alert", "Choose at least one file to upload."
  end

  test "shows file details and a download of the untouched original" do
    upload("alpha_sample.csv")
    evidence_file = @kase.evidence_files.last

    get case_evidence_file_url(@kase, evidence_file)
    assert_response :success
    assert_select "#sha256", EvidenceFileTest::ALPHA_SAMPLE_SHA256

    download_path = css_select("a:contains('Download original')").first["href"]
    assert_match %r{/rails/active_storage/blobs/proxy/}, download_path,
      "downloads must stream through Rails, not redirect to the internal bucket URL"
    get download_path
    assert_response :success
    assert_equal file_fixture("alpha_sample.csv").binread, response.body
    assert_match(/attachment/, response.headers["Content-Disposition"])
  end

  test "does not show evidence through another case" do
    upload("alpha_sample.csv")
    get case_evidence_file_url(cases(:empty), @kase.evidence_files.last)
    assert_response :not_found
  end

  test "deleting a case with evidence is refused" do
    upload("alpha_sample.csv")
    assert_no_difference("Case.count") { delete case_url(@kase) }
    assert_redirected_to case_url(@kase)
    follow_redirect!
    assert_select ".flash-alert", /Cannot delete record because dependent evidence files exist/
  end
end
