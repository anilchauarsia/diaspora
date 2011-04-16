#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class Request
  include ROXML
  include Diaspora::Webhooks
  include ActiveModel::Validations

  attr_accessor :sender, :recipient, :aspect

  xml_accessor :sender_handle
  xml_accessor :recipient_handle

  validates_presence_of :sender, :recipient
  validate :not_already_connected
  validate :not_friending_yourself

  def self.diaspora_initialize(opts = {})
    req = self.new
    req.sender = opts[:from]
    req.recipient = opts[:to]
    req.aspect = opts[:into]
    req
  end

  def reverse_for accepting_user
    Request.diaspora_initialize(
      :from => accepting_user.person,
      :to => self.sender
    )
  end

  def diaspora_handle
    sender_handle
  end

  def sender_handle
    sender.diaspora_handle
  end
  def sender_handle= sender_handle
    self.sender = Person.where(:diaspora_handle => sender_handle).first
  end

  def recipient_handle
    recipient.diaspora_handle
  end
  def recipient_handle= recipient_handle
    self.recipient = Person.where(:diaspora_handle => recipient_handle).first
  end

  def notification_type(user, person)
    Notifications::StartedSharing
  end

  def subscribers(user)
    [self.recipient]
  end

  def receive(user, person)
    Rails.logger.info("event=receive payload_type=request sender=#{self.sender} to=#{self.recipient}")

    contact = user.contacts.find_or_initialize_by_person_id(self.sender.id)

    contact.sharing = true
    contact.save

    receive_tokens(contact)

    self
  end

  def receive_tokens(contact)
    challenge = [self.sender_handle, self.recipient_handle, Time.now.to_i].join(';')
    sig = self.recipient.owner.encryption_key.sign(OpenSSL::Digest::SHA256.new, challenge)

    client = Rack::OAuth2::Client.new(
      :identifier => "#{sender.diaspora_handle};#{recipient.diaspora_handle}",
      :secret => sig,
      #:redirect_uri => YOUR_REDIRECT_URI, # only required for grant_type = :code
      :host => URI.parse(sender.url).host,
      :port => URI.parse(sender.url).port.to_s
    )

    save_tokens(client.access_token!, contact)
  end

  def save_tokens(response, contact)
    response = JSON.parse(response.to_json.to_s)
    refresh_token = RefreshToken.create!(:token => response['refresh_token'], :contact => contact)
    AccessToken.create!(:token => response['access_token'], :refresh_token => refresh_token, :contact => contact)
  end

  private

  def not_already_connected
    if sender && recipient && Contact.where(:user_id => self.recipient.owner_id, :person_id => self.sender.id).count > 0
      errors[:base] << 'You have already connected to this person'
    end
  end

  def not_friending_yourself
    if self.recipient == self.sender
      errors[:base] << 'You can not friend yourself'
    end
  end
end
