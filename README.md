README
======

A rebuild with devlog notes on how to build a new Rails 7 app with tailwind CSS, PostgreSQL db, RailsAdmin, Devise authentication.

Now updated to Rails 7.0.4.

Prerequisites
-------------

__mailcatcher__

`gem install mailcatcher`

You can start it with just mailcatcher - it runs a local webserver at localhost:1080 and catches SMTP locally at :1025

__pg__

`gem install pg`

If install fails, you likely need to install the Postgres headers. On a Mac the fastest way to do this is install Postgres itself:

`brew install postgres`

For running Postgres locally on a Mac try the Postgres.app

Create Application
------------------

Use bin/dev instead of rails s

```rails
  new r7template --css=tailwind --database=postgresql
  cd r7template
  bundle install
  bin/rails db:create
  bin/dev
```

Instead of simple indexing we'll use UUIDs.

`rails g migration EnableUUID`

Populate migration file:

```
class EnableUuid < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pgcrypto'
  end
end
```
Create `config/initializers/generators.db`:

```
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

Test that UUID indexing is working:

`bin/rails g scaffold Post title:string body:text ispublished:boolean --no-scaffold-stylesheet
`

Now, modify the migration that was just generated to use the new UUID

Modify the migration to use the new UUID feature
```
class CreatePosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts, id: :uuid do |t|
      t.string :title
      t.text :body
      t.boolean :ispublished
      t.timestamps
    end
  end
end
```

Add an appname and helper to `app/helpers/application_helper.rb':

```
def appname
  @appname = "Rails Template Application Name"
end
```

Add standalone pages we'll use to test authentication filtering:

`rails g controller pages index welcome about
`

Clean up routes for the new controllers:

```
match '/about',   to: 'pages#about',  via: 'get'
match '/welcome', to: 'pages#welcome', via: 'get'
resources :posts
root 'pages#index'
```

Add dynamic page title and description for your pages:

Application Layout at app/views/layouts/application.html.erb:

```
  <title><% if content_for?(:page_title) %><%= appname %> | <%= yield(:page_title) %><% else %><%= appname %><% end %></title>
  <% if content_for?(:page_description) %><meta name="description" content="<%= yield(:page_description) %>"/><% end %>
```

Then in individual pages add title and descriptions like:

in layout:

```
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><% if content_for?(:page_title) %><%= yield(:page_title) %> | <%= appname %><% else %><%= appname %><% end %></title>
<% if content_for?(:page_description) %><meta name="description" content="<%= yield(:page_description) %>"/><% end %>
<meta name="viewport" content="width=device-width,initial-scale=1">
```

then in each page like index, about, welcome:

```
<%= content_for :page_title, 'Home Page' %>
<%= content_for :page_description, 'Home Page' %>
```

Create a user resource before setting up Devise:

```
rails g model user firstname:string lastname:string isadmin:boolean
```

Then edit to add boolean defaults:

`t.boolean :isadmin, null: false, default: false`

Run the migration:

`rails db:migrate`

Install Devise
--------------

```
  bundle add devise
  rails g devise:install
```

Adjust config/environments/development.rb for devise and mailcatcher:

```
  # devise install wants a default url
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  config.action_mailer.delivery_method = :smtp
  # mailcatcher gem
  config.action_mailer.smtp_settings = { address: 'localhost', port: 1025 }
```

Add flash alerts for devise that work with Tailwind:

```
  <p class="notice"><%= notice %></p>
  <p class="alert"><%= alert %></p>
```

And now install devise for our user resource:

`rails g devise User`

Uncomment what you want to add in Devise like Trackable, Confirmable, etc.

Be sure t.timestamps is commented OUT or the Devise migration will fail.

Migrate and test it all:

```
  bin/rails db:migrate
  bin/dev
  mailcatcher
  localhost:1080
  localhost:3000/users/sign_up
```
Configure routes:

```
devise_scope :user do
  # Redirects signing out users back to sign-in
  get "users", to: "devise/sessions#new"
end

# change default /user/action URLs for devise
  devise_for :users, path: '', path_names: { sign_in: 'signin', sign_out: 'signout', password: 'iforgot', confirmation: 'verification', unlock: 'unlock', registration: '', sign_up: 'signup' }
```

The best way to manage signup and signout is through cleaning up the menus like this in application layout:

```
  <nav class="navbar navbar-light bg-gray-800">
    <div class="container-fluid p-6">
      <ul class="navbar-nav flex flex-row space-x-5">
        <li class="font-bold text-white"><a href="/"><%= appname %></a></li>
        <% if user_signed_in? %><li class="text-white"><a href="/welcome">welcome</a></li><% end %>
        <li class="text-white hover:text-gray-400"><a href="/about">about</a></li>
        <% if user_signed_in? %><li class="nav-item text-white"><%= link_to 'edit profile', edit_user_registration_path %></li>
        <% if user_signed_in? && current_user.isadmin? %><li class="nav-item text-white"><%= link_to 'admin', rails_admin_path %></li><% end %>
        <%# link_to 'sign out', destroy_user_session_path, method: 'delete', status: 303 %>
        <li class="nav-item text-white hover:text-gray-400">
          <%= button_to "sign out", destroy_user_session_path, method: :delete, data: { turbo: false } %>
          <%# link_to "sign out", destroy_user_session_path, data: { "turbo-method": :delete } %></li><% else %>
        <li class="nav-item text-white hover:text-gray-400"><%= link_to 'sign up', new_user_registration_path %></li>
        <li class="nav-item text-white hover:text-gray-400"><%= link_to 'sign in', new_user_session_path %></li><% end %>
      </ul>
    </div>
  </nav>
```

Adjust application controller for devise redirects:

```
  class ApplicationController < ActionController::Base

    before_action :configure_permitted_parameters, if: :devise_controller?

    # override the devise signin and signout url behavior
    def after_sign_in_path_for(_resource_or_scope)
      welcome_url
    end

    def after_sign_out_path_for(_resource_or_scope)
      root_url
    end

    protected

    # Allow extra attributes for user signup and user profile edit
    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up) do |u|
        u.permit(:firstname, :lastname, :email, :password, :current_password, :isadmin)
      end

      devise_parameter_sanitizer.permit(:account_update) do |u|
        u.permit(:firstname, :lastname, :email, :password, :password_confirmation,
                 :current_password, :isadmin)
      end
    end

  end
```

And add this to the pages controller:

`before_action :authenticate_user!, except: %i[index about]`

Then do some serious surgery on devise.rb:

```
  class TurboFailureApp < Devise::FailureApp
    def respond
      if request_format == :turbo_stream
        redirect
      else
        super
      end
    end

    def skip_format?
      %w[html turbo_stream */*].include? request_format.to_s
    end
  end

  Devise.setup do |config|
    # ==> Controller configuration
    # Configure the parent class to the devise controllers.
    config.parent_controller = 'TurboDeviseController'
    # ==> Navigation configuration
    config.navigational_formats = ['*/*', :html, :turbo_stream]
    # ==> Warden configuration
    config.warden do |manager|
      manager.failure_app = TurboFailureApp
      #   manager.intercept_401 = false
      #   manager.default_strategies(scope: :user).unshift :some_external_strategy
    end
  end
```

Now copy over and tweak devise views:

`rails g devise:views`

And install the rails_admin gem.

bundle add 'rails_admin'

Start mailcatcher, sign up as a new user, then navigate to localhost:1080 to see your email in mailcatcher to confirm your account.

To become an admin (because there are none) use the rails console:

```
rails c
m = User.first
m.isadmin = true
m.save
```

Now when you refresh the page you should see the new 'admin' menu item.

You should probably delete the posts controllers now to build your app.




