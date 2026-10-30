module Api
  module V1
    class LeadIngestionsController < BaseController
      before_action -> { require_scope!("leads:ingest") }

      # POST /api/v1/lead_ingestions
      # 201 created · 200 already registered or replayed key · 409 key reused
      # with another body · 422 invalid payload · 401/403 token · 429 throttled.
      def create
        key = request.headers["Idempotency-Key"].to_s.strip
        unless key.length.between?(8, 128)
          return render_error(422, "idempotency_key_required", "Falta la cabecera Idempotency-Key (8 a 128 caracteres)")
        end

        body_sha = Digest::SHA256.hexdigest(request.raw_post.to_s)
        if (previous = @api_client.ingestion_requests.find_by(idempotency_key: key))
          return replay(previous, body_sha)
        end

        data = payload
        return render_error(400, "invalid_json", "El cuerpo debe ser un objeto JSON") unless data.is_a?(Hash)

        result = LeadIngestion.new(data, api_client: @api_client).call
        record = @api_client.ingestion_requests.create!(idempotency_key: key, request_sha256: body_sha, lead: result.lead,
                                                        response_status: result.status, response_body: result.body)
        render json: record.response_body, status: record.response_status
      rescue ActiveRecord::RecordNotUnique
        replay(@api_client.ingestion_requests.find_by!(idempotency_key: key), body_sha)
      end

      private
        def payload
          JSON.parse(request.raw_post.to_s)
        rescue JSON::ParserError
          nil
        end

        def replay(previous, body_sha)
          if previous.request_sha256 != body_sha
            return render_error(409, "idempotency_conflict", "La Idempotency-Key ya se usó con otro contenido")
          end

          response.set_header("Idempotent-Replayed", "true")
          render json: previous.response_body, status: previous.response_status
        end
    end
  end
end
