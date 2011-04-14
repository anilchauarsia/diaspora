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
      RestClient.unstub!(:post)
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
      request = Request.diaspora_initialize(:from => alice.person, :to => eve.person, :into => @aspect)
      time = Time.now
      Time.stub!(:now).and_return(time)
      request.stub!(:recipient).and_return(eve.person)
      eve.person.stub!(:owner).and_return(eve)
      
      key = eve.encryption_key
      eve.stub!(:encryption_key).and_return(key)

      challenge = [alice.person.diaspora_handle,eve.person.diaspora_handle, time.to_i].join(";")
      key.should_receive(:sign).with(OpenSSL::Digest::SHA256.new, challenge)
      request.send(:receive_tokens)
    end

    it 'POSTS a signed challenge' do

    end

    it 'stores authorization and refresh tokens' do
      pending "this might go in the controller, depending on redirection logic"
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
