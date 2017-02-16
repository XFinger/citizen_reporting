#dev tool to print the shift_data hash
module Helper

  def print_hash
    puts '________________________________________'
    @shift_data.each do |key, value|
        puts key + ' : ' + value.to_s
        puts value.class
    end
    puts '________________________________________'
  
  end
  
  # Helper to convert floats to  integers (pennies)
  def to_pennies(dec)
    pennies = (dec * 100).to_int
    return pennies
  end
  
  # Helper function to convert cent-based money amounts to dollars and cents
  def fm(money)
    money_string = format("%.2f", (money.abs/100.to_f))
    if money < 0
      money_string = '( ' + money_string + ' )'
    end
    return money_string
  end

  def cleanup #move generated files to google drive folder clear the terminal and return to the menu
    system "clear"  #clear the terminal
    puts 'PDF document created'
    puts ' '
    menu            #go back to main menu
  end

end