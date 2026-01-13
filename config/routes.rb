require 'sidekiq/web'

Rails.application.routes.draw do
  # sitemaps
  # xml: for robots/search engines
  # txt: for humans/archivers
  get 'sitemap_xml', to: 'sitemap#sitemap_xml', defaults: { format: 'xml' }, as: :sitemap_xml
  get 'sitemap_txt', to: 'sitemap#sitemap_txt', defaults: { format: 'txt' }, as: :sitemap_txt

  # TEMP: Delete after switching the site auth to Devise, enable this auth protected route
  # # Sidekiq admin interface to monitor background jobs
  mount Sidekiq::Web => '/sidekiq',
        constraints: lambda { |request|
                       User.where(id: request.session['user_id']).first&.role&.in? %w[publisher developer]
                     }

  # Homepage
  root to: 'home#index'

  get 'page', to: redirect('/page/1'), as: :page_one
  get 'page/:page', to: 'articles#index', as: :articles

  # To Change Everything (TCE)
  get 'tce(/:lang)',
      to:       'to_change_everything#show',
      defaults: { lang: 'english' },
      as:       :to_change_everything

  # Steal Something from Work Day (SSfWD)
  get 'steal-something-from-work-day(/:locale)',
      to:       'steal_something_from_work_day#show',
      defaults: { locale: 'english' },
      as:       :steal_something_from_work_day

  # Articles
  # Article listings by year, optional month, optional day
  get '(/:year)(/:month)(/:day)/page(/1)', to: redirect { |_, req|
    req.path.split('page').first
  }
  get '/(:year/(:month/(:day)))/(page/:page)',
      to:          'article_archives#index',
      constraints: { year: /\d{4}/, month: /\d{2}/, day: /\d{2}/ },
      as:          :article_archives

  # Article permalink
  # no (/:lang) since slug should encompass that
  get ':year/:month/:day/:slug(.:format)',
      to:          'articles#show',
      constraints: { year: /\d{4}/, month: /\d{2}/, day: /\d{2}/ },
      as:          :article

  # Article edit convenience route
  get ':year/:month/:day/:slug/edit',
      controller:  'admin/articles',
      action:      'edit',
      constraints: { year: /\d{4}/, month: /\d{2}/, day: /\d{2}/ }

  # Fallback route for mangled date URL fragments, example: .com/202 (one digit cut off a year)
  get '/(:year/(:month/(:day)))/(page/:page)',
      to:          'article_archives#index',
      constraints: { year: /\d*/, month: /\d*/, day: /\d*/ },
      as:          :article_archives_fallback

  # Draft Articles and Pages
  get 'drafts/articles/:draft_code',            to: 'articles#show',       as: :article_draft
  get 'drafts/pages/:draft_code',               to: 'pages#show',          as: :page_draft
  get 'drafts/episodes/:draft_code',            to: 'episodes#show',       as: :episode_draft
  get 'drafts/episodes/:draft_code/transcript', to: 'episodes#transcript', as: :episode_draft_transcript

  # Draft Articles and Pages /edit convenience routes
  get 'drafts/articles/:draft_code/edit', controller: 'admin/articles', action: 'edit'

  # Articles Atom Feed
  get 'feeds',             to: 'pages#feeds',                                  as: :feeds
  get 'feed(/:lang).json', to: 'articles#index', defaults: { format: 'json' }, as: :json_feed
  get 'feed(/:lang)',      to: 'articles#index', defaults: { format: 'atom' }, as: :feed

  # Articles - Collection Items
  get 'articles/:id_or_slug/collection_posts', to: 'collection_posts#index'

  # Categories
  get 'categories',                         to: 'categories#index', as: :categories
  get 'categories/:slug/page(/1)',          to: redirect { |path_params, _| "/categories/#{path_params[:slug]}" }
  get 'categories/:slug(/page/:page)',      to: 'categories#show', as: :category
  get 'categories/:slug/feed(/:lang).json', to: 'categories#feed', defaults: { format: 'json' }, as: :category_json_feed
  get 'categories/:slug/feed(/:lang)',      to: 'categories#feed', defaults: { format: 'atom' }, as: :category_feed

  # Tags
  get 'tags/:slug/page(/1)',          to: redirect { |path_params, _| "/tags/#{path_params[:slug]}" }
  get 'tags/:slug(/page/:page)',      to: 'tags#show', as: :tag
  get 'tags/:slug/feed(/:lang).json', to: 'tags#feed', defaults: { format: 'json' }, as: :tag_json_feed
  get 'tags/:slug/feed(/:lang)',      to: 'tags#feed', defaults: { format: 'atom' }, as: :tag_feed

  # Tools: Zines
  get 'zines',                        to: 'zines#index',    as: :zines
  get 'zines/:slug',                  to: 'zines#show',     as: :zine

  # Tools
  get 'tools',  to: 'tools#about',  as: :tools
  get 'random', to: 'tools#random', as: :random_tool

  # Site search
  get  'search',          to: 'search#index',      as: :search
  get  'search/advanced', to: redirect('/search'), as: :advanced_search

  # Admin Dashboard
  get :admin, to: redirect('/admin/dashboard'), as: 'admin'
  namespace :admin do
    # theme switcher
    resources :cookies

    get 'dashboard', to: 'dashboard#index'
    get 'markdown',  to: 'markdown#index', as: :markdown

    concern :paginatable do
      get 'page(/1)', on: :collection, to: redirect { |_, req| req.path.split('page').first }
      get '(page/:page)', action: :index, on: :collection, as: ''
    end

    resources :articles, concerns: :paginatable do
      member do
        get 'new', as: :new_collection_post
      end
      collection do
        get 'draft', as: :draft
      end
    end

    resources :categories,  concerns: :paginatable
    resources :definitions, concerns: :paginatable
    resources :links,       concerns: :paginatable
    resources :locales,     concerns: :paginatable
    resources :pages,       concerns: :paginatable
    resources :redirects,   concerns: :paginatable
    resources :users,       concerns: :paginatable
    resources :zines,       concerns: :paginatable
  end

  # Auth + User signup
  resources :users,    only: %i[create update destroy]
  resources :sessions, only: [:create]

  get 'signin',   to: 'sessions#new',     as: :signin
  get 'signout',  to: 'sessions#destroy', as: :signout

  # Misc plumbing infrastructure
  get 'manifest.json',  to: 'misc#manifest_json'
  get 'opensearch.xml', to: 'misc#opensearch_xml'

  # Pages
  get 'about',                 to: 'pages#about',   as: :about,   via: :all
  get 'contact',               to: 'pages#contact', as: :contact, via: :all
  get 'library',               to: 'pages#library', as: :library
  get 'submission-guidelines', to: 'pages#submission_guidelines'

  get 'key.pub',               to: 'pages#pgp_public_key', as: :pgp_public_key, via: :all

  get 'languages',         to: 'languages#index', as: :languages
  get 'languages/:locale', to: 'languages#show',  as: :language

  # For redirection, exempts Active Storage upload paths
  get '*path', to: 'pages#show', as: :page, via: :all, constraints: lambda { |req|
    req.path.exclude? 'rails/active_storage'
  }
end
