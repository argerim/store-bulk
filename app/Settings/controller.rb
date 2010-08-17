require 'rho'
require 'rho/rhocontroller'
require 'rho/rhoerror'
require 'helpers/browser_helper'

class SettingsController < Rho::RhoController
  include BrowserHelper
  
  def index
    @msg = @params['msg']
    render
  end

  def login
    @msg = @params['msg']
    render :action => :login, :back => '/app'
  end

  def login_callback
    errCode = @params['error_code'].to_i
    if errCode == 0
      # run sync if we were successful
      WebView.navigate Rho::RhoConfig.options_path
      SyncEngine.dosync
    else
      if errCode == Rho::RhoError::ERR_CUSTOMSYNCSERVER
        @msg = @params['error_message']
      end
        
      if !@msg || @msg.length == 0   
        @msg = Rho::RhoError.new(errCode).message
      end
      
      WebView.navigate ( url_for :action => :login, :query => {:msg => @msg} )
    end  
  end

  def do_login
    if @params['login'] and @params['password']
      begin
        SyncEngine.login(@params['login'], @params['password'], (url_for :action => :login_callback) )
        AppApplication.start_bulk_sync = Time.now
        
        render :action => :wait
      rescue Rho::RhoError => e
        @msg = e.message
        render :action => :login
      end
    else
      @msg = Rho::RhoError.err_message(Rho::RhoError::ERR_UNATHORIZED) unless @msg && @msg.length > 0
      render :action => :login
    end
  end
  
  def logout
    SyncEngine.logout
    @msg = "You have been logged out."
    render :action => :login
  end
  
  def reset
    render :action => :reset
  end
  
  def do_reset
    Rhom::Rhom.database_full_reset
    SyncEngine.dosync
    @msg = "Database has been reset."
    redirect :action => :index, :query => {:msg => @msg}
  end
  
  def do_sync
    SyncEngine.dosync
    @msg =  "Sync has been triggered."
    redirect :action => :index, :query => {:msg => @msg}
  end
  
  def sync_notify
    status = @params['status'] ? @params['status'] : ""  
    if status == "error"
      
      err_code = @params['error_code'].to_i
      rho_error = Rho::RhoError.new(err_code)

      @msg = @params['error_message'] if err_code == Rho::RhoError::ERR_CUSTOMSYNCSERVER
      @msg = rho_error.message() unless @msg && @msg.length > 0   

      if  rho_error.unknown_client?(@params['error_message'])
          Rhom::Rhom.database_client_reset
          SyncEngine.dosync
      elsif err_code == Rho::RhoError::ERR_UNATHORIZED
          WebView.navigate ( url_for :action => :login, :query => {:msg => "Server credentials are expired"} )                
      end    
      
    elsif status == "complete"
      WebView.navigate Rho::RhoConfig.start_path
    elsif @params['sync_type'] == 'bulk'
        puts "bulk_callback: #{@params}"

        if @params['bulk_status'] == 'start' && @params['partition'].length == 0
            AppApplication.start_bulk_sync = Time.now
            puts "Start time = " + AppApplication.start_bulk_sync.to_i.inspect
            WebView.navigate (url_for :action => :wait)
        end    
      
        AppApplication.end_bulk_sync = Time.now
        AppApplication.bulk_sync_total_time = 
          AppApplication.end_bulk_sync.to_i - AppApplication.start_bulk_sync.to_i
        WebView.navigate Rho::RhoConfig.start_path unless @params['status'] == 'in_progress'
    end
  
  end
end
