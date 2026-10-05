class EvidenceFilesController < ApplicationController
  before_action :set_case

  rescue_from EvidenceFile::IntegrityError do |error|
    redirect_to @case, alert: error.message, status: :see_other
  end

  def show
    @evidence_file = @case.evidence_files.find(params.expect(:id))
  end

  def create
    uploads = Array(params.dig(:evidence, :files)).compact_blank
    if uploads.empty?
      redirect_to @case, alert: "Choose at least one file to upload.", status: :see_other
      return
    end

    stored = uploads.map do |upload|
      EvidenceFile.ingest!(kase: @case, io: upload, filename: upload.original_filename,
        content_type: upload.content_type)
    end
    redirect_to @case, notice: "Uploaded #{helpers.pluralize(stored.size, "file")}.", status: :see_other
  end

  private
    def set_case
      @case = Case.find(params.expect(:case_id))
    end
end
