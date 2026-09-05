class ApplicationController < ActionController::API
  rescue_from Lipwa::ConfigurationError, with: :render_configuration_error
  rescue_from Lipwa::UnsupportedCapabilityError, with: :render_configuration_error

  private

  # Renders the gem's Success/Failure(ValidationError|GatewayError) result
  # as JSON. `on_success` maps the Lipwa::Response into your own payload
  # (e.g. saving a Transaction) before it's rendered.
  def render_result(result, status: :ok, on_failure: nil, &on_success)
    result.either(
      lambda do |response|
        payload = on_success ? on_success.call(response) : response.raw
        render json: payload, status: status
      end,
      lambda do |error|
        on_failure&.call(error)

        case error
        when Lipwa::ValidationError
          render json: { errors: error.validation_result.errors.to_h }, status: :unprocessable_entity
        when Lipwa::GatewayError
          render json: { error: error.message, code: error.code }, status: :bad_gateway
        else
          raise error
        end
      end
    )
  end

  def render_configuration_error(error)
    render json: { error: error.message }, status: :internal_server_error
  end
end
