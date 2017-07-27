

def get_settlement_ids

 
    @settlement_ids = []

    #URL-encode all parameters
    parameters = URI.encode_www_form(
      'begin_time' => @begin_time,
      'end_time'   => @end_time      
    )

    connect_string = '/settlements?' + parameters
    s_ids = CallSquare.new.api_call connect_string
    s_ids.each do |ids|
       @settlement_ids << ids['id']
    end
    
    return @settlement_ids

end

def parse_settelments(settlement_ids)
    settlements = []
    settlement_ids.each do |id|
        connect_string = '/settlements/' + id
        settlement_events = CallSquare.new.events_api_call connect_string
        settlements += settlement_events
    end
    #puts settlements.to_json
    settlement_math(settlements)
end

def settlement_math(settlements)
    @settlement_arry = []
    capital = {}
    deposit = {}
    
   
    #get square capital payments, refunds and instant deposit fees
    settlements.each do |s| 
        cap_money = deposit_money = instant_dep_fee = 0
        deposit_money += s['total_money']['amount']
        initiated_at = s['initiated_at']
 
        s['entries'].each do |e|
           # puts s['id']
            if e['type'] == 'SQUARE_CAPITAL_PAYMENT'
                 cap_money += e['amount_money']['amount']
            elsif e['type'] == 'SQUARE_CAPITAL_REVERSED_PAYMENT'
                cap_money -= e['amount_money']['amount']
            elsif e['type'] == 'OTHER'
                instant_dep_fee += e['amount_money']['amount']
            end   
        end

        capital =  {  'initiated_at' => initiated_at,
                     'capital' => cap_money,
                     'deposit' => deposit_money,
                     'instant_dep_fee' => instant_dep_fee
                } 

        @settlement_arry << capital
    end   
     
end

def settlements_pdf  #settlements pdf standalone
  settlement_data = []

  Prawn::Document.generate("#{@accounting_data['date'].strftime("%m-%d-%Y")}_accounting.pdf" ) do |pdf|
   
    @settlement_arry.each do |set|     
        settlement_data << [{:content => "Initiated On: " +  Date.parse(set['initiated_at']).to_s, :colspan => 4}] 
        settlement_data << [{:content =>  "Deposit", :colspan => 2}, "106", fm(set['deposit'])] 
        settlement_data << [{:content =>  "Capital", :colspan => 2}, " ", fm(set['capital'])] 
        settlement_data << [{:content =>  "Instant Deposit Fee ", :colspan => 2},"", fm(set['instant_dep_fee'])]
        settlement_data << [{:content => " ", :colspan =>2}, " "," "]
    end

    pdf.text("Citizen " + @accounting_data['date'].strftime("%m-%d-%Y"), size: 12, style: :bold)
    pdf.move_down 20
    pdf.table(settlement_data, :width => 500, :cell_style => { :border_width => [0,0], size: 12, font_style: :bold}) do
        column(0).align = :left
        column(1).align = :left
        column(2).align = :left  
        column(3).align = :right
      end
 
  end

    FileUtils.move  "#{@accounting_data['date'].strftime("%m-%d-%Y")}_accounting.pdf" , "../docs/pdf/#{@accounting_data['date'].strftime("%m-%d-%Y")}_accounting.pdf"

end