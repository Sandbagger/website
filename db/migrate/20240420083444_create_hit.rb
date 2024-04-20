class CreateHit < ActiveRecord::Migration[7.1]
  def change
    create_table :hits do |t|
      t.string :unique_user_id
      t.string :user_agent
      t.string :page
      t.string :referer
      t.string :session_id
      t.string :path
      t.json :metadata

      t.timestamps
    end
  end
end
