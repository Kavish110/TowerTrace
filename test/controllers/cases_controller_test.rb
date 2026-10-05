require "test_helper"

class CasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @case = cases(:riverside)
  end

  test "root lists cases" do
    get root_url
    assert_response :success
    assert_select "#cases td a", text: @case.name
  end

  test "shows the empty state" do
    Case.delete_all
    get cases_url
    assert_select "p.empty", "No cases yet."
  end

  test "new" do
    get new_case_url
    assert_response :success
  end

  test "creates a case" do
    assert_difference("Case.count", 1) do
      post cases_url, params: { case: { name: "New case", description: "Notes" } }
    end
    assert_redirected_to case_url(Case.order(:id).last)
    follow_redirect!
    assert_select "h1", "New case"
  end

  test "rejects an invalid case" do
    assert_no_difference("Case.count") do
      post cases_url, params: { case: { name: "" } }
    end
    assert_response :unprocessable_content
    assert_select ".errors li", "Name can't be blank"
  end

  test "rejects a request without case params" do
    post cases_url, params: { name: "x" }
    assert_response :bad_request
  end

  test "shows a case" do
    get case_url(@case)
    assert_response :success
    assert_select "h1", @case.name
  end

  test "returns 404 for an unknown case" do
    get case_url(id: 0)
    assert_response :not_found
  end

  test "edit" do
    get edit_case_url(@case)
    assert_response :success
  end

  test "updates a case" do
    patch case_url(@case), params: { case: { name: "Renamed" } }
    assert_redirected_to case_url(@case)
    assert_equal "Renamed", @case.reload.name
  end

  test "rejects an invalid update" do
    patch case_url(@case), params: { case: { name: "" } }
    assert_response :unprocessable_content
    assert_equal "Riverside burglary series", @case.reload.name
  end

  test "destroys a case" do
    assert_difference("Case.count", -1) do
      delete case_url(cases(:empty))
    end
    assert_redirected_to cases_url
  end
end
