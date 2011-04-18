#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'
require File.join(Rails.root, 'lib/diaspora/exporter')

describe Diaspora::Exporter do

  before do
    time = Time.now
    Time.stub(:now).and_return(time)

    @aspect  = alice.aspects.first
    @aspect1 = alice.aspects.create(:name => "Work")
    @aspect2 = eve.aspects.create(:name => "Family")
    @aspect3 = bob.aspects.first

    @status_message1 = alice.post(:status_message, :text => "One", :public => true, :to => @aspect1.id)
    @status_message2 = alice.post(:status_message, :text => "Two", :public => true, :to => @aspect1.id)
    @status_message3 = eve.post(:status_message, :text => "Three", :public => false, :to => @aspect2.id)
  end

  def exported
    Nokogiri::XML(Diaspora::Exporter.new(Diaspora::Exporters::XML).execute(alice))
  end

  context '<user/>' do
    it 'includes a users private key' do
      exported.xpath('//user').to_s.should include alice.serialized_private_key
    end
  end

  context '<aspects/>' do
    it 'includes the post_ids' do
      aspects_xml = exported.xpath('//aspects').to_s
      aspects_xml.should include @status_message1.id.to_s
      aspects_xml.should include @status_message2.id.to_s
    end
  end

  context '<contacts/>' do
    before do
      alice.add_contact_to_aspect(alice.contact_for(bob.person), @aspect1)
      alice.reload
    end

    let(:contacts_xml) {exported.xpath('//contacts').to_s}
    it 'includes a person id' do
      contacts_xml.should include bob.person.guid
    end

    it 'should include an aspects names of all aspects they are in' do
      #contact specific xml needs to be tested
      alice.contacts.find_by_person_id(bob.person.id).aspects.count.should > 0
      alice.contacts.find_by_person_id(bob.person.id).aspects.each { |aspect|
        contacts_xml.should include aspect.name
      }
    end
  end

  context '<people/>' do
    let(:people_xml) {exported.xpath('//people').to_s}

    it 'should include persons id' do
      people_xml.should include bob.person.guid
    end

    it 'should include their profile' do
      people_xml.should include bob.person.profile.first_name
      people_xml.should include bob.person.profile.last_name
    end

    it 'should include their public key' do
      people_xml.should include bob.person.exported_key
    end

    it 'should include their diaspora handle' do
      people_xml.should include bob.person.diaspora_handle
    end
  end

  context '<posts>' do
    let(:posts_xml) {exported.xpath('//posts').to_s}
    it 'should include many posts xml' do
      posts_xml.should include @status_message1.text
      posts_xml.should include @status_message2.text
      posts_xml.should_not include @status_message3.text
    end

    it 'should include post created at time' do
      doc = Nokogiri::XML::parse(posts_xml)
      target_xml = doc.xpath('//posts/status_message').detect{|status| status.to_s.include?(@status_message1.text)}
      xml_time = Time.zone.parse(target_xml.xpath('//status_message').text)
      xml_time.to_i.should == @status_message1.created_at.to_i
    end
  end
end
