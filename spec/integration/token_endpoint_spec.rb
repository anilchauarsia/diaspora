require 'spec_helper'

describe 'Token Endpoint' do

  before do
    @client = Client.create!(:identifier => "abc", :contact => alice.contact_for(bob.person), :redirect_uri => "http://localhost/")
    alice.contact_for(bob.person).update_attributes(:client => @client)

    @sender_handle = alice.person.diaspora_handle
    @recepient_handle = bob.person.diaspora_handle
    @time = Time.now
    @rand = "djfa98fha89fh"
    Time.stub!(:now).and_return(@time)

    client_id = [@sender_handle,@recepient_handle].join(";")
    @params_hash = {:format => :json, :client_id => client_id, :grant_type => :client_credentials, :response_type => :token, 
      :sender_handle => @sender_handle, :recepient_handle => @recepient_handle}

    @challenge = "#{client_id};#{@time.to_i}"
    @code = Base64.encode64("#{@time.to_i};signature")
  end

  it 'fails with an invalid signature' do
    post 'oauth2/token', @params_hash.merge(:time => @time.to_i, :client_secret => @code)
    response.code.should == "401"
    JSON.parse(response.body)['error'].should == "invalid_client"
  end

  context "with valid signature" do
    context 'wrong time' do
      before do
        @time = (@time-6.minutes)
        @challenge = [@sender_handle,@recepient_handle,@time.to_i].join(";")
        @code = Base64.encode64( 
              [@time.to_i, bob.encryption_key.sign(OpenSSL::Digest::SHA256.new, @challenge)].join(';'))
      end

      it 'fails if the timestamp is more than 5 mins ago ' do
        post 'oauth2/token', @params_hash.merge(:time => @time.to_i, :client_secret => @code)
        response.code.should == "401"
        JSON.parse(response.body)['error'].should == "invalid_client"
      end

      it 'does not token a refresh token' do
        lambda{
          post 'oauth2/token', @params_hash.merge(:time => @time.to_i, :client_secret => @code)
        }.should_not change{
          RefreshToken.count
        }
      end

      it 'does not token an access token' do

        lambda{
          post 'oauth2/token', @params_hash.merge(:time => @time.to_i, :client_secret => @code)
        }.should_not change{
          AccessToken.count
        }
      end
    end

    context 'valid time' do
      before do
        @code = Base64.encode64( 
              [@time.to_i, bob.encryption_key.sign(OpenSSL::Digest::SHA256.new, @challenge)].join(';'))
        AccessToken.any_instance.stub(:token).and_return('xxx')
        RefreshToken.any_instance.stub(:token).and_return('zzz')
      end

      it 'responds with a token for a correct signature' do
        json = '{ "access_token":"xxx",
                 "token_type":"bearer",
                 "expires_in":900,
                 "refresh_token":"zzz"
                }' 

        post 'oauth2/token', @params_hash.merge(:time => @time.to_i, :client_secret => @code)
        JSON.parse(response.body).should == JSON.parse(json)
      end

      it 'tokens a refresh token' do
        lambda{
          post 'oauth2/token', @params_hash.merge(:time => @time.to_i, :client_secret => @code)
        }.should change{
          RefreshToken.count
        }.by(1)
      end

      it 'tokens an access token' do
        lambda{
          post 'oauth2/token', @params_hash.merge(:time => @time.to_i, :client_secret => @code)
        }.should change{
          AccessToken.count
        }.by(1)
      end
    end
  end
end
