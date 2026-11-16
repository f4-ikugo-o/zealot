# frozen_string_literal: true

module Middleware
  # 条件は公式 Docker の Caddy と同じ（docker/rootfs/etc/Caddyfile の @protected）
  class PrivateUploads
    PROTECTED_PATH = %r{\A/(?:uploads|backup)/}
    PUBLIC_PATH = %r{\A/uploads/apps/.+/icons/}
    NOT_FOUND_BODY = "Not Found\n"

    def initialize(app)
      @app = app
    end

    def call(env)
      path = normalize(env['PATH_INFO'].to_s)
      return not_found if path.match?(PROTECTED_PATH) && !path.match?(PUBLIC_PATH)

      @app.call(env)
    end

    private

    def normalize(path)
      Rack::Utils.clean_path_info(Rack::Utils.unescape_path(path))
    rescue StandardError
      path
    end

    def not_found
      [
        404,
        { 'content-type' => 'text/plain', 'content-length' => NOT_FOUND_BODY.bytesize.to_s },
        [NOT_FOUND_BODY]
      ]
    end
  end
end
