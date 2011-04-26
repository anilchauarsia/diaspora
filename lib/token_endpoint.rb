class TokenEndpoint

  def call(env)
    authenticator.call(env)
  end

  private

  def authenticator
    Rack::OAuth2::Server::Token.new do |req, res|
      split = req.client_id.split(";")
      sender_handle = split[0]
      username = sender_handle.split('@')[0]
      recepient_handle = split[1]
      contact = Contact.joins(:user).joins(:person).where(:users => {:username => username}, :people => {:diaspora_handle => recepient_handle}).first
      client = contact ? contact.client : nil 
      error(req, :invalid_client!) unless client

      split = Base64.decode64(req.client_secret).split(';')
      time = split[0]
      nonce = split[1]
      signature = split[2]
      challenge = [sender_handle, recepient_handle, time, nonce].join(";")

      (valid_time?(time) && valid_nonce?(client, nonce) && verify_signature(client, challenge, signature)) || error(req, :invalid_client!)

      case req.grant_type
      when :authorization_code
        code = AuthorizationCode.valid.find_by_token(req.code)
        req.invalid_grant! if code.blank? || code.redirect_uri != req.redirect_uri
        res.access_token = code.access_token.to_bearer_token(:with_refresh_token)
      when :password
        # NOTE: password is not hashed in this sample app. Don't do the same on your app.
        account = Account.find_by_username_and_password(req.username, req.password) || req.invalid_grant!
        res.access_token = account.access_tokens.create(:client => client).to_bearer_token(:with_refresh_token)
      when :client_credentials
        # NOTE: client is already authenticated here.
        res.access_token = client.access_tokens.create(:nonce => nonce).to_bearer_token(:with_refresh_token)
      when :refresh_token
        refresh_token = client.refresh_tokens.valid.find_by_token(req.refresh_token)
        req.invalid_grant! unless refresh_token
        res.access_token = refresh_token.access_tokens.create.to_bearer_token
      else
        # NOTE: extended assertion grant_types are not supported yet.
        req.unsupported_grant_type!
      end
    end
  end

  def verify_signature(client, challenge, signature)
    client.contact.person.public_key.verify(OpenSSL::Digest::SHA256.new, Base64.decode64(signature), challenge)
  end

  def valid_time?(time)
    time.to_i > (Time.now - 5.minutes).to_i
  end

  def valid_nonce?(client, nonce)
    client.access_tokens.where(:nonce => nonce).first.nil? 
  end

  def error(req, error)
    req.env["warden"].custom_failure!
    req.send(error)
  end


end
