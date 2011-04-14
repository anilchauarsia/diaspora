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

    @params_hash = {:format => :json, :client_id => "abc", :grant_type => :client_credentials, :response_type => :token, 
      :sender_handle => @sender_handle, :recepient_handle => @recepient_handle, :redirect_uri => "http://localhost/"}
  end

  describe '#new' do
    before do
      pending
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
      @challenge = [@sender_handle,@recepient_handle,@time.to_i].join(";")
      #st = alice.contact_for(bob.person).client
      #st.challenge = @challenge
      #st.save!
      @code = "signature"
    end

    it 'fails with an invalid signature' do
      post :create, @params_hash.merge(:time => @time.to_i, :code => @code)
      response.body.should include("access_denied")
    end

    context "with valid signature" do
      it 'fails if the timestamp is more than 5 mins ago ' do
        @time = (@time-6.minutes)
        @challenge = [@sender_handle,@recepient_handle,@time.to_i].join(";")
        @code = Base64.encode64(
          bob.encryption_key.sign OpenSSL::Digest::SHA256.new, @challenge )

        post :create, @params_hash.merge(:time => @time.to_i, :code => @code)
        response.code.should == "401"
        response.body.strip!.should == <<JSON.strip!
        {
          "error":"invalid_request"
        }
JSON
      end

      it 'creates a token with a correct signature' do
        @code = Base64.encode64(
          bob.encryption_key.sign OpenSSL::Digest::SHA256.new, @challenge )

        post :create, @params_hash.merge(:time => @time.to_i, :code => @code)
        response.body.strip!.should == <<JSON.strip!
        {
         "access_token":"SlAV32hkKG",
         "token_type":"example",
         "expires_in":3600,
         "refresh_token":"8xLOxBtZp8",
         "example_parameter":"example_value"
        } 
JSON

      end
    end
  end
end
