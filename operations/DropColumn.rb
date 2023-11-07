# frozen_string_literal: true

require_relative '../components/Table'
require_relative '../components/Database'
require_relative './GeneralOperation'

class DropColumn < GeneralOperation
  # initialize: super
  # rollback: super

  def expand
    before_view = {}
    after_view = { @column => nil }
    super(before_view, after_view)
  end

  def contract
    super
    @table.drop_column(@column)
  end
end
