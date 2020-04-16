class CreateRegistrations < ActiveRecord::Migration[5.2]
  def change
    create_table :registrations do |t|
      t.string :name
      t.string :otp
      t.string :access_token
      t.string :swan_backend
      t.string :salt_master

      t.timestamps
    end
  end
end
