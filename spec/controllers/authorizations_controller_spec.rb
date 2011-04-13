require 'spec_helper'

describe AuthorizationsController do
  render_views

  before do
    @client = Client.create!(:identifier => "abc", :contact => alice.contact_for(bob.person), :redirect_uri => "")
    alice.contact_for(bob.person).update_attributes(:server_token => @client)

    @sender_handle = alice.person.diaspora_handle
    @recepient_handle = bob.person.diaspora_handle
    @time = Time.now
    @rand = "djfa98fha89fh"
    Time.stub!(:now).and_return(@time)

    @params_hash = { :response_type => :token} 
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
      get :new, @new_hash.merge(:sender_handle => @sender_handle, :recepient_handle => @recepient_handle)
      response.body.should match(/#{@sender_handle};#{@recepient_handle};#{@time.to_i};.+/)
    end

    it 'calls secure random' do
      ActiveSupport::SecureRandom.should_receive(:base64).and_return(@rand)
      get :new, @new_hash.merge(:sender_handle => @sender_handle, :recepient_handle => @recepient_handle)
      response.body.should include(@rand)
    end

    it 'stores the string in the client' do
      get :new, @new_hash.merge(:sender_handle => @sender_handle, :recepient_handle => @recepient_handle)
      alice.contact_for(bob.person).server_token.challenge.should == response.body.strip!
    end

  end

  describe '#create' do
    before do
      @challenge = "#{@sender_handle};#{@recepient_handle};#{@time.to_i};#{@rand}"
    end

    it 'succeeds' do
      post :create, :challenge => @challenge
      response.should be_success
    end
  end

end
