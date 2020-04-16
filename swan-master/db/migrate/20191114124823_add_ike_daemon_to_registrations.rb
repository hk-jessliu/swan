class AddIkeDaemonToRegistrations < ActiveRecord::Migration[5.2]
  def change
    add_column :registrations, :ike_daemon, :string
  end
end
