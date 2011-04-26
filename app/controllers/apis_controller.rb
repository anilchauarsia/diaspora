class ApisController < ApplicationController #We should start with this versioned, V0ApisController  BEES
  before_filter :require_oauth_token, :only => [:user_timeline]
  respond_to :json
  respond_to :xml, :only => [:user_timeline]
  #posts
  def public_timeline
    set_defaults
    timeline = StatusMessage.where(:public => true).includes(:photos, :author => :profile).paginate(:page => params[:page], :per_page => params[:per_page], :order => "#{params[:order]} DESC")
    respond_with timeline do |format|
      format.json{ render :json => timeline.to_json(:format => :twitter) }
    end
  end

  def user_timeline
    set_defaults

    pp "after set defaults"
    if params[:user_id]
      person = Person.where(:guid => params[:user_id]).first
    elsif params[:screen_name]
      person = Person.where(:diaspora_handle => params[:screen_name]).first
    end
    
    pp person

    if person 
      if @current_token
        pp "with access token"
        user = @current_token.client.contact.user
        contact_id = user.contact_for(person).id

        pp bob.raw_visible_posts.map(&:contacts)
        pp user.diaspora_handle
        timeline = Post.joins(:post_visibilities).where(:post_visibilities => {:contact_id => contact_id}).all
        pp timeline
      else
        pp "without access token"
        timeline = StatusMessage.where(:public => true, :author_id => person.id).includes(:photos).paginate(:page => params[:page], :per_page => params[:per_page], :order => "#{params[:order]} DESC")
      end
      respond_with timeline do |format|
        format.json{ render :json => timeline.to_json(:format => :twitter) }
        format.xml do
          timeline = timeline.collect do |post|
            post.to_xml.to_s
          end

          render :xml => "<XML><post>#{timeline.join('')}</post></XML>"
        end
      end
    else
      render :json => {:status => 'failed', :reason => 'user not found'}, :status => 404
    end
  end

  def home_timeline
    set_defaults
    timeline = current_user.visible_posts(:max_time => params[:max_time],
                                          :limit => params[:per_page],
                                          :order => "#{params[:order]} DESC").includes(:comments, :photos, :likes, :dislikes)
    respond_with timeline do |format|
      format.json{ render :json => timeline.to_json(:format => :twitter) }
    end
  end

  def statuses
    status = StatusMessage.where(:guid => params[:guid], :public => true).includes(:photos, :author => :profile).first
    if status
      respond_with status do |format|
        format.json{ render :json => status.to_json(:format => :twitter) }
      end
    else
      render(:nothing => true, :status => 404)
    end
  end

  #people
  def users
    if params[:user_id]
      person = Person.where(:guid => params[:user_id]).first
    elsif params[:screen_name]
      person = Person.where(:diaspora_handle => params[:screen_name]).first
    end

    if person && !person.remote?
      respond_with person do |format|
        format.json{ render :json => person.to_json(:format => :twitter) }
      end
    else
      render(:nothing => true, :status => 404)
    end
  end

  def users_search
    set_defaults

    if params[:q]
      people = Person.public_search(params[:q]).paginate(:page => params[:page], :per_page => params[:per_page], :order => "#{params[:order]} DESC")
    end

    if people
      respond_with people do |format|
        format.json{ render :json => people.to_json(:format => :twitter) }
      end
    else
      render(:nothing => true, :status => 404)
    end
  end

  def users_profile_image
    if person = Person.where(:diaspora_handle => params[:screen_name]).first
      redirect_to person.profile.image_url
    else
      render(:nothing => true, :status => 404)
    end
  end

  #tags
  def tag_posts
    set_defaults
    posts = StatusMessage.where(:public => true, :pending => false)
    posts = posts.tagged_with(params[:tag])
    posts = posts.includes(:comments, :photos).paginate(:page => params[:page], :per_page => params[:per_page], :order => "#{params[:order]} DESC")
    render :json => posts.as_json(:format => :twitter)
  end

  def tag_people
    set_defaults
    profiles = Profile.tagged_with(params[:tag]).where(:searchable => true).select('profiles.id, profiles.person_id')
    people = Person.where(:id => profiles.map{|p| p.person_id}).paginate(:page => params[:page], :per_page => params[:per_page], :order => "#{params[:order]} DESC")
    render :json => people.as_json(:format => :twitter)
  end

  protected
  def set_defaults
    params[:per_page] = 20 if params[:per_page].nil? || params[:per_page] > 100
    params[:order] = 'created_at' unless ['created_at', 'updated_at'].include?(params[:order])
    params[:page] ||= 1
  end

  def require_oauth_token
    token = params[:oauth_token] #request.env[Rack::OAuth2::Server::Resource::Bearer]
    @current_token = AccessToken.where("token = '#{token}' AND client_id IS NOT NULL").first if token
    pp "at the end of require oauth token"
    #raise Rack::OAuth2::Server::Resource::Bearer::Unauthorized unless @current_token
  end
end
