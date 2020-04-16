class ApplicationController < ActionController::Base
  before_action :authorize

  class PreconditionFailed < StandardError; end
  rescue_from PreconditionFailed, with: :precondition_failed

  protected

    def authorize
      unless User.find_by(id: session[:user_id])
        redirect_to login_url, notice: "Please log in"
      end
    end

    def precondition_failed
      respond_to do |format|
        format.html { redirect_to new_registration_path, notice: @notice }
        format.json { render json: { :notice => @notice }, status: :precondition_failed }
      end
    end
end
