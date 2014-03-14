class CharitiesController < ApplicationController
  def index
    @charities = Charity.all
  end

  def new
    @charity = Charity.new
    # create a page relating to the charity id
    @page = @charity.pages.build
    # create content relating to the page id
    @content = @page.build_content
  end

  def edit
  end

  def update
  end

  def destroy
    @charity = Charity.where( domain: params[ :id ] ).take

    if session[ :auth ] and session[ :user_id ] == User.get_admin.id
      @charity.destroy
      
      redirect_to :back
    else
      redirect_to login_path
    end
  end

  def search
    @charities = Charity.search( params[ :charity ][ :org_name ] )
    render 'index'
  end

  def verify
    require "open-uri"
    require "nokogiri"
    require "timeout"
    
    # the charity number the user provides
    number_to_verify = params[ :charity_number ]

    # the page to scrape
    url = "http://www.revenue.ie/en/business/authorised-charities-resident.html"
    json = { status: "no-list" }

    # check if number has already been used
    charity = Charity.where( charity_number: number_to_verify ).take
    if charity.blank?
      begin
        # break after 10 seconds
        timeout( 10 ) do
          # get webpage
          doc = Nokogiri::HTML( open( url ))

          # get rows of the table
          doc.css( "tr" ).each do |row|
            if row.css( "td:nth-child(1)" ).text == number_to_verify
              # success!
              json = { 
                status: "okay", 
                id: row.css( "td:nth-child(1)" ).text, 
                org_name: row.css( "td:nth-child(2)" ).text, 
                address: row.css( "td:nth-child(3)" ).text 
              }
            end
          end
        end
      rescue Timeout::Error
        json = {
          status: "504",
          error: "connection timeout"
        }
      end
    else
      # this charity exists, however has already in use
      json = { 
        status: "taken",
        org_name: charity.org_name
      }
    end

    render :json => json.to_json
  end

  def domain_check
    domain_to_check = params[ :domain ]
    rows_returned = Charity.where( domain: domain_to_check ).length
    render :json => { status: "okay", rows: rows_returned }.to_json
  end

  private
  # strong parameters - this is a whitelist allowing only these form attributes
  # required by Rails

  def get_charity_params
    params.require( :charity ).permit( :domain, :org_name, :org_address, :org_tel, :charity_number, :charity_number_verified, :email, :template )
  end

  def get_user_params
    params.require( :user ).permit( :f_name, :l_name, :email, :email_confirmation, :password, :password_confirmation )
  end
end
