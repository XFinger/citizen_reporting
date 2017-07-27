require 'configatron'
require_relative '../config/configatron/defaults.rb'

class CallSquare

  ACCESS_TOKEN = configatron.access_token
  # The base URL for every Connect API request
  CONNECT_HOST = 'https://connect.squareup.com'
  # Standard HTTP headers for every Connect API request
  REQUEST_HEADERS = {
    'Authorization' => 'Bearer ' + ACCESS_TOKEN,
    'Accept' => 'application/json',
    'Content-Type' => 'application/json'
  }
  #unique store id
  LOCATION_ID = configatron.location_id


def api_call(connect_string)
 data = []  
  

request_path = CONNECT_HOST + '/v1/' + LOCATION_ID + connect_string  
    more_results = true
    while more_results do

      # Send a GET request to the List Payments endpoint
      response = Unirest.get request_path,
                   headers: REQUEST_HEADERS 
             
      # Read the converted JSON body into the cumulative array of results     
       
      data += response.body
 
      # Check whether pagination information is included in a response header, indicating more results
      if response.headers.has_key?(:link)
        pagination_header = response.headers[:link]
        if pagination_header.include? "rel='next'"
          # Extract the next batch URL from the header.
          #
          # Pagination headers have the following format:
          # <https://connect.squareup.com/v1/MERCHANT_ID/payments?batch_token=BATCH_TOKEN>;rel='next'
          # This line extracts the URL from the angle brackets surrounding it.
          request_path = pagination_header.split('<')[1].split('>')[0]
        else
          more_results = false
        end
      else
        more_results = false
      end
  end 
 return  data
end

def events_api_call(connect_string)
  data =[]
    request_path = CONNECT_HOST + '/v1/' + LOCATION_ID + connect_string  
    more_results = true
    while more_results do
      response = Unirest.get request_path,
                   headers: REQUEST_HEADERS 
      data << response.body 

      # Check whether pagination information is included in a response header, indicating more results
      if response.headers.has_key?(:link)
        pagination_header = response.headers[:link]
        if pagination_header.include? "rel='next'"
          request_path = pagination_header.split('<')[1].split('>')[0]
        else
          more_results = false
        end
      else
        more_results = false
      end
    end

    return data
end







end