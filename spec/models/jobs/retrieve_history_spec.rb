require 'spec_helper'

describe Job::RetrieveHistory do
  before do
    @user = alice
    @person = eve.person
    @person2 = bob.person
    @public_xml = 3.times.inject('') do |result, obj|
      result += Factory.build(:status_message, :author_id => @person.id, :public => true).to_xml.to_s
    end

    @private_xml = 3.times.inject('') do |result, obj|
      result += Factory.build(:status_message, :author_id => @person2.id).to_xml.to_s
    end

    @public_xml = "<XML><post>#{ @public_xml }</post></XML>"
    @private_xml = "<XML><post>#{ @private_xml }</post></XML>"

  end

  context 'public posts' do
    before do
      stub_request(:get, "#{@person.url}api/v0/statuses/user_timeline?format=xml&screen_name=#{@person.diaspora_handle}").
        with( :headers => {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate'}).
        to_return(:status => 200, :body => @public_xml, :headers => {})
    end

    it 'does a GET for public posts' do
      Job::RetrieveHistory.perform(@user.id, @person.id)
    end

    it 'saves public posts from a response' do
      lambda{
        Job::RetrieveHistory.perform(@user.id, @person.id)
      }.should change{
        Post.count
      }.by(3)
    end

    it 'sockets result posts to requesting user' do
      mock = Object.new
      mock.stub(:outgoing).and_return(true)

      SocketsController.should_receive(:new).exactly(3).times.and_return(mock)
      Job::RetrieveHistory.perform(@user.id, @person.id)
    end
 
    it "updates the person's fetched_at time" do
      @time = Time.now
      Time.stub(:now).and_return(@time)
      lambda{
        Job::RetrieveHistory.perform(@user.id, @person.id)
      }.should change{
        time = @person.reload.fetched_at
        time = time.to_i if time
        time
      }.from(nil).to(@time.to_i)
    end

  end

  context 'private posts' do
    before do
      @contact = @user.contact_for(@person2)
      Job::RetrieveHistory.stub(:get_data).and_yield
    end

    it "retrieves tokens if access token is nil" do
      @contact.access_token.destroy
      @contact.reload

      t = mock
      t.stub(:expired?).and_return(true)
      t.stub(:token).and_return("123")
      @contact.stub(:access_token).and_return(t)
      @contact.should_receive(:receive_tokens)

      @user.stub(:contact_for).and_return(@contact)
      User.stub(:find){ |id, *args|
        id == @user.id ? @user : nil
      }

      Job::RetrieveHistory.perform(@user.id, @person2.id)
    end

    it 'does a GET for private posts if the person is sharing with user' do
      Job::RetrieveHistory.unstub(:get_data)
      Job::RetrieveHistory.should_receive(:get_data)
      Job::RetrieveHistory.perform(@user.id, @person2.id)
    end
 
    it "updates the contact's fetched_at time" do
      Job::RetrieveHistory.stub(:get_data).and_yield

      @time = Time.now
      Time.stub(:now).and_return(@time)
      lambda{
        Job::RetrieveHistory.perform(@user.id, @person2.id)
      }.should change{
        time = @contact.reload.fetched_at
        time = time.to_i if time
        time
      }.from(nil).to(@time.to_i)
    end
  end

  describe '.get_data' do

    it 'does not yield on failure' do

      stub_request(:get, "#{@person.url}api/v0/statuses/user_timeline?format=xml&screen_name=#{@person.diaspora_handle}").
        with( :headers => {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate'}).
        to_return(:status => 500, :body => @public_xml, :headers => {})
      
      @time = Time.now
      Time.stub(:now).and_return(@time)
      lambda{
        Job::RetrieveHistory.perform(@user.id, @person.id)
      }.should_not change{
        time = @person.reload.fetched_at
        time = time.to_i if time
        time
      }

    end

  end
end
