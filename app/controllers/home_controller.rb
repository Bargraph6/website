class HomeController < ApplicationController
  before_action :redirect_pagination

  def index
    articles_for_current_page = Article.includes(:categories).english.live.published.root

    @body_id = 'home'
    @homepage = true

    # Homepage featured article
    @latest_article = articles_for_current_page.first if first_page?

    # Feed artciles
    @articles = articles_for_current_page.page(params[:page]).per(6).padding(1)

    render "#{Current.theme}/home/index"
  end

  private

  def first_page?
    params[:page].blank?
  end

  def redirect_pagination
    return if params[:page].blank?

    redirect_to [:articles, { page: params[:page] }]
  end
end
