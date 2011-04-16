#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'

describe Request do
  before do
    @aspect = alice.aspects.first
  end

  describe 'validations' do
    before do
      @request = Request.diaspora_initialize(:from => alice.person, :to => eve.person, :into => @aspect)
    end

    it 'is valid' do
      @request.sender.should == alice.person
      @request.recipient.should   == eve.person
      @request.aspect.should == @aspect
      @request.should be_valid
    end

    it 'is from a person' do
      @request.sender = nil
      @request.should_not be_valid
    end

    it 'is to a person' do
      @request.recipient = nil
      @request.should_not be_valid
    end

    it 'is not necessarily into an aspect' do
      @request.aspect = nil
      @request.should be_valid
    end

    it 'is not from an existing friend' do
      Contact.create(:user => eve, :person => alice.person, :aspects => [eve.aspects.first])
      @request.should_not be_valid
    end

    it 'is not to yourself' do
      @request = Request.diaspora_initialize(:from => alice.person, :to => alice.person, :into => @aspect)
      @request.should_not be_valid
    end
  end

  describe '#notification_type' do
    it 'returns request_accepted' do
      person = Factory :person

      request = Request.diaspora_initialize(:from => alice.person, :to => eve.person, :into => @aspect)
      alice.contacts.create(:person_id => person.id)

      request.notification_type(alice, person).should == Notifications::StartedSharing
    end
  end

  describe '#subscribers' do
    it 'returns an array with to field on a request' do
      request = Request.diaspora_initialize(:from => alice.person, :to => eve.person, :into => @aspect)
      request.subscribers(alice).should =~ [eve.person]
    end
  end

  describe '#receive' do
    before do
      Request.any_instance.stub(:receive_tokens)
    end

    it 'creates a contact' do
     request = Request.diaspora_initialize(:from => alice.person, :to => eve.person, :into => @aspect)

      lambda{
        request.receive(eve, alice.person)
      }.should change{
        eve.contacts(true).size
      }.by(1)
    end

    it 'sets mutual if a contact already exists' do
      alice.share_with(eve.person, alice.aspects.first)

      lambda {
        Request.diaspora_initialize(:from => eve.person, :to => alice.person,
                                    :into => eve.aspects.first).receive(alice, eve.person)
      }.should change {
        alice.contacts.find_by_person_id(eve.person.id).mutual?
      }.from(false).to(true)
    end

    it 'calls receive_tokens' do
     request = Request.diaspora_initialize(:from => alice.person, :to => eve.person, :into => @aspect)

     request.should_receive(:receive_tokens)
     request.receive(eve, alice.person)
    end
  end

  describe '#receive_tokens' do
    # Server A issues a share request to Server B
    # Server B requests an authorization token for Server A for GET access
    before do
      Request.any_instance.unstub(:receive_tokens)
      RestClient.unstub!(:post)
      client_url = "#{URI.parse(alice.person.url).host}:#{URI.parse(alice.person.url).port.to_s}"

      @json = {
         :access_token => "SlAV32hkKG",
         :token_type => "example",
         :refresh_token => "8xLOxBtZp8",
         :example_parameter => "example_value"
      }

      stub_request(:post, "https://#{client_url}/oauth2/token").
      with(:body => {
              :client_id => 'alice@example.org;eve@example.org',
              :client_secret => 'sig',
              :grant_type => 'client_credentials'
            }, 
           :headers => {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'97', 'Content-Type'=>'application/x-www-form-urlencoded'}).
      to_return(:status => 200, :body => @json.to_json.to_s, :headers => {})

      @request = Request.diaspora_initialize(:from => alice.person, :to => eve.person, :into => @aspect)
      @time = Time.now
      Time.stub!(:now).and_return(@time)
      @request.stub!(:recipient).and_return(eve.person)
      eve.person.stub!(:owner).and_return(eve)
      
      @key = eve.encryption_key
      eve.stub!(:encryption_key).and_return(@key)

      @challenge = [alice.person.diaspora_handle,eve.person.diaspora_handle, @time.to_i].join(";")
    end

    after do
      RestClient.stub!(:post).and_return(FakeHttpRequest.new(:success))
    end

    it 'asks for authorization' do
      pending "panda"
    end

    it 'verifies authenticity of challenge' do
      pending "panda"
    end

    it 'signs a challenge' do
      @key.should_receive(:sign).with(OpenSSL::Digest::SHA256.new, @challenge)
      Rack::OAuth2::Client.any_instance.stub(:access_token!).and_return(true)


      @request.stub(:save_tokens)

      @request.receive(eve, alice.person)
    end

    it 'POSTS a signed challenge' do
      @key.stub!(:sign).with(OpenSSL::Digest::SHA256.new, @challenge).and_return("sig")

      @request.receive(eve, alice.person)
    end

    it 'stores authorization and refresh tokens' do
      @key.stub!(:sign).with(OpenSSL::Digest::SHA256.new, @challenge).and_return("sig")

      @request.receive(eve, alice.person)
      
      eve.contact_for(alice.person).access_token.token.should == @json[:access_token]
      eve.contact_for(alice.person).access_token.expires_at.to_i.should == (@time + 15.minutes).to_i
      eve.contact_for(alice.person).refresh_token.token.should == @json[:refresh_token]
      eve.contact_for(alice.person).refresh_token.expires_at.to_i.should == (@time + 1.month).to_i
    end

    it 'sets sharing' do
      Request.diaspora_initialize(:from => eve.person, :to => alice.person,
                                  :into => eve.aspects.first).receive(alice, eve.person)
      alice.contact_for(eve.person).should be_sharing
    end
  end

  context 'xml' do
    before do
      @request = Request.diaspora_initialize(:from => alice.person, :to => eve.person, :into => @aspect)
      @xml = @request.to_xml.to_s
    end

    describe 'serialization' do
      it 'produces valid xml' do
        @xml.should include alice.person.diaspora_handle
        @xml.should include eve.person.diaspora_handle
        @xml.should_not include alice.person.exported_key
        @xml.should_not include alice.person.profile.first_name
      end
    end

    context 'marshalling' do
      it 'produces a request object' do
        marshalled = Request.from_xml @xml

        marshalled.sender.should == alice.person
        marshalled.recipient.should == eve.person
        marshalled.aspect.should be_nil
      end
    end
  end
end
