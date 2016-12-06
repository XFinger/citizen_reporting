require 'logger'

log_file = File.new(File.expand_path("../../log/rimport.log", __FILE__), 'a+')
log_file.sync = true

LOGGER = Logger.new(log_file, 'weekly')
LOGGER.level = Logger::INFO