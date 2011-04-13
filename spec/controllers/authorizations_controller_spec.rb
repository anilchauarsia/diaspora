require 'spec_helper'

describe AuthorizationsController do
  render_views

  before do
    @client = Client.create!(:identifier => "abc", :contact => alice.contact_for(bob.person), :redirect_uri => "http://localhost/")
    alice.contact_for(bob.person).update_attributes(:client => @client)

    @sender_handle = alice.person.diaspora_handle
    @recepient_handle = bob.person.diaspora_handle
    @time = Time.now
    @rand = "djfa98fha89fh"
    Time.stub!(:now).and_return(@time)

    @params_hash = {:client_id => "abc", :response_type => :token, :sender_handle => @sender_handle, :recepient_handle => @recepient_handle, :redirect_uri => "http://localhost/"}
  end

  describe '#new' do
    before do
      @new_hash = @params_hash
    end
    
    it 'succeeds' do
      get :new, @new_hash.merge(:sender_handle => 'foo@foo.com', :recepient_handle => 'bar@bar.com')
      response.should be_success
    end
    
    it 'generates a string that is to be signed' do
      get :new, @new_hash
      response.body.should match(/#{@sender_handle};#{@recepient_handle};#{@time.to_i};.+/)
    end

    it 'calls secure random' do
      ActiveSupport::SecureRandom.should_receive(:base64).and_return(@rand)
      get :new, @new_hash
      response.body.should include(@rand)
    end

    it 'stores the string in the client' do
      get :new, @new_hash
      alice.contact_for(bob.person).client.challenge.should == response.body.strip!
    end
  end

  describe '#create' do
    before do
      @challenge = "#{@sender_handle};#{@recepient_handle};#{@time.to_i};#{@rand}"
      st = alice.contact_for(bob.person).client
      st.challenge = @challenge
      st.save!
      @code = "signature"
    end

    it 'fails with an invalid signature' do
      post :create, @params_hash.merge(:code => @code)
      response.body.should include("access_denied")
    end

    it 'creates a token with a correct signature' do
      @code = Base64.encode64(
        bob.encryption_key.sign OpenSSL::Digest::SHA256.new, @challenge )
      post :create, @params_hash.merge(:code => @code)
      response.body.should_not include("access_denied")
    end
  end
end
