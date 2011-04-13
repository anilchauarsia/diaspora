require 'spec_helper'

describe AuthorizationsController do
  render_views
  
  describe '#new' do
    before do
      @client = Client.create!(:identifier => "abc", :contact => alice.contact_for(bob.person), :redirect_uri => "")
      
      @sender_handle = "sender"#alice.contact_for(bob.person).diaspora_handle
      @recepient_handle = "receiver"#bob.contact_for(alice.person).diaspora_handle
      @time = Time.now
      @rand = "djfa98fha89fh"
      Time.stub!(:now).and_return(@time)
      
      @new_hash = { :client_id => "abc", :response_type => :token}
    end
    
    it 'succeeds' do
      get :new, @new_hash
      response.should be_success
    end
    
    it 'generates a string that is to be signed' do
      get :new, @new_hash.merge(:sender_handle => @sender_handle, :receiver_handle => @recepient_handle)
      response.body.should include("#{@sender_handle};#{@receipient_handle};#{@time.to_i}")
    end

    it 'calls secure random' do
      ActiveSupport::SecureRandom.should_receive(:base64).and_return(@rand)
      get :new, @new_hash.merge(:sender_handle => @sender_handle, :receiver_handle => @recepient_handle)
      response.body.should include(@rand)
    end

    it 'stores the string in the client' do
      @sender = alice.contact_for(bob.person)
      @sender_handle = @sender.person.diaspora_handle
      @recepient_handle = bob.contact_for(alice.person).person.diaspora_handle
      
      lambda{
        get :new, @new_hash.merge(:sender_handle => @sender_handle, :receiver_handle => @recepient_handle)
      }.should change{
        @sender.server_token.challenge
      }.from(nil).to(response.body)

    end

  end

  describe '#create' do

  end

end
