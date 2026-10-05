# An investigation. Named after the domain term; note that `case` is a Ruby
# keyword, so local variables holding one are called `kase`.
class Case < ApplicationRecord
  has_many :evidence_files, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 200 }

  scope :recent_first, -> { order(updated_at: :desc) }
end
