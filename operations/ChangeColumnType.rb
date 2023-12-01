# frozen_string_literal: true

require_relative './GeneralOperation'

class ChangeColumnType < GeneralOperation
  def initialize(db_conn, script)
    super
    @new_column = "laridae_new_#{@column}"
    @functions = script['functions']
    @new_type = script['info']['type']
  end

  def rollback
    super
    @table.drop_column(@new_column)
  end

  def expand
    before_view = { @new_column => nil }
    after_view = { @column => nil, @new_column => @column }

    create_before_view(before_view)

    @table.add_column(@new_column, @new_type, nil, false)
    create_after_view(after_view)

    @database.create_trigger(@table, @column, @new_column, @functions['up'], @functions['down'])
    @table.backfill(@new_column, @functions['up'])
  end

  def contract
    super
    @table.drop_column(@column)
    @table.rename_column(@new_column, @column)
  end
end
