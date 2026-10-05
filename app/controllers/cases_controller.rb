class CasesController < ApplicationController
  before_action :set_case, only: %i[show edit update destroy]

  def index
    @cases = Case.recent_first
  end

  def show
  end

  def new
    @case = Case.new
  end

  def edit
  end

  def create
    @case = Case.new(case_params)

    if @case.save
      redirect_to @case, notice: "Case created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @case.update(case_params)
      redirect_to @case, notice: "Case updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @case.destroy
      redirect_to cases_path, notice: "Case deleted.", status: :see_other
    else
      redirect_to @case, alert: @case.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def set_case
      @case = Case.find(params.expect(:id))
    end

    def case_params
      params.expect(case: [ :name, :description ])
    end
end
