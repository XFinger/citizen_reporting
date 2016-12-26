This is a custom solution for generating shift reports and end of day reports for accounting purposes. It
s written in Ruby and uses basic interview questions in a command line interface to gather shift / daily information and the Square api to gather transactional information. It then compiles the info into reports and outputs them to a tabular PDF file.

This script is fairly single entity-centric but may be of some use getting started with the Square api or general use of Prawn for generating tabular data PDFs. More Square examples can be found on their [Github page](https://github.com/square/connect-api-examples)

This is a custom solution for generating shift reports and end of day reports for accounting purposes. It
s written in Ruby and uses basic interview questions in a command line interface to gather shift / daily information and the Square api to gather transactional information. It then compiles the info into reports and outputs them to a tabular PDF file.

This script is fairly single entity-centric but may be of some use getting started with the Square api or general use of Prawn for generating tabular data PDFs. More Square examples can be found on their [Github page](https://github.com/square/connect-api-examples)


####Install:
  
  - clone  
  - edit config/configatron/defaults.rb to add your access token and location id (configatron keeps your secrets secret)
  - bundle update

  - in app directory run ruby citizen_reports.rb and follow the interview questions

  - in app directory run ruby citizen_reports.rb and follow the interview questions

####Notes:
 - This is intended to run without a database and assumes at least one breakfast server is on each am shift
 - All responses from Square api calls are in pennies so interview questions with floats are converted to pennies and later converted back to floats using the to_pennies and fm (format money) methods.
