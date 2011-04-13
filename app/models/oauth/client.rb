class Client < ActiveRecord::Base
  require File.join(Rails.root, 'lib/oauth/secure_token')

  has_many :access_tokens
  has_many :refresh_tokens
  belongs_to :contact

  before_validation :setup, :on => :create
  validates :contact, :presence => true
  validates :identifier, :secret, :presence => true, :uniqueness => true

  private

  def setup
    self.identifier = SecureToken.generate(16)
    self.secret = SecureToken.generate
  end
end
