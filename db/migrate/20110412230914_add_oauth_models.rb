class AddOauthModels < ActiveRecord::Migration
  def self.up
    create_table :clients do |t|
      t.belongs_to :contact
      t.string :identifier, :secret, :redirect_uri
      t.timestamps
    end

    create_table :refresh_tokens do |t|
      t.belongs_to :contact, :client
      t.string :token
      t.string :nonce
      t.datetime :expires_at
      t.timestamps
    end

    create_table :access_tokens do |t|
      t.belongs_to :contact, :client, :refresh_token
      t.string :token, :token_type, :nonce
      t.datetime :expires_at
      t.timestamps
    end
  end

  def self.down
    drop_table :clients
    drop_table :refresh_tokens
    drop_table :access_tokens
  end
end
