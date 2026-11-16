# frozen_string_literal: true

class Download::ReleasesController < ApplicationController
  before_action :set_release
  before_action :require_download_auth

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found_entity_response

  def show
    return render_not_found_entity_response unless File.exist?(@release.file.path.to_s)

    redirect_to filename_download_release_url(@release, @release.download_filename)
  end

  def download
    # 触发 web_hook
    WebHookService.call(:download, channel: @release.channel, release: @release, user: download_user)

    headers['Content-Length'] = @release.file.size
    response.headers['X-Accel-Buffering'] = 'no'
    send_file @release.file.path,
              filename: @release.download_filename,
              disposition: 'attachment'
  end

  private

  def require_download_auth
    return if download_user || channel_password_matched?

    if @release.channel.password.present?
      return redirect_to channel_release_path(@release.channel, @release, back_url: @release.download_url)
    end

    if api_token.present? || !request.format.html?
      return render json: { error: t('api.unauthorized_token') }, status: :unauthorized
    end

    redirect_to new_user_session_path, alert: t('download.releases.login_required')
  end

  def download_user
    return @download_user if defined?(@download_user)

    @download_user = current_user || user_by_api_token
  end

  def user_by_api_token
    return if api_token.blank?

    User.find_by(token: api_token)
  end

  def api_token
    return @api_token if defined?(@api_token)

    matched = request.headers['Authorization'].to_s.match(/\A\s*(?:Token|Bearer)\s+(.+)\z/i)
    @api_token = matched ? matched[1].strip : request.headers['X-Zealot-Token'].presence
  end

  def channel_password_matched?
    @release.channel.password.present? && @release.cookie_password_matched?(cookies)
  end

  def render_not_found_entity_response
    render json: {
      error: t('.not_found')
    }, status: :not_found
  end


  def set_release
    @release = Release.find(params[:id])
  end
end

