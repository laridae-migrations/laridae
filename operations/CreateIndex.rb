# frozen_string_literal: true

require_relative './GeneralOperation'

class CreateIndex < GeneralOperation
  def initialize(db_conn, script)
    super
    @new_column = "laridae_new_#{@column}"
    @index = "laridae_index_#{@table.name}_#{@column}"
    @method = script['info']['method']
  end

  def rollback
    super
    @database.drop_index(@table.schema, @index)
    @table.drop_column(@new_column)
  end

  def expand
    before_view = { @new_column => nil }
    after_view = { @column => nil, @new_column => @column }

    @table.create_new_version_of_column(@column)
    super(before_view, after_view)

    @database.create_index(@table, @index, @method, @new_column)
    @database.create_trigger(@table, @column, @new_column, @column, @column)
    @table.backfill(@new_column, @column)
  end

  def contract
    super
    @table.drop_column(@column)
    @table.rename_column(@new_column, @column)
    new_index_name = "index_#{@table.name}_#{@column}"
    @database.rename_index(@table.schema, @index, new_index_name)
  end
end
