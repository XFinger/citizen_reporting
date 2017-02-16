  




def accounting_pdf #report for accountant
  Prawn::Document.generate("#{@date}_accounting.pdf" ) do |pdf|
   

    part1 = ([ [{:content =>  "Food Sales", :colspan => 2}, "600", fm(@shift_data['food_sales'])],
               [{:content =>  "ABC Sales", :colspan => 2}, " ", fm(@accounting_data['abc_sales'])],
               [{:content =>  "Beer - Wine - Liquor", :colspan => 2}, " ", fm(@shift_data['abc_sales']['beer_money']) + ' - ' + fm(@shift_data['abc_sales']['wine_money']) + ' - ' + fm(@shift_data['abc_sales']['liquor_money'])],
               [{:content =>  "Retail Sales", :colspan => 2}, " ", fm(@shift_data['retail_sales'])],
               [{:content =>  "Sales Tax", :colspan => 2},"442", fm(@shift_data['tax_collected']) + "  /  " + fm(@accounting_data['city_tax'])],
               [{:content =>  "Retail Tax", :colspan => 2}, " ", fm(@shift_data['retail_tax'])],
               [{:content =>  "GC Sold", :colspan => 2}," ", fm(@accounting_data['gc_sold'])],
               [{:content =>  "Total", :colspan => 2}," ", fm(@accounting_data['total'])],
               [{:content =>  " ", :colspan => 2}," "," "],    
               [{:content =>  "Food Purchases", :colspan => 2},"710",fm(@accounting_data['food_purchases'])],
               [{:content =>  "Supplies", :colspan => 2},"884", fm(@accounting_data['supplies'])],
               [{:content =>  "Repairs", :colspan => 2},"878", fm(@accounting_data['repairs'])],
               [{:content =>  "Laundry", :colspan => 2},"858", fm(@accounting_data['laundry'])],
               [{:content =>  "Office Supplies", :colspan => 2},"882", fm(@accounting_data['office_supplies'])],
               [{:content =>  "Credit Card Fee", :colspan => 2}, " ", fm(@accounting_data['cc_fees'])],
               [{:content =>  "GC Redeemed", :colspan => 2},"",fm(@accounting_data['gift_certificate_sales'])],
               [{:content =>  "Charge Tip Payout", :colspan => 2},"",fm(@shift_data['credit_tips'])],
               [{:content =>  "Total Disbursements", :colspan => 2},"",fm(@accounting_data['total_dispursements'])],
               [{:content =>  " ", :colspan => 2}," "," "], 
               [{:content =>  "Cash Deposit", :colspan => 2},"105",fm(@accounting_data['cash_deposit'])],
               [{:content =>  "Charge Deposit", :colspan => 2}, "106",fm(@accounting_data['charge_deposit'])],
               [{:content =>  "Total Receipts", :colspan => 2},"",fm(@accounting_data['total'])]
      ])

    pdf.text("Citizen", size: 16, style: :bold)
    pdf.text(@shift_data['date'], size: 16, style: :bold)
    pdf.move_down 20
    pdf.table(part1, :width => 500, :cell_style =>
     { :border_width => [0,0], size: 15, style: :bold}) do
        column(0).align = :left
        column(1).align = :left
        column(2).align = :left  
        column(3).align = :right
      end
 
  end

  #move file to docs/pdf folder
  FileUtils.move  "#{@date}_accounting.pdf" , "../docs/pdf/#{@date}_accounting.pdf"

end





