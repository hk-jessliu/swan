class Registration < ApplicationRecord
  before_save :defaults

  validates :otp,
    presence: true 
  validates :swan_backend,
    presence: true 
  validates :ike_daemon,
    presence: true,
    inclusion: { in: %w(strongswan libreswan),
                 message: "%{value} must be any of: strongswan (default), libreswan" }

  def defaults
    self.swan_backend = Rails.configuration.swan['default_swan_backend'] if self.swan_backend.nil?
    self.ike_daemon = 'strongswan' if self.ike_daemon.blank?
  end
end
