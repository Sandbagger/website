class SetReferrerPolicy
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    [status, headers, response]
  end
end
