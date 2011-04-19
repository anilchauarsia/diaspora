require 'spec_helper'

describe Job::RetrieveHistory do
  before do
    @user = local_luke
    @person = remote_raphael
    @xml = 3.times.inject('') do |result, obj|
      result += Factory.build(:status_message, :author_id => @person.id, :public => true).to_xml.to_s
    end

    @xml = "<XML><post>#{ @xml }</post></XML>"

    stub_request(:get, "#{@person.url}statuses/user_timeline?user_id=#{@person.guid}").
    with(:headers => {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate'}).
    to_return(:status => 200, :body => @xml, :headers => {})
  end

  it 'does a GET for public posts' do
  end

  it 'saves public posts from a response' do
    lambda{
      Job::RetrieveHistory.perform(@user, @person)
    }.should change{
      Post.count
    }.by(3)
  end

  it 'sockets result posts to requesting user' do
    mock = Object.new
    mock.stub(:outgoing).and_return(true)

    SocketsController.should_receive(:new).exactly(3).times.and_return(mock)
    Job::RetrieveHistory.perform(@user, @person)
  end
end
