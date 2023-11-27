# frozen_string_literal: true

require_relative './GeneralOperation'

class AddNotNull < GeneralOperation
  def initialize(db_conn, script)
    super
    @new_column = "laridae_new_#{@column}"
    @constraint_name = "laridae_constraint_#{@column}_not_null"
    @functions = script['functions']
  end

  def rollback
    super
    @table.drop_column(@new_column)
    @table.remove_constraint(@constraint_name)
  end

  def expand
    constraint = "CHECK (#{@new_column} IS NOT NULL) NOT VALID"

    before_view = { @new_column => nil }
    after_view = { @column => nil, @new_column => @column }

    create_before_view(before_view)

    @table.create_new_version_of_column(@column)
    create_after_view(after_view)

    @table.add_constraint(@constraint_name, constraint)

    @database.create_trigger(@table, @column, @new_column, @functions['up'], @functions['down'])
    @table.backfill(@new_column, @functions['up'])
    @table.validate_constraint(@constraint_name)
  end

  def contract
    super
    @table.drop_column(@column)
    @table.rename_column(@new_column, @column)
    new_constraint_name = "constraint_#{@column}_not_null"
    @table.rename_constraint(@constraint_name, new_constraint_name)
  end
end
