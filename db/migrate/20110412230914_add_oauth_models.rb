class AddOauthModels < ActiveRecord::Migration
  def self.up
    create_table :access_tokens do |t|
      t.belongs_to :contact, :client, :refresh_token
      t.string :token, :token_type
      t.datetime :expires_at
      t.timestamps
    end

    create_table :clients do |t|
      t.belongs_to :contact
      t.string :identifier, :secret, :redirect_uri, :challenge
      t.timestamps
    end

    create_table :refresh_tokens do |t|
      t.belongs_to :contact, :client
      t.string :token
      t.datetime :expires_at
      t.timestamps
    end

    add_column :contacts, :server_token_id, :integer
    add_column :contacts, :client_token_id, :integer
  end

  def self.down
    remove_column :contacts, :client_token_id
    remove_column :contacts, :server_token_id

    drop_table :refresh_tokens

    drop_table :clients

    drop_table :access_tokens
  end
end
