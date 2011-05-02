module Oauth2Token
  def self.included(klass)
    klass.class_eval do
      cattr_accessor :default_lifetime
      self.default_lifetime = 1.minute

      belongs_to :contact
      belongs_to :client

      before_validation :setup, :on => :create
      validates_presence_of :token
      validates_uniqueness_of :token, :scope => :client_id
      
      validate do
        if !client_id && !contact_id
          errors[:base] << "Oauth2Token requires either a client id or a contact id"
          false
        else
          true
        end
      end

      scope :valid, lambda {
        where("expires_at > #{ Time.now.utc.to_i}")
      }
    end
  end

  def expires_in
    (expires_at - Time.now.utc).to_i
  end

  def expired!
    self.expires_at = Time.now.utc
    self.save!
  end

  def expired?
    expires_at.to_i < Time.now.to_i
  end

  private

  def setup
    if client_id
      self.token = SecureToken.generate
    end
    self.expires_at ||= self.default_lifetime.from_now
  end
end
