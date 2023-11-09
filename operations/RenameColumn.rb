# frozen_string_literal: true

require_relative './GeneralOperation'

class RenameColumn < GeneralOperation
  def initialize(db_conn, script)
    super
    @new_name = script['info']['new_name']
  end

  # rollback: super

  def expand
    before_view = {}
    after_view = { @column => @new_name }
    super(before_view, after_view)
  end

  def contract
    super
    @table.rename_column(@column, @new_name)
  end
end
