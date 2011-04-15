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
      :sender_handle => @sender_handle, :recepient_handle => @recepient_handle}
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

  describe '#token' do
    before do
      @challenge = [@sender_handle,@recepient_handle,@time.to_i].join(";")
      @code = "signature"
    end

    it 'fails with an invalid signature' do
      post :token, @params_hash.merge(:time => @time.to_i, :client_secret => @code)
      response.code.should == "401"
      response.body.strip!.should == '{"error":"invalid_request"}'
    end

    context "with valid signature" do
      context 'wrong time' do
        before do
          @time = (@time-6.minutes)
          @challenge = [@sender_handle,@recepient_handle,@time.to_i].join(";")
          @code = Base64.encode64(
            bob.encryption_key.sign OpenSSL::Digest::SHA256.new, @challenge )
        end

        it 'fails if the timestamp is more than 5 mins ago ' do
          post :token, @params_hash.merge(:time => @time.to_i, :client_secret => @code)
          response.code.should == "401"
          response.body.strip!.should == '{"error":"invalid_request"}'
        end

        it 'does not token a refresh token' do
          lambda{
            post :token, @params_hash.merge(:time => @time.to_i, :client_secret => @code)
          }.should_not change{
            RefreshToken.count
          }
        end

        it 'does not token an access token' do

          lambda{
            post :token, @params_hash.merge(:time => @time.to_i, :client_secret => @code)
          }.should_not change{
            AccessToken.count
          }
        end
      end

      context 'valid time' do
        before do
          @code = Base64.encode64(
            bob.encryption_key.sign OpenSSL::Digest::SHA256.new, @challenge )
          AccessToken.any_instance.stub(:token).and_return('xxx')
          RefreshToken.any_instance.stub(:token).and_return('zzz')
        end

        it 'responds with a token for a correct signature' do
          json = '{ "access_token":"xxx",
                   "token_type":"bearer",
                   "expires_in":900,
                   "refresh_token":"zzz"
                  }' 

          post :token, @params_hash.merge(:time => @time.to_i, :client_secret => @code)
          JSON.parse(response.body).should == JSON.parse(json)
        end

        it 'tokens a refresh token' do
          lambda{
            post :token, @params_hash.merge(:time => @time.to_i, :client_secret => @code)
          }.should change{
            RefreshToken.count
          }.by(1)
        end

        it 'tokens an access token' do
          lambda{
            post :token, @params_hash.merge(:time => @time.to_i, :client_secret => @code)
          }.should change{
            AccessToken.count
          }.by(1)
        end
      end
    end
  end
end
