#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'

describe Contact do
  describe 'aspect_memberships' do
    it 'deletes dependent aspect memberships' do
      lambda{
        alice.contact_for(bob.person).destroy
      }.should change(AspectMembership, :count).by(-1)
    end
  end

  context 'validations' do
    let(:contact){Contact.new}

    it 'requires a user' do
      contact.valid?
      contact.errors.full_messages.should include "User can't be blank"
    end

    it 'requires a person' do
      contact.valid?
      contact.errors.full_messages.should include "Person can't be blank"
    end

    it 'ensures user is not making a contact for himself' do
      contact.person = alice.person
      contact.user = alice

      contact.valid?
      contact.errors.full_messages.should include "Cannot create self-contact"
    end

    it 'validates uniqueness' do
      person = Factory(:person)

      contact2 = alice.contacts.create(:person=>person)
      contact2.should be_valid

      contact.user = alice
      contact.person = person
      contact.should_not be_valid
    end
  end

  context 'scope' do
    describe 'sharing' do
      it 'returns contacts with sharing true' do
        lambda {
          alice.contacts.create!(:sharing => true, :person => Factory(:person))
          alice.contacts.create!(:sharing => false, :person => Factory(:person))
        }.should change{
          Contact.sharing.count
        }.by(1)
      end
    end

    describe 'receiving' do
      it 'returns contacts with sharing true' do
        lambda {
          alice.contacts.create!(:receiving => true, :person => Factory(:person))
          alice.contacts.create!(:receiving => false, :person => Factory(:person))
        }.should change{
          Contact.receiving.count
        }.by(1)
      end
    end
  end

  describe '#contacts' do
    before do
      @alice = alice
      @bob = bob
      @eve = eve
      @bob.aspects.create(:name => 'next')
      @people1 = []
      @people2 = []

      1.upto(5) do
        person = Factory(:person)
        bob.contacts.create(:person => person, :aspects => [bob.aspects.first])
        @people1 << person
      end
      1.upto(5) do
        person = Factory(:person)
        bob.contacts.create(:person => person, :aspects => [bob.aspects.last])
        @people2 << person
      end
    #eve <-> bob <-> alice
    end

    context 'on a contact for a local user' do
      before do
        @contact = @alice.contact_for(@bob.person)
      end

      it "returns the target local user's contacts that are in the same aspect" do
        @contact.contacts.map{|p| p.id}.should == [@eve.person].concat(@people1).map{|p| p.id}
      end

      it 'returns nothing if contacts_visible is false in that aspect' do
        asp = @bob.aspects.first
        asp.contacts_visible = false
        asp.save
        @contact.contacts.should == []
      end

      it 'returns no duplicate contacts' do

        contact_ids = @contact.contacts.map{|p| p.id}
        contact_ids.uniq.should == contact_ids
      end
    end

    context 'on a contact for a remote user' do
      before do
        @contact = @bob.contact_for @people1.first
      end
      it 'returns an empty array' do
        @contact.contacts.should == []
      end
    end
  end

  context 'requesting' do
    before do
      @contact = Contact.new
      @user = Factory.create(:user)
      @person = Factory(:person)

      @contact.user = @user
      @contact.person = @person
    end

    describe '#generate_request' do
      it 'makes a request' do
        @contact.stub(:user).and_return(@user)
        request = @contact.generate_request

        request.sender.should == @user.person
        request.recipient.should == @person
      end
    end

    describe '#dispatch_request' do
      before do
        @contact.stub(:user).and_return(@user)
        @m = mock()
        @m.should_receive(:post)
      end
      
      it 'pushes to people' do
        Postzord::Dispatch.should_receive(:new).and_return(@m)
        @contact.dispatch_request
      end

      context 'oauth2' do
        it 'creates a client' do
          Postzord::Dispatch.stub(:new).and_return(@m)
          
          lambda{
            @contact.dispatch_request
          }.should change{
            Client.count
          }.by(1)
        end
      end
    end
  end

  context 'sharing/receiving status' do
    before do
      alice.share_with(eve.person, alice.aspects.first)

      @follower = eve.contact_for(alice.person)
      @following = alice.contact_for(eve.person)
    end

    describe '#sharing?' do
      it 'returns true if contact has no aspect visibilities' do
        @follower.should be_sharing
      end

      it 'returns false if contact has aspect visibilities' do
        @following.should_not be_sharing
      end

      it 'returns false if contact is not persisted' do
        Contact.new.should_not be_sharing
      end
    end

    describe '#receiving?' do
      it 'returns false if contact has no aspect visibilities' do
        @follower.should_not be_receiving
      end

      it 'returns true if contact has aspect visibilities' do
        @following.should be_receiving
      end
    end
  end

  describe '#receive_tokens' do
    # Server A issues a share request to Server B
    # Server B requests an authorization token for Server A for GET access

    # Request#receive_tokens is an alias_method as defined in
    #  spec/support/receive_tokens_stub.rb

    before do
      RestClient.unstub!(:post)
      client_url = "#{URI.parse(bob.person.url).host}:#{URI.parse(bob.person.url).port.to_s}"

      @json = {
         :access_token => "SlAV32hkKG",
         :token_type => "bearer",
         :refresh_token => "8xLOxBtZp8",
         :example_parameter => "example_value"
      }

      @contact = alice.contact_for(bob.person)
      @contact.access_token.destroy
      @contact.refresh_token.destroy
      @contact.save

      @time = Time.now
      Time.stub!(:now).and_return(@time)

      stub_request(:post, "https://#{client_url}/oauth2/token").to_return(:status => 200, :body => @json.to_json.to_s, :headers => {})

      @key = alice.encryption_key
      alice.stub(:encryption_key).and_return(@key)
      @contact.stub(:user).and_return(alice)

      @nonce = SecureToken.generate(32)
      SecureToken.stub(:generate).and_return(@nonce)
      @challenge = [bob.person.diaspora_handle,alice.person.diaspora_handle, @time.to_i, @nonce].join(";")

    end

    after do
      RestClient.stub(:post).and_return(FakeHttpRequest.new(:success))
    end

    it 'signs a challenge' do
      @key.should_receive(:sign).with(OpenSSL::Digest::SHA256.new, @challenge).and_return("sig")
      Rack::OAuth2::Client.any_instance.stub(:access_token!).and_return(true)
      @contact.stub(:save_tokens)

      @contact.receive_tokens_original
    end

    it 'POSTS a signed challenge' do
      @key.stub(:sign).with(OpenSSL::Digest::SHA256.new, @challenge).and_return("sig")

      @contact.receive_tokens_original
    end

    it 'stores authorization and refresh tokens' do
      @key.stub(:sign).with(OpenSSL::Digest::SHA256.new, @challenge).and_return("sig")

      @contact.receive_tokens_original
      
      @contact.reload.access_token.token.should == @json[:access_token]
      @contact.reload.access_token.expires_at.to_i.should == (@time + 15.minutes).to_i
      @contact.reload.refresh_token.token.should == @json[:refresh_token]
      @contact.reload.refresh_token.expires_at.to_i.should == (@time + 1.month).to_i
    end

    it 'generates a nonce' do
      SecureToken.should_receive(:generate).with(32)
      Rack::OAuth2::Client.any_instance.stub(:access_token!).and_return(true)
      @contact.stub(:save_tokens)

      @contact.receive_tokens_original
    end
  end
end
