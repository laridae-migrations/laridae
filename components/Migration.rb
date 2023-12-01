# frozen_string_literal: true

require_relative './DatabaseConnection'
require_relative './MigrationRecord'
require_relative './Validator'
require_relative './Table'

require_relative '../operations/AddColumn'
require_relative '../operations/AddUniqueConstraint'
require_relative '../operations/AddForeignKeyConstraint'
require_relative '../operations/AddNotNull'
require_relative '../operations/RenameColumn'
require_relative '../operations/AddCheckConstraint'
require_relative '../operations/DropColumn'
require_relative '../operations/CreateIndex'
require_relative '../operations/ChangeColumnType'

require 'json'

# This is the main migration driver
class Migration
  HANDLERS_BY_OPERATION = {
    'add_not_null_constraint' => AddNotNull,
    'rename_column' => RenameColumn,
    'add_check_constraint' => AddCheckConstraint,
    'drop_column' => DropColumn,
    'create_index' => CreateIndex,
    'add_column' => AddColumn,
    'add_unique_constraint' => AddUniqueConstraint,
    'add_foreign_key_constraint' => AddForeignKeyConstraint,
    "change_column_type" => ChangeColumnType
  }.freeze

  def initialize(db_conn, migration_record, script_hash = {})
    @db_conn = db_conn
    @record = migration_record
    @script = script_hash
  end

  def operation_handler_for_script(script_hash)
    operation_name = script_hash['operation']
    HANDLERS_BY_OPERATION[operation_name].new(@db_conn, script_hash)
  end

  def cleanup(script = @script)
    operation_handler_for_script(script).rollback
    Database.new(@db_conn, script).teardown_created_schemas
  end

  def cleanup_if_last_aborted
    return unless @record.last_migration && @record.last_migration['status'] == 'aborted'

    cleanup(JSON.parse(@record.last_migration['script']))
    puts 'Cleaned up last aborted migration.'
  end

  def expand
    if @record.ok_to_expand?(@script)
      @record.mark_expand_starts(@script)
      cleanup_if_last_aborted
      operation_handler_for_script(@script).expand
      @record.mark_expand_finishes(@script)
      puts 'Expand completed.'
    else
      raise 'Either there is another active migration running, or this was a duplicated Migration. '
    end
  end

  def contract
    if @record.ok_to_contract?
      @record.mark_contract_starts
      last_migration_script = JSON.parse(@record.last_migration['script'])
      operation_handler_for_script(last_migration_script).contract
      @record.mark_contract_finishes
      puts 'Contract completed. '
    else
      raise 'There is no open migration. '
    end
  end

  def rollback
    if @record.ok_to_rollback?
      @record.mark_rollback_starts
      last_migration_script = JSON.parse(@record.last_migration['script'])
      operation_handler_for_script(last_migration_script).rollback
      @record.mark_rollback_finishes
      puts 'Rollback completed. '
    else
      raise 'There is no open migration. '
    end
  end

  def restore
    raise 'There is no migration to restore' if @record.last_migration.nil?

    if @record.ok_to_restore?
      cleanup(JSON.parse(@record.last_migration['script']))
      puts 'Cleaned up last aborted migration'
    else
      raise 'Restore only runs for aborted migrations. If previous migration is in Expanded state, use Rollback instead'
    end
  end
end
