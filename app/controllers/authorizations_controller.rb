class AuthorizationsController < ApplicationController

=begin
  rescue_from Rack::OAuth2::Server::Authorize::BadRequest do |e|
    @error = e
    render :nothing => true, :status => e.status
  end

  def new
    @sender_handle = params[:sender_handle]
    @recepient_handle = params[:recepient_handle]
    @time = Time.now.to_i
    @rand = SecureToken.generate
    respond *authorize_endpoint.call(request.env)
  end

  def create
    respond *authorize_endpoint(:allow_approval).call(request.env)
  end

  def token
    @json = {}
    token_endpoint.call(request.env)
    pp response.code
  end
    
  def setup_response(response, access_token, with_refresh_token = false)
    response.access_token = access_token.token
    response.refresh_token = access_token.create_refresh_token(
      :contact => access_token.contact,
      :client => access_token.client
    ).token if with_refresh_token
    response.token_type = access_token.token_type
    response.expires_in = access_token.expires_in
  end

  def token_endpoint
    Rack::OAuth2::Server::Token.new do |req, res|
      username = params[:sender_handle].split("@")[0]
      contact = Contact.joins(:user).joins(:person).where(:users => {:username => username}, :people => {:diaspora_handle => params[:recepient_handle]}).first
      client = contact ? contact.client : nil 
      req.invalid_grant! unless client

      verify_signature(client, params[:client_secret]) || req.invalid_grant!
      case req.grant_type
      when :authorization_code
        code = AuthorizationCode.valid.find_by_token(req.code)
        req.invalid_grant! if code.blank? || code.redirect_uri != req.redirect_uri
        setup_response res, code.access_token, :with_refresh_token
      when :password
        # NOTE: password is not hashed in this sample app. Don't do the same on your app.
        account = Account.find_by_username_and_password(req.username, req.password) || req.invalid_grant!
        setup_response res, account.access_tokens.create(:client => client), :with_refresh_token
      when :client_credentials
        # NOTE: client is already authenticated here.
        setup_response res, client.access_tokens.create, :with_refresh_token
      when :refresh_token
        refresh_token = client.refresh_tokens.valid.find_by_token(req.refresh_token)
        setup_response res, refresh_token.access_tokens.create
      else
        # NOTE: extended assertion grant_types are not supported yet.
        req.unsupported_grant_type!
      end
    end
  end

  def verify_signature(client, signature)
    challenge = [ params[:sender_handle], params[:recepient_handle], params[:time]].join(";")
    client.contact.person.public_key.verify(OpenSSL::Digest::SHA256.new, Base64.decode64(signature), challenge) && params[:time] > (Time.now - 5.minutes).to_i
  end


  private

  def respond(status, header, response)
    ["WWW-Authenticate"].each do |key|
      headers[key] = header[key] if header[key].present?
    end
    if response.redirect?
      redirect_to header['Location']
    else
      @challenge = "#{@sender_handle};#{@recepient_handle};#{@time.to_i};#{@rand}"
      @client.update_attributes(:challenge => @challenge) if @client
      render :new, :layout => false
    end
  end

  def authorize_endpoint(allow_approval = false)
    Rack::OAuth2::Server::Authorize.new do |req, res|
      username = params[:sender_handle].split("@")[0]
      contact = Contact.joins(:user).joins(:person).where(:users => {:username => username}, :people => {:diaspora_handle => params[:recepient_handle]}).first
      @client = contact ? contact.client : nil

      if @client && allow_approval
        res.redirect_uri = @redirect_uri = req.verify_redirect_uri!(@client.redirect_uri)

        if verify_signature(@client, params[:code])
          case req.response_type
          when :code
            #authorization_code = current_account.authorization_codes.create(:client_id => @client, :redirect_uri => res.redirect_uri)
            #res.code = authorization_code.token
          when :token
            access_token = @client.access_tokens.create(:client_id => @client)
            res.access_token = access_token.token
            res.token_type = :bearer
            res.expires_in = access_token.expires_in
          end
          res.approve!
        else
          req.access_denied!
        end
      else
        @response_type = req.response_type
      end
    end
  end

=end
end
