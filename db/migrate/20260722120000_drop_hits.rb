# frozen_string_literal: true

class DropHits < ActiveRecord::Migration[8.0]
  def up
    drop_table :hits
  end

  def down
    create_table :hits do |t|
      t.string :unique_user_id
      t.string :user_agent
      t.string :referer
      t.string :session_id
      t.string :path
      t.json :metadata
      t.timestamps
    end
  end
end
