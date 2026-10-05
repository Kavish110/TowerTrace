require "test_helper"

class CaseTest < ActiveSupport::TestCase
  test "valid with a name" do
    assert Case.new(name: "Test case").valid?
  end

  test "requires a name" do
    kase = Case.new(name: " ")
    assert_not kase.valid?
    assert_includes kase.errors[:name], "can't be blank"
  end

  test "limits name length" do
    kase = Case.new(name: "x" * 201)
    assert_not kase.valid?
    assert kase.errors.of_kind?(:name, :too_long)
  end

  test "database rejects a null name" do
    assert_raises(ActiveRecord::NotNullViolation) do
      Case.insert!({ name: nil, created_at: Time.current, updated_at: Time.current })
    end
  end

  test "recent_first orders by last update" do
    cases(:empty).touch
    assert_equal cases(:empty), Case.recent_first.first
  end
end
