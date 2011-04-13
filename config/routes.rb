#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

Diaspora::Application.routes.draw do

  # Posting and Reading

  resources :aspects do
    get 'manage'                    => :manage, :on => :collection
    put 'toggle_contact_visibility' => :toggle_contact_visibility
  end

  resources :status_messages, :only => [:new, :create, :destroy, :show]
  get 'bookmarklet' => 'status_messages#bookmarklet'
  get 'p/:id'       => 'posts#show', :as => 'post'

  resources :photos, :except => [:index] do
    put 'make_profile_photo' => :make_profile_photo
  end

  resources :comments, :only => [:create, :destroy]

  resources :likes, :only => [:create, :destroy]

  resources :conversations do
    resources :messages, :only => [:create, :show]
    delete 'visibility' => 'conversation_visibilities#destroy'
  end

  resources :notifications, :only => [:index, :update] do
    get 'read_all' => :read_all, :on => :collection
  end

  resources :tags, :only => [:index]
  get 'tags/:name' => 'tags#show', :as => 'tag'

  # Users and people

  resource :user, :only => [:edit, :update, :destroy], :shallow => true do
    get :export
    get :export_photos
  end


  controller :users do
    get 'public/:username'          => :public,          :as => 'users_public'
    match 'getting_started'         => :getting_started, :as => 'getting_started'
    get 'getting_started_completed' => :getting_started_completed
  end

  # This is a hack to overide a route created by devise.
  # I couldn't find anything in devise to skip that route, see Bug #961
  match 'users/edit' => redirect('/user/edit')

  devise_for :users, :controllers => {:registrations => "registrations",
                                      :password      => "devise/passwords",
                                      :sessions      => "sessions",
                                      :invitations   => "invitations"} do
    get 'invitations/resend/:id' => 'invitations#resend', :as => 'invitation_resend'
  end

  # generating a new user token (for devise)

  # ActivityStreams routes
  scope "/activity_streams", :module => "activity_streams", :as => "activity_streams" do
    resources :photos, :controller => "photos", :only => [:create, :show, :destroy]
  end

  #Temporary token_authenticable route
  resource :token, :only => [:show, :create]

  get 'login' => redirect('/users/sign_in')

  scope 'admins', :controller => :admins do
    match 'user_search'   => :user_search
    get   'admin_inviter' => :admin_inviter
    get   'add_invites'   => :add_invites, :as => 'add_invites'
  end

  resource :profile

  resources :contacts,           :except => [:index, :update, :create] do
    get :sharing, :on => :collection
  end
  resources :aspect_memberships, :only   => [:destroy, :create, :update]
  resources :post_visibilities,  :only   => [:update]

  resources :people, :except => [:edit, :update] do
    resources :status_messages
    resources :photos
    get  :contacts
    post 'by_handle' => :retrieve_remote, :on => :collection, :as => 'person_by_handle'
  end


  # Federation

  controller :publics do
    get 'webfinger'             => :webfinger
    get 'hcard/users/:guid'     => :hcard
    get '.well-known/host-meta' => :host_meta
    post 'receive/users/:guid'  => :receive
    get 'hub'                   => :hub
  end


  # External

  resources :services, :only => [:index, :destroy]
  controller :services do
    match '/auth/:provider/callback' => :create
    match '/auth/failure'            => :failure
    scope 'services' do
      match 'inviter/:provider' => :inviter, :as => 'service_inviter'
      match 'finder/:provider'  => :finder,  :as => 'friend_finder'
    end
  end

  #Oauth - adapted from https://github.com/nov/rack-oauth2-sample/ 

  resources :authorizations, :only => :create
  match 'oauth2/authorize', :to => 'authorizations#new'
  post 'oauth2/token', :to => proc { |env| token_endpoint.call(env) }


  #API
  scope 'api/v0', :controller => :apis do
    match 'statuses/public_timeline' => :public_timeline
    match 'statuses/home_timeline'   => :home_timeline
    match 'statuses/show/:guid'      => :statuses
    match 'statuses/user_timeline'   => :user_timeline

    match 'users/show'               => :users
    match 'users/search'             => :users_search
    match 'users/profile_image'      => :users_profile_image

    match 'tags_posts/:tag'          => :tag_posts
    match 'tags_people/:tag'         => :tag_people
  end


  # Mobile site

  get 'mobile/toggle', :to => 'home#toggle_mobile', :as => 'toggle_mobile'


  # Startpage

  root :to => 'home#show'
end

def setup_response(response, access_token, with_refresh_token = false)
  response.access_token = access_token.token
  response.refresh_token = access_token.create_refresh_token(
    :account => access_token.account,
    :client => access_token.client
  ).token if with_refresh_token
  response.token_type = access_token.token_type
  response.expires_in = access_token.expires_in
end

token_endpoint = Rack::OAuth2::Server::Token.new do |req, res|
  client = Client.find_by_identifier(req.client_id) || req.invalid_client!
  client.secret == req.client_secret || req.invalid_client!
  case req.grant_type
  when :authorization_code
    code = AuthorizationCode.valid.find_by_token(req.code)
    req.invalid_grant! if code.blank? || code.redirect_uri != req.redirect_uri
    setup_response res, code.access_token, :with_refresh_token
  when :password
    # NOTE: password is not hashed in this sample app. Don't do the same on your app.
    account = Account.find_by_username_and_password(req.username, req.password) || req.invalid_grant!
    setup_response res, account.access_tokens.create(:client => client), :with_refresh_token
  when :client_credentials
    # NOTE: client is already authenticated here.
    setup_response res, client.access_tokens.create, :with_refresh_token
  when :refresh_token
    refresh_token = client.refresh_tokens.valid.find_by_token(req.refresh_token)
    setup_response res, refresh_token.access_tokens.create
  else
    # NOTE: extended assertion grant_types are not supported yet.
    req.unsupported_grant_type!
  end
end

