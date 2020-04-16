class RegistrationsController < ApplicationController
  before_action :redis_acquire_salt_minion_key, only: [:create, ]
  after_action  :redis_create_salt_minion_configuration, only: [:create, ]
  before_action :redis_delete_salt_minion_configuration, only: [:destroy, ]
  before_action :set_registration, only: [:show, :edit, :update, :destroy]

  # GET /registrations
  # GET /registrations.json
  def index
    @registrations = Registration.all
  end

  # GET /registrations/1
  # GET /registrations/1.json
  def show
    respond_to do |format|
      if @registration.nil?
        format.html { redirect_to new_registration_path }
        format.json { render json: @registration.errors, status: :unprocessable_entity }
      else
        format.html { render :show, notice: 'Registration was successfully created.' }
        format.json { render :show, status: :created, location: @registration }
      end
    end
  end

  # GET /registrations/new
  def new
    @registration = Registration.new
    @registration.swan_backend = Rails.configuration.swan['default_swan_backend']
    @registration.ike_daemon = Rails.configuration.swan['ike']['daemon']
  end

  # GET /registrations/1/edit
  def edit
    respond_to do |format|
      if @registration.nil?
        format.html { redirect_to new_registration_path }
        format.json { render json: @registration.errors, status: :not_found }
      else
        format.html { render :edit }
        format.json { render :show, status: :created, location: @registration }
      end
    end
  end

  # POST /registrations
  # POST /registrations.json
  def create
    # create new registration object
    @registration = Registration.new(registration_params)

    # precondition: salt minion key must exist
    if not File.file?(Rails.configuration.swan['salt_minion_key_path'])
      @notice = "Precondition failed: salt minion key not found."
      raise PreconditionFailed
    end

    # activation URL for SWAN backend
    @urlstring = [@registration.swan_backend, Rails.configuration.swan['path_swan_activate']].join('')

    # send POST request to backend for activation
    begin
        @result = HTTParty.post(
	    @urlstring.to_str, 
            :multipart => :true,
            :body => { 
	      :otp => @registration.otp,
              :saltkey =>  File.open(Rails.configuration.swan['salt_minion_key_path']),
	      :ike_daemon => @registration.ike_daemon,
              },
            :headers => { 
	      'Content-Type' => 'application/x-www-form-urlencoded',
	      'Accept' => 'application/json',
	      })
    rescue Errno::ECONNREFUSED => e
      respond_to do |format|
	@notice = "Unable to connect to #{@urlstring.to_s} with error #{e}."
        format.html { render :new, notice: @notice }
        format.json { render json: @registration.errors, status: :unprocessable_entity }
      end
      return
    rescue StandardError => e
      respond_to do |format|
	@notice = "Unable to register at #{@urlstring.to_s} with error #{e}."
        format.html { render :new, notice: @notice }
        format.json { render json: @registration.errors, status: :unprocessable_entity }
      end
      return
    end

    if @result.code == 201
      @notice = 'Device successfully connected to Secure WAN.'
      @registration.access_token = @result['access_token']
      @registration.salt_master = @result['salt_master']
      @registration.name = @result['name']
      @registration.ike_daemon = @result['ike_daemon']

      respond_to do |format|
        if @registration.save
          format.html { redirect_to @registration, notice: @notice }
          format.json { render :show, status: :created, location: @registration }
        else
          format.html { render :new, notice: @notice }
          format.json { render json: @registration.errors, status: :unprocessable_entity }
        end
      end
    else
      @notice = "Failed to connect device to Secure WAN at #{@urlstring.to_s} using activation code #{@registration.otp}. Error code #{@result.code}."
      respond_to do |format|
        format.html { render :new, notice: @notice }
        format.json { render json: @registration.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /registrations/1
  # PATCH/PUT /registrations/1.json
  def update
    respond_to do |format|
      if @registration.update(registration_params)
        format.html { redirect_to @registration, notice: 'Device successfully reconnected to Secure WAN.' }
        format.json { render :show, status: :ok, location: @registration }
      else
        format.html { render :edit }
        format.json { render json: @registration.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /registrations/1
  # DELETE /registrations/1.json
  def destroy
    if not @registration.nil?
      # deactivation URL for SWAN backend
      @urlstring = [@registration.swan_backend, Rails.configuration.swan['path_swan_deactivate']].join('')

      # send DELETE request to backend for deactivation
      @result = HTTParty.delete(
	      @urlstring.to_str, 
              :multipart => :true,
              :body => {
                :access_token => @registration.access_token, 
	        },
              :headers => {
	        'Content-Type' => 'application/x-www-form-urlencoded',
		'Accept' => 'application/json',
		})

      if @result.code != 204
        @notice = 'Failed to disconnect device from Secure WAN.'
      else
        @notice = 'Device successfully disconnected from Secure WAN.'
      end
      Registration.destroy_all

    end
    respond_to do |format|
      format.html { redirect_to new_registration_path, notice: @notice }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_registration
      @registration = Registration.first
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def registration_params
      params.require(:registration).permit(:name, :otp, :access_token, :swan_backend, :salt_master, :ike_daemon)
    end

    def redis_acquire_salt_minion_key
      SendRedisEventJob.perform_now 'swan.rails.salt.minion.key.get', nil
    end

    def redis_create_salt_minion_configuration
      SendRedisEventJob.perform_now 'swan.rails.salt.minion.config.create', {
        :id => @registration.name,
	:master => @registration.salt_master,
	:grains => {
	  :roles => [
	    'kernel',
	    'systemd',
	    'frr',
	    @registration.ike_daemon,
	    ],
	  },
	}
        #render_to_string(json: @registration)
    end

    def redis_delete_salt_minion_configuration
      SendRedisEventJob.perform_now 'swan.rails.salt.minion.config.delete', 
        render_to_string(json: @registration)
    end
end
